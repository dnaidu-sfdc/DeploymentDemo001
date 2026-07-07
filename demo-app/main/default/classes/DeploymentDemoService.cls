/**
 * DeploymentDemoService
 * -----------------------------------------------------------------------------
 * Minimal, self-contained Apex used by the DevSecOps CI/CD demo
 * (Development Lifecycle & Deployment badge).
 *
 * Exposes an @InvocableMethod so a record-triggered Flow can hand a
 * Deployment_Demo__c record to Apex, which "closes it out" (marks it processed).
 * This lets the demo show BOTH a Flow and Apex executing together, and gives
 * the pipeline a meaningful unit test to run as its quality gate.
 */
public with sharing class DeploymentDemoService {

    /** Flow input wrapper: exposes recordId as a single input in Flow Builder. */
    public class FlowRequest {
        @InvocableVariable(required=true label='Deployment Demo Record Id')
        public Id recordId;
    }
//new change made for the demo with Maulik

    @InvocableMethod(
        label='Mark Deployment Demo Processed'
        description='Marks the Deployment Demo record as processed and sets Status to Done.'
    )
    public static void markProcessed(List<FlowRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        // Collect the ids handed in by Flow (bulk-safe).
        Set<Id> recordIds = new Set<Id>();
        for (FlowRequest req : requests) {
            if (req.recordId != null) {
                recordIds.add(req.recordId);
            }
        }
        if (recordIds.isEmpty()) {
            return;
        }

        // Only touch records not already processed -> prevents flow/apex recursion.
        List<Deployment_Demo__c> records = [
            SELECT Id, Status__c, Processed__c, Notes__c
            FROM Deployment_Demo__c
            WHERE Id IN :recordIds AND Processed__c = false
            WITH USER_MODE
        ];

        for (Deployment_Demo__c record : records) {
            record.Processed__c = true;
            record.Status__c = 'Done';
            String stamp = 'Processed by Apex on ' + System.now().format();
            record.Notes__c = String.isBlank(record.Notes__c)
                ? stamp
                : record.Notes__c + '\n' + stamp;
        }

        if (!records.isEmpty()) {
            update as user records;
        }
    }
}
// Sandbox gate verification.
// Final end-to-end demo run.
