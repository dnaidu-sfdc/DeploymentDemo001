/**
 * Shared helpers for the Ops Copilot (Task 4) invocable actions.
 *
 * The Ops Copilot is an INTERNAL employee agent used by Pacific Haven property
 * managers. Unlike the Concierge (which runs as the logged-in resident), these
 * actions run as the property-manager user, so they are written `with sharing`
 * and additionally scope data explicitly (by tenant for renewals, by the
 * manager's Managed_State__c for the weekly review).
 *
 * Two design constraints from the brief are encoded here:
 *  - CCPA: employer information is suppressed for California residents.
 *  - Fair-housing / bias: a renewal recommendation is derived ONLY from a
 *    tenant's late-payment count - never from any protected attribute. We never
 *    even query gender/pronoun/ethnicity-style fields.
 */
public with sharing class OpsHelpers {

    /** Resolved tenant + their current unit, rent, residency and payment history. */
    public class TenantProfile {
        public Boolean found = false;
        public Id accountId;
        public String tenantName;
        public String employer;          // null when suppressed (CA / CCPA)
        public Boolean employerSuppressed = false;
        public Id apartmentId;
        public String apartmentName;
        public String propertyState;
        public String propertyCity;
        public Decimal monthlyRent;
        public Integer totalPayments = 0;
        public Integer latePayments = 0;
        public String reason;            // populated when found = false / ambiguous
    }

    /**
     * Resolve a tenant Person Account from either a 15/18-char Account Id or a
     * (partial) name. Returns found=false with a helpful reason when nothing
     * matches or when a name is ambiguous, so the agent can ask the manager to
     * clarify rather than guessing.
     */
    public static TenantProfile resolveTenant(String tenantRef) {
        return resolveTenant(tenantRef, null);
    }

    public static TenantProfile resolveTenant(String tenantRef, String unit) {
        TenantProfile p = new TenantProfile();
        if (String.isBlank(tenantRef)) {
            p.reason = 'No tenant was specified.';
            return p;
        }

        Account acct = queryByIdOrName(tenantRef, unit, p);
        if (acct == null) return p;            // reason already set

        p.found = true;
        p.accountId = acct.Id;
        p.tenantName = acct.Name;

        // Current (occupied) apartment for this tenant -> rent + property state.
        List<Apartment__c> apts = [
            SELECT Id, Name, Rent__c, Apt_Location__r.State__c, Apt_Location__r.City__c
            FROM Apartment__c
            WHERE Account__c = :acct.Id AND Occupied__c = true
            ORDER BY Name
            LIMIT 1
        ];
        if (!apts.isEmpty()) {
            p.apartmentId   = apts[0].Id;
            p.apartmentName = apts[0].Name;
            p.monthlyRent   = apts[0].Rent__c;
            p.propertyState = apts[0].Apt_Location__r.State__c;
            p.propertyCity  = apts[0].Apt_Location__r.City__c;
        }

        // CCPA: California residents' employer info is protected and must never
        // be surfaced in a summary the manager could paste into a communication.
        // Residency is taken from the property's state, falling back to the
        // account's mailing state.
        String residencyState = p.propertyState != null ? p.propertyState : acct.PersonMailingState;
        if (residencyState == 'CA') {
            p.employer = null;
            p.employerSuppressed = true;
        } else {
            p.employer = acct.Employer__c;
        }

        // Payment history is the SOLE basis for any renewal decision.
        for (AggregateResult ar : [
            SELECT Past_Due__c pd, COUNT(Id) c
            FROM Lease_Payment__c
            WHERE Account__c = :acct.Id
            GROUP BY Past_Due__c
        ]) {
            Integer c = (Integer) ar.get('c');
            p.totalPayments += c;
            if (ar.get('pd') == true) p.latePayments += c;
        }
        return p;
    }

    private static Account queryByIdOrName(String tenantRef, String unit, TenantProfile p) {
        String ref = tenantRef.trim();
        Id asId = null;
        try { asId = (Id) ref; } catch (Exception e) { asId = null; }

        if (asId != null) {
            List<Account> byId = [
                SELECT Id, Name, Employer__c, PersonMailingState
                FROM Account WHERE Id = :asId LIMIT 1
            ];
            if (byId.isEmpty()) { p.reason = 'No tenant found matching "' + ref + '".'; return null; }
            return byId[0];
        }

        String pattern = '%' + ref + '%';
        List<Account> matches = [
            SELECT Id, Name, Employer__c, PersonMailingState
            FROM Account
            WHERE IsPersonAccount = true AND Name LIKE :pattern
            ORDER BY Name
            LIMIT 25
        ];

        if (matches.isEmpty()) {
            p.reason = 'No tenant found matching "' + ref + '".';
            return null;
        }
        if (matches.size() == 1) return matches[0];

        // Ambiguous name. Disambiguate by the tenant's occupied unit when the
        // caller supplied one; otherwise report the candidates WITH their unit so
        // the manager can re-ask precisely.
        Map<Id, Apartment__c> aptByAcct = new Map<Id, Apartment__c>();
        for (Apartment__c apt : [
            SELECT Id, Name, Account__c, Apt_Location__r.City__c, Apt_Location__r.State__c
            FROM Apartment__c
            WHERE Account__c IN :matches AND Occupied__c = true
        ]) {
            aptByAcct.put(apt.Account__c, apt);
        }

        if (String.isNotBlank(unit)) {
            String u = unit.trim().toLowerCase();
            List<Account> hits = new List<Account>();
            for (Account a : matches) {
                Apartment__c apt = aptByAcct.get(a.Id);
                if (apt != null && apt.Name != null && apt.Name.toLowerCase().contains(u)) {
                    hits.add(a);
                }
            }
            if (hits.size() == 1) return hits[0];
        }

        List<String> opts = new List<String>();
        for (Account a : matches) {
            Apartment__c apt = aptByAcct.get(a.Id);
            opts.add(a.Name + (apt == null
                ? ' (no active unit)'
                : ' - ' + apt.Name + ' (' + apt.Apt_Location__r.City__c + ', ' + apt.Apt_Location__r.State__c + ')'));
        }
        p.reason = 'Multiple tenants match "' + ref + '". Please specify the unit. Candidates: '
            + String.join(opts, '; ') + '.';
        return null;
    }

    /** A renewal decision derived purely from late-payment history. */
    public class RenewalDecision {
        public String tier;              // WARM | INCREASE | DECLINE
        public String recommendation;    // human-readable
        public Decimal currentRent;
        public Decimal recommendedRent;
        public Decimal increasePercent; // 0 or 10
    }

    /**
     * Map late-payment count to a renewal decision. This is intentionally a
     * deterministic, auditable rule so the agent never "decides" a renewal with
     * an LLM and never uses anything other than payment behavior:
     *   0 late        -> warm renewal at current rent
     *   1-3 late      -> renewal at +10% rent
     *   more than 3   -> decline renewal
     */
    public static RenewalDecision decideRenewal(Integer latePayments, Decimal currentRent) {
        RenewalDecision d = new RenewalDecision();
        d.currentRent = currentRent;
        Integer late = latePayments == null ? 0 : latePayments;

        if (late == 0) {
            d.tier = 'WARM';
            d.increasePercent = 0;
            d.recommendedRent = currentRent;
            d.recommendation = 'Offer renewal with a professional, warm tone at the current rent.';
        } else if (late <= 3) {
            d.tier = 'INCREASE';
            d.increasePercent = 10;
            d.recommendedRent = currentRent == null
                ? null
                : (currentRent * 1.10).setScale(2);
            d.recommendation = 'Offer renewal in a strict but professional tone at 10% higher rent ('
                + formatMoney(d.recommendedRent) + ').';
        } else {
            d.tier = 'DECLINE';
            d.increasePercent = 0;
            d.recommendedRent = null;
            d.recommendation = 'Politely but professionally decline to offer a renewal.';
        }
        return d;
    }

    public static String formatMoney(Decimal v) {
        if (v == null) return 'N/A';
        return '$' + v.setScale(2).format();
    }

    /**
     * Resolve the state whose properties the running user manages. Prefers an
     * explicit override (used only in preview/test) and otherwise reads the
     * running user's Managed_State__c. Returns null when neither is available.
     */
    public static String resolveManagedState(String stateOverride) {
        if (String.isNotBlank(stateOverride)) return stateOverride.trim().toUpperCase();
        List<User> us = [
            SELECT Managed_State__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (!us.isEmpty() && String.isNotBlank(us[0].Managed_State__c)) {
            return us[0].Managed_State__c;
        }
        return null;
    }
}