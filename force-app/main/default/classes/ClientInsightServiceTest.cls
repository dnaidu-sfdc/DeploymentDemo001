@isTest
private class ClientInsightServiceTest {

    @testSetup
    static void setup() {
        Account acct = new Account(
            Name = 'Globex Healthcare',
            Industry = 'Healthcare',
            AnnualRevenue = 5000000,
            Type = 'Customer',
            Description = 'Strategic healthcare client.'
        );
        insert acct;

        insert new Opportunity(
            Name = 'Globex - Platform Renewal',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 250000,
            AccountId = acct.Id
        );

        insert new Case(Subject = 'Login issue', Status = 'New', Priority = 'High', AccountId = acct.Id);

        ContentVersion cv = new ContentVersion(
            Title = 'Account Plan 2025',
            PathOnClient = 'plan.txt',
            VersionData = Blob.valueOf('Quarterly account plan content.')
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = acct.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static Id acctId() {
        return [SELECT Id FROM Account WHERE Name = 'Globex Healthcare' LIMIT 1].Id;
    }

    // A provider stub used to deterministically exercise the live path and the fallback path.
    private class StubProvider implements LlmProvider {
        private Boolean throwError;
        StubProvider(Boolean throwError) { this.throwError = throwError; }
        public String generate(String prompt, String language) {
            if (throwError) {
                throw new CalloutException('simulated model failure');
            }
            return 'LIVE ANSWER for ' + language;
        }
    }

    @isTest
    static void getInsightUsesMockByDefaultAndGroundsContext() {
        Test.startTest();
        ClientInsightService.InsightResult result =
            ClientInsightService.getInsight(acctId(), 'Summarize this customer.');
        Test.stopTest();

        System.assertNotEquals(null, result.answer, 'An answer should be produced');
        System.assertEquals(false, result.usedLiveModel, 'Defaults to the mock provider');
        System.assert(result.answer.contains('Globex Healthcare'), 'Answer should be grounded in retrieved context');
        System.assert(result.answer.contains('Globex - Platform Renewal'), 'Opportunity context should be included');
    }

    @isTest
    static void getInsightUsesLiveProviderWhenInjected() {
        ClientInsightService.providerOverride = new StubProvider(false);

        Test.startTest();
        ClientInsightService.InsightResult result =
            ClientInsightService.getInsight(acctId(), 'How are we doing?');
        Test.stopTest();

        System.assertEquals(true, result.usedLiveModel, 'Injected non-mock provider marks live');
        System.assert(result.answer.startsWith('LIVE ANSWER'), 'Live provider output expected');
    }

    @isTest
    static void getInsightFallsBackWhenLiveProviderFails() {
        ClientInsightService.providerOverride = new StubProvider(true);

        Test.startTest();
        ClientInsightService.InsightResult result =
            ClientInsightService.getInsight(acctId(), 'How are we doing?');
        Test.stopTest();

        System.assertEquals(false, result.usedLiveModel, 'Failure should fall back to mock');
        System.assert(result.answer.contains('Globex Healthcare'), 'Fallback answer is still grounded');
    }

    @isTest
    static void invocableMethodReturnsSummary() {
        ClientInsightService.Request req = new ClientInsightService.Request();
        req.recordId = acctId();
        req.question = 'Summarize engagement.';

        Test.startTest();
        List<ClientInsightService.Response> responses =
            ClientInsightService.summarizeClient(new List<ClientInsightService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success, 'Flow call should succeed');
        System.assertNotEquals(null, responses[0].answer);
    }

    @isTest
    static void invocableMethodHandlesErrorGracefully() {
        ClientInsightService.Request req = new ClientInsightService.Request();
        req.recordId = null; // forces an error in retrieval

        Test.startTest();
        List<ClientInsightService.Response> responses =
            ClientInsightService.summarizeClient(new List<ClientInsightService.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Missing id should be reported as failure');
        System.assertNotEquals(null, responses[0].errorMessage, 'Error message should be populated');
    }

    @isTest
    static void promptTemplateProviderParsesGeneration() {
        Test.setMock(HttpCalloutMock.class, new ModelMock(200, '{"generation":"hi there"}'));
        Test.startTest();
        String out = new PromptTemplateProvider().generate('prompt', 'en_US');
        Test.stopTest();
        System.assertEquals('hi there', out);
    }

    @isTest
    static void promptTemplateProviderThrowsOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new ModelMock(500, 'boom'));
        Boolean threw = false;
        Test.startTest();
        try {
            new PromptTemplateProvider().generate('prompt', 'en_US');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Non-2xx should raise an exception');
    }

    @isTest
    static void mockProviderEchoesGroundingAndLanguage() {
        String out = new MockLlmProvider().generate('CTX', 'fr_FR');
        System.assert(out.contains('fr_FR'));
        System.assert(out.contains('CTX'));
    }

    private class ModelMock implements HttpCalloutMock {
        private Integer code;
        private String body;
        ModelMock(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }
}
