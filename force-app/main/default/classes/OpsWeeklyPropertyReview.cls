/**
 * Ops Copilot - Task 4 Scenario 2.
 *
 * Produces a weekly activity summary for the properties a property manager is
 * responsible for. The brief simplifies ownership to "one property manager per
 * state" (CA, OR, WA), so scoping is by the running user's Managed_State__c.
 *
 * The summary aggregates the three Pre-Work objects for the last 7 days:
 *   - Apartment__c     -> occupancy (occupied / vacant / rate)
 *   - Lease_Payment__c -> payments due this week + how many were late
 *   - Case             -> new cases this week, broken down by priority/status
 *
 * Cost note (see IMPLEMENTATION.md Task 4): this action is deterministic Apex
 * (unmetered). Generative summarization of its output is the only metered step,
 * which is why a scheduled batch should pre-compute these aggregates in Apex and
 * only call a generative step when a human actually opens the summary.
 */
public with sharing class OpsWeeklyPropertyReview {

    private static final Integer WINDOW_DAYS = 7;

    public class Request {
        @InvocableVariable(label='Managed State Override'
            description='Optional. For testing only - normally the property manager\'s Managed State is used automatically. One of CA, OR, WA.')
        public String managedStateOverride;
    }

    public class Response {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String state;
        @InvocableVariable public Integer totalUnits;
        @InvocableVariable public Integer occupiedUnits;
        @InvocableVariable public Integer vacantUnits;
        @InvocableVariable public Decimal occupancyRate;       // percent, 0-100
        @InvocableVariable public Integer paymentsDueThisWeek;
        @InvocableVariable public Integer latePaymentsThisWeek;
        @InvocableVariable public Integer newCasesThisWeek;
        @InvocableVariable public Integer openHighPriorityCases;
        @InvocableVariable public String caseBreakdown;
        @InvocableVariable public String summary;
    }

    @InvocableMethod(
        label='Weekly Property Review'
        description='Summarizes the last 7 days of occupancy, lease payments and cases for the properties in the running property manager\'s managed state (CA, OR, WA).'
        category='Ops Copilot'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();

        for (Request req : requests) {
            Response resp = new Response();
            String state = OpsHelpers.resolveManagedState(
                req == null ? null : req.managedStateOverride);

            if (String.isBlank(state)) {
                resp.found = false;
                resp.summary = 'No managed state is set for your user. Ask an administrator to set '
                    + 'your "Managed State" (CA, OR or WA) so I can scope the weekly review to your properties.';
                out.add(resp);
                continue;
            }

            resp.found = true;
            resp.state = state;
            Date weekAgo = Date.today().addDays(-WINDOW_DAYS);

            // --- Occupancy across this manager's properties ---
            Integer total = 0, occupied = 0;
            for (AggregateResult ar : [
                SELECT Occupied__c occ, COUNT(Id) c
                FROM Apartment__c
                WHERE Apt_Location__r.State__c = :state
                GROUP BY Occupied__c
            ]) {
                Integer c = (Integer) ar.get('c');
                total += c;
                if (ar.get('occ') == true) occupied += c;
            }
            resp.totalUnits = total;
            resp.occupiedUnits = occupied;
            resp.vacantUnits = total - occupied;
            resp.occupancyRate = total == 0 ? 0 : (Decimal.valueOf(occupied) / total * 100).setScale(1);

            // --- Lease payments due in the last 7 days ---
            Integer due = 0, late = 0;
            for (AggregateResult ar : [
                SELECT Past_Due__c pd, COUNT(Id) c
                FROM Lease_Payment__c
                WHERE Apartment__r.Apt_Location__r.State__c = :state
                  AND Date_Due__c >= :weekAgo
                GROUP BY Past_Due__c
            ]) {
                Integer c = (Integer) ar.get('c');
                due += c;
                if (ar.get('pd') == true) late += c;
            }
            resp.paymentsDueThisWeek = due;
            resp.latePaymentsThisWeek = late;

            // --- Cases opened in the last 7 days, by priority ---
            Map<String, Integer> byPriority = new Map<String, Integer>();
            Integer newCases = 0;
            for (AggregateResult ar : [
                SELECT Priority pri, COUNT(Id) c
                FROM Case
                WHERE Apartment__r.Apt_Location__r.State__c = :state
                  AND Occurred_On__c >= :weekAgo
                GROUP BY Priority
            ]) {
                Integer c = (Integer) ar.get('c');
                newCases += c;
                String pri = (String) ar.get('pri');
                byPriority.put(pri == null ? 'None' : pri, c);
            }
            resp.newCasesThisWeek = newCases;

            // Open (not closed) high-priority cases, regardless of age.
            resp.openHighPriorityCases = [
                SELECT COUNT()
                FROM Case
                WHERE Apartment__r.Apt_Location__r.State__c = :state
                  AND Priority = 'High'
                  AND Status != 'Closed'
            ];

            List<String> brk = new List<String>();
            for (String pri : new List<String>{ 'High', 'Medium', 'Low', 'None' }) {
                if (byPriority.containsKey(pri)) brk.add(pri + ': ' + byPriority.get(pri));
            }
            resp.caseBreakdown = String.join(brk, ', ');

            resp.summary = buildSummary(resp);
            out.add(resp);
        }
        return out;
    }

    private static String buildSummary(Response r) {
        List<String> lines = new List<String>();
        lines.add('Weekly property review - ' + r.state + ' (last ' + WINDOW_DAYS + ' days)');
        lines.add('Occupancy: ' + r.occupiedUnits + '/' + r.totalUnits
            + ' units occupied (' + r.occupancyRate + '%), ' + r.vacantUnits + ' vacant.');
        lines.add('Lease payments due this week: ' + r.paymentsDueThisWeek
            + ', of which ' + r.latePaymentsThisWeek + ' were late.');
        lines.add('New cases this week: ' + r.newCasesThisWeek
            + (String.isBlank(r.caseBreakdown) ? '' : ' (' + r.caseBreakdown + ')') + '.');
        lines.add('Open high-priority cases: ' + r.openHighPriorityCases + '.');
        return String.join(lines, '\n');
    }
}