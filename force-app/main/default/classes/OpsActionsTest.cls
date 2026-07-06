/**
 * Unit tests for the Ops Copilot (Task 4) invocable actions and helpers.
 *
 * Covers:
 *  - Renewal tiers driven solely by late-payment count (0 / 1-3 / >3).
 *  - CCPA suppression of employer for California residents.
 *  - Tenant resolution: by name, not-found, ambiguous.
 *  - Weekly property review aggregation + state scoping.
 *
 * Fixtures are built per-test (SeeAllData defaults to false) so counts are
 * deterministic and independent of seeded org data.
 */
@IsTest
private class OpsActionsTest {

    private static Id personRt {
        get {
            if (personRt == null) {
                personRt = [
                    SELECT Id FROM RecordType
                    WHERE SObjectType = 'Account' AND IsPersonType = true AND IsActive = true
                    LIMIT 1
                ].Id;
            }
            return personRt;
        }
        set;
    }

    private static Account makePersonAccount(String first, String last, String state, String employer) {
        Account a = new Account(
            FirstName = first, LastName = last,
            RecordTypeId = personRt,
            PersonMailingState = state,
            Employer__c = employer
        );
        insert a;
        return a;
    }

    private static Apartment__c makeApartment(Id acctId, Id locId, Decimal rent, Boolean occupied) {
        Apartment__c apt = new Apartment__c(
            Apt_Location__c = locId, Bedrooms__c = 2, Rent__c = rent,
            Occupied__c = occupied, Account__c = acctId, Available_Date__c = Date.today()
        );
        insert apt;
        return apt;
    }

    private static Apt_Location__c makeLocation(String state) {
        Apt_Location__c loc = new Apt_Location__c(
            Name = 'Loc ' + state, City__c = 'City ' + state, State__c = state);
        insert loc;
        return loc;
    }

    /** Creates `lateCount` late payments and `onTimeCount` on-time payments. */
    private static void makePayments(Id acctId, Id aptId, Decimal rent, Integer lateCount, Integer onTimeCount) {
        List<Lease_Payment__c> lps = new List<Lease_Payment__c>();
        for (Integer i = 0; i < lateCount; i++) {
            Date due = Date.today().addDays(-(40 + i));
            lps.add(new Lease_Payment__c(
                Account__c = acctId, Apartment__c = aptId, Rent_Amount__c = rent,
                Date_Due__c = due, Date_Paid__c = due.addDays(10)   // paid 10 days late
            ));
        }
        for (Integer i = 0; i < onTimeCount; i++) {
            Date due = Date.today().addDays(-(40 + lateCount + i));
            lps.add(new Lease_Payment__c(
                Account__c = acctId, Apartment__c = aptId, Rent_Amount__c = rent,
                Date_Due__c = due, Date_Paid__c = due                // paid on the due date
            ));
        }
        if (!lps.isEmpty()) insert lps;
    }

    private static OpsTenantRenewalSummary.Response summarize(String tenant) {
        OpsTenantRenewalSummary.Request req = new OpsTenantRenewalSummary.Request();
        req.tenant = tenant;
        return OpsTenantRenewalSummary.run(
            new List<OpsTenantRenewalSummary.Request>{ req })[0];
    }

    /* ===================== Renewal tiers ===================== */

    @IsTest
    static void renewal_warm_cleanHistory_includesEmployerOutsideCA() {
        Account a = makePersonAccount('Warm', 'Payerton', 'OR', 'Acme Corp');
        Apt_Location__c loc = makeLocation('OR');
        Apartment__c apt = makeApartment(a.Id, loc.Id, 2000, true);
        makePayments(a.Id, apt.Id, 2000, 0, 6);

        Test.startTest();
        OpsTenantRenewalSummary.Response r = summarize('Payerton');
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals(0, r.latePayments);
        System.assertEquals(6, r.totalPayments);
        System.assertEquals('WARM', r.renewalTier);
        System.assertEquals(2000, r.recommendedRent, 'warm renewal keeps current rent');
        System.assert(r.summary.contains('Acme Corp'), 'employer shown for non-CA resident');
        System.assert(r.emailGuidance.containsIgnoreCase('warm'));
    }

    @IsTest
    static void renewal_increase_oneToThreeLate() {
        Account a = makePersonAccount('Mid', 'Increaseman', 'WA', 'Globex');
        Apt_Location__c loc = makeLocation('WA');
        Apartment__c apt = makeApartment(a.Id, loc.Id, 2000, true);
        makePayments(a.Id, apt.Id, 2000, 2, 4);

        Test.startTest();
        OpsTenantRenewalSummary.Response r = summarize('Increaseman');
        Test.stopTest();

        System.assertEquals(2, r.latePayments);
        System.assertEquals('INCREASE', r.renewalTier);
        System.assertEquals(2200.00, r.recommendedRent, '10% higher than 2000');
    }

    @IsTest
    static void renewal_decline_moreThanThree_andCcpaSuppressesEmployer() {
        Account a = makePersonAccount('Cali', 'Declinez', 'CA', 'SecretEmployer Inc');
        Apt_Location__c loc = makeLocation('CA');
        Apartment__c apt = makeApartment(a.Id, loc.Id, 3000, true);
        makePayments(a.Id, apt.Id, 3000, 5, 1);

        Test.startTest();
        OpsTenantRenewalSummary.Response r = summarize('Declinez');
        Test.stopTest();

        System.assertEquals(5, r.latePayments);
        System.assertEquals('DECLINE', r.renewalTier);
        System.assertEquals(null, r.recommendedRent);
        System.assert(!r.summary.contains('SecretEmployer'), 'CA employer must be suppressed (CCPA)');
        System.assert(r.summary.containsIgnoreCase('CCPA'), 'summary explains the suppression');
    }

    @IsTest
    static void renewal_notFound_and_ambiguous() {
        Account a1 = makePersonAccount('Ambi', 'Guoustone', 'OR', null);
        Account a2 = makePersonAccount('Ambi', 'Guoustwo', 'OR', null);

        OpsTenantRenewalSummary.Response notFound = summarize('Nobody McNoone');
        System.assertEquals(false, notFound.found);
        System.assert(notFound.summary.containsIgnoreCase('No tenant found'));

        OpsTenantRenewalSummary.Response ambiguous = summarize('Guoust');
        System.assertEquals(false, ambiguous.found);
        System.assert(ambiguous.summary.containsIgnoreCase('Multiple tenants'));
    }

    @IsTest
    static void renewal_byAccountId() {
        Account a = makePersonAccount('Ida', 'Lookupson', 'OR', 'Initech');
        Apt_Location__c loc = makeLocation('OR');
        makeApartment(a.Id, loc.Id, 1800, true);

        OpsTenantRenewalSummary.Response r = summarize(a.Id);
        System.assertEquals(true, r.found);
        System.assertEquals('WARM', r.renewalTier);
    }

    @IsTest
    static void decideRenewal_boundaries() {
        System.assertEquals('WARM',    OpsHelpers.decideRenewal(0, 1000).tier);
        System.assertEquals('INCREASE',OpsHelpers.decideRenewal(1, 1000).tier);
        System.assertEquals('INCREASE',OpsHelpers.decideRenewal(3, 1000).tier);
        System.assertEquals('DECLINE', OpsHelpers.decideRenewal(4, 1000).tier);
        System.assertEquals(1100.00,   OpsHelpers.decideRenewal(2, 1000).recommendedRent);
    }

    /* ===================== Weekly property review ===================== */

    @IsTest
    static void weekly_review_scopesAndAggregatesByState() {
        Apt_Location__c orLoc = makeLocation('OR');
        Account t1 = makePersonAccount('Owen', 'Resident', 'OR', null);
        Account t2 = makePersonAccount('Olive', 'Resident', 'OR', null);
        Apartment__c a1 = makeApartment(t1.Id, orLoc.Id, 2000, true);
        Apartment__c a2 = makeApartment(t2.Id, orLoc.Id, 2100, true);
        Apartment__c a3 = makeApartment(null, orLoc.Id, 2200, false);   // vacant

        // Payments due this week: 1 late, 1 on time.
        insert new List<Lease_Payment__c>{
            new Lease_Payment__c(Account__c = t1.Id, Apartment__c = a1.Id, Rent_Amount__c = 2000,
                Date_Due__c = Date.today().addDays(-2), Date_Paid__c = Date.today().addDays(-1)),
            new Lease_Payment__c(Account__c = t2.Id, Apartment__c = a2.Id, Rent_Amount__c = 2100,
                Date_Due__c = Date.today().addDays(-3), Date_Paid__c = Date.today().addDays(-3))
        };

        // Cases this week: 1 High (open), 1 Medium (closed).
        insert new List<Case>{
            new Case(AccountId = t1.Id, Apartment__c = a1.Id, Subject = 'No power',
                Issue_Type__c = 'Electrical', Priority = 'High', Status = 'New',
                Occurred_On__c = Date.today().addDays(-1)),
            new Case(AccountId = t2.Id, Apartment__c = a2.Id, Subject = 'Drip',
                Issue_Type__c = 'Plumbing', Priority = 'Medium', Status = 'Closed',
                Occurred_On__c = Date.today().addDays(-2))
        };

        OpsWeeklyPropertyReview.Request req = new OpsWeeklyPropertyReview.Request();
        req.managedStateOverride = 'OR';

        Test.startTest();
        OpsWeeklyPropertyReview.Response r = OpsWeeklyPropertyReview.run(
            new List<OpsWeeklyPropertyReview.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals('OR', r.state);
        System.assertEquals(3, r.totalUnits);
        System.assertEquals(2, r.occupiedUnits);
        System.assertEquals(1, r.vacantUnits);
        System.assertEquals(2, r.paymentsDueThisWeek);
        System.assertEquals(1, r.latePaymentsThisWeek);
        System.assertEquals(2, r.newCasesThisWeek);
        System.assertEquals(1, r.openHighPriorityCases);
    }

    @IsTest
    static void weekly_review_noManagedState() {
        // The running test user has no Managed_State__c and no override is given.
        OpsWeeklyPropertyReview.Request req = new OpsWeeklyPropertyReview.Request();
        OpsWeeklyPropertyReview.Response r = OpsWeeklyPropertyReview.run(
            new List<OpsWeeklyPropertyReview.Request>{ req })[0];
        System.assertEquals(false, r.found);
        System.assert(r.summary.containsIgnoreCase('managed state'));
    }

    @IsTest
    static void resolveManagedState_readsRunningUser() {
        // A standard user carrying Managed_State__c = WA resolves to that state.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Pam', LastName = 'Manager',
            Email = 'pam.manager.ops@example.com',
            Username = 'pam.manager.ops.' + DateTime.now().getTime() + '@example.com.invalid',
            Alias = 'pmgr', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = p.Id, Managed_State__c = 'WA'
        );
        insert u;

        System.runAs(u) {
            System.assertEquals('WA', OpsHelpers.resolveManagedState(null));
        }
        // Override always wins and is upper-cased.
        System.assertEquals('CA', OpsHelpers.resolveManagedState('ca'));
    }
}