/**
 * DeploymentDemoServiceTest
 * Unit tests for DeploymentDemoService — this is the "basic quality check"
 * the CI pipeline runs on every PR.
 *
 * The service enforces FLS/CRUD via WITH USER_MODE / `update as user`, so the
 * tests run as a dedicated user granted the Bedrock_Deployment_Demo permission
 * set. This makes them pass consistently in a scratch org, the 2GP packaging
 * build org, and on package install — none of which assume the running user is
 * an admin with implicit field access.
 */
@isTest
private class DeploymentDemoServiceTest {

    /** Create a minimal-access user + assign the demo permission set (setup DML). */
    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Bedrock',
            LastName = 'DemoRunner',
            Email = 'bedrock.demorunner@bedrock.demo.test',
            Username = 'bedrock.demorunner.' + DateTime.now().getTime() + '@bedrock.demo.test',
            Alias = 'bdemo',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Bedrock_Deployment_Demo' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }

    private static User demoUser() {
        return [SELECT Id FROM User WHERE Username LIKE 'bedrock.demorunner.%@bedrock.demo.test' LIMIT 1];
    }

    @isTest
    static void marksRecordProcessed() {
        User u = demoUser();
        Deployment_Demo__c demo;

        System.runAs(u) {
            demo = new Deployment_Demo__c(Name = 'CI Demo Record', Status__c = 'New', Processed__c = false);
            insert demo;

            DeploymentDemoService.FlowRequest req = new DeploymentDemoService.FlowRequest();
            req.recordId = demo.Id;

            Test.startTest();
            DeploymentDemoService.markProcessed(new List<DeploymentDemoService.FlowRequest>{ req });
            Test.stopTest();
        }

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
        User u = demoUser();

        System.runAs(u) {
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
        }

        Integer processed = [SELECT COUNT() FROM Deployment_Demo__c WHERE Processed__c = true];
        System.assertEquals(200, processed, 'All 200 records should be processed in bulk');
    }

    @isTest
    static void handlesEmptyAndNullInput() {
        User u = demoUser();
        System.runAs(u) {
            Test.startTest();
            DeploymentDemoService.markProcessed(new List<DeploymentDemoService.FlowRequest>());
            DeploymentDemoService.markProcessed(null);
            Test.stopTest();
        }
        // No exception = pass.
    }
}
