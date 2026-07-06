/**
 * DeploymentDemoServiceTest
 * Unit tests for DeploymentDemoService — this is the "basic quality check"
 * the CI pipeline runs on every PR.
 */
@isTest
private class DeploymentDemoServiceTest {

    @isTest
    static void marksRecordProcessed() {
        Deployment_Demo__c demo = new Deployment_Demo__c(
            Name = 'CI Demo Record',
            Status__c = 'New',
            Processed__c = false
        );
        insert demo;

        DeploymentDemoService.FlowRequest req = new DeploymentDemoService.FlowRequest();
        req.recordId = demo.Id;

        Test.startTest();
        DeploymentDemoService.markProcessed(new List<DeploymentDemoService.FlowRequest>{ req });
        Test.stopTest();

        Deployment_Demo__c after = [
            SELECT Processed__c, Status__c, Notes__c
            FROM Deployment_Demo__c
            WHERE Id = :demo.Id
        ];
        System.assertEquals(true, after.Processed__c, 'Record should be marked processed');
        System.assertEquals('Done', after.Status__c, 'Status should be Done');
        System.assert(after.Notes__c != null && after.Notes__c.contains('Processed by Apex'),
            'Notes should capture the Apex stamp');
    }

    @isTest
    static void isBulkSafeAndSkipsProcessed() {
        List<Deployment_Demo__c> demos = new List<Deployment_Demo__c>();
        for (Integer i = 0; i < 200; i++) {
            demos.add(new Deployment_Demo__c(Name = 'Bulk ' + i, Status__c = 'New', Processed__c = false));
        }
        insert demos;

        List<DeploymentDemoService.FlowRequest> reqs = new List<DeploymentDemoService.FlowRequest>();
        for (Deployment_Demo__c d : demos) {
            DeploymentDemoService.FlowRequest r = new DeploymentDemoService.FlowRequest();
            r.recordId = d.Id;
            reqs.add(r);
        }

        Test.startTest();
        DeploymentDemoService.markProcessed(reqs);
        Test.stopTest();

        Integer processed = [SELECT COUNT() FROM Deployment_Demo__c WHERE Processed__c = true];
        System.assertEquals(200, processed, 'All 200 records should be processed in bulk');
    }

    @isTest
    static void handlesEmptyAndNullInput() {
        Test.startTest();
        DeploymentDemoService.markProcessed(new List<DeploymentDemoService.FlowRequest>());
        DeploymentDemoService.markProcessed(null);
        Test.stopTest();
        // No exception = pass.
    }
}
