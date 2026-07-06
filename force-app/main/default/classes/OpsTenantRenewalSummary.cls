/**
 * Ops Copilot - Task 4 Scenario 1.
 *
 * Returns a property manager a concise rental-history summary for a tenant and a
 * deterministic renewal recommendation derived ONLY from late-payment history:
 *   0 late      -> warm renewal at current rent
 *   1-3 late    -> renewal at +10% rent
 *   more than 3 -> decline renewal
 *
 * Trust guarantees baked into this action:
 *  - CCPA: a California resident's employer is never returned (see OpsHelpers).
 *  - Fair housing / anti-bias: the decision uses payment count only; no
 *    protected attribute is queried or considered. The agent is expected to
 *    draft the renewal email from `emailGuidance`, not to re-decide the outcome.
 */
public with sharing class OpsTenantRenewalSummary {

    public class Request {
        @InvocableVariable(required=true label='Tenant'
            description='The tenant to summarize: a full or partial tenant name, or an Account Id.')
        public String tenant;

        @InvocableVariable(label='Unit'
            description='Optional. The tenant\'s unit/apartment name (e.g. "Unit 1000 - Financial District"), used only to disambiguate when several tenants share the same name.')
        public String unit;
    }

    public class Response {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String tenantName;
        @InvocableVariable public String apartment;
        @InvocableVariable public String propertyState;
        @InvocableVariable public Decimal monthlyRent;
        @InvocableVariable public Integer totalPayments;
        @InvocableVariable public Integer latePayments;
        @InvocableVariable public String renewalTier;          // WARM | INCREASE | DECLINE
        @InvocableVariable public Decimal recommendedRent;
        @InvocableVariable public String renewalRecommendation;
        @InvocableVariable public String emailGuidance;        // tells the agent how to draft
        @InvocableVariable public String summary;              // the manager-facing summary
    }

    @InvocableMethod(
        label='Summarize Tenant For Renewal'
        description='Returns a tenant rental-history summary and a renewal recommendation based solely on late-payment history. Omits CCPA-protected employer info for California residents.'
        category='Ops Copilot'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();

        for (Request req : requests) {
            Response resp = new Response();
            OpsHelpers.TenantProfile p = OpsHelpers.resolveTenant(req.tenant, req.unit);

            if (!p.found) {
                resp.found = false;
                resp.summary = p.reason;
                out.add(resp);
                continue;
            }

            OpsHelpers.RenewalDecision d =
                OpsHelpers.decideRenewal(p.latePayments, p.monthlyRent);

            resp.found = true;
            resp.tenantName = p.tenantName;
            resp.apartment = p.apartmentName;
            resp.propertyState = p.propertyState;
            resp.monthlyRent = p.monthlyRent;
            resp.totalPayments = p.totalPayments;
            resp.latePayments = p.latePayments;
            resp.renewalTier = d.tier;
            resp.recommendedRent = d.recommendedRent;
            resp.renewalRecommendation = d.recommendation;

            resp.summary = buildSummary(p, d);
            resp.emailGuidance = buildEmailGuidance(p, d);
            out.add(resp);
        }
        return out;
    }

    private static String buildSummary(OpsHelpers.TenantProfile p, OpsHelpers.RenewalDecision d) {
        List<String> lines = new List<String>();
        lines.add('Tenant: ' + p.tenantName);
        if (p.apartmentName != null) {
            lines.add('Unit: ' + p.apartmentName
                + (p.propertyCity != null ? ' (' + p.propertyCity + ', ' + p.propertyState + ')' : ''));
        }
        lines.add('Current monthly rent: ' + OpsHelpers.formatMoney(p.monthlyRent));
        lines.add('Payments on record: ' + p.totalPayments
            + ' (late: ' + p.latePayments + ')');

        if (p.employerSuppressed) {
            lines.add('Employer: withheld - protected for California residents under CCPA.');
        } else if (String.isNotBlank(p.employer)) {
            lines.add('Employer: ' + p.employer);
        }

        lines.add('');
        lines.add('Renewal recommendation (based on payment history only): ' + d.recommendation);
        return String.join(lines, '\n');
    }

    /**
     * A precise, decision-locked instruction for the agent's email draft. The
     * tier and rent are decided here in Apex; the LLM only writes prose in the
     * requested tone. The guidance also re-states the anti-bias rule.
     */
    private static String buildEmailGuidance(OpsHelpers.TenantProfile p, OpsHelpers.RenewalDecision d) {
        String base = 'Draft the renewal email addressed to ' + p.tenantName
            + ' regarding unit ' + (p.apartmentName == null ? '' : p.apartmentName) + '. '
            + 'Base the message ONLY on the recommendation below; do not consider or mention '
            + 'any personal characteristics (e.g. race, gender, orientation, family status, national origin). ';

        if (d.tier == 'WARM') {
            return base + 'The tenant has a clean payment record. Write a professional but warm email '
                + 'offering a lease renewal at the current rent of ' + OpsHelpers.formatMoney(d.currentRent) + '.';
        } else if (d.tier == 'INCREASE') {
            return base + 'The tenant has ' + p.latePayments + ' late payment(s). Write a strict but '
                + 'professional email offering a lease renewal at a 10% higher rent of '
                + OpsHelpers.formatMoney(d.recommendedRent) + ' (up from ' + OpsHelpers.formatMoney(d.currentRent) + ').';
        } else {
            return base + 'The tenant has ' + p.latePayments + ' late payments (more than three). Write a '
                + 'polite but professional email declining to offer a lease renewal at this time.';
        }
    }
}