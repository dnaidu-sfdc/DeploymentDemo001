/**
 * Retrieval-Augmented Generation (RAG) orchestrator for the "Client Insight" assistant.
 *
 * Pipeline:
 *   1. RETRIEVE - pull grounding data for the Account from Salesforce (Account profile, recent
 *      Opportunities, recent Cases, and attached files such as account plans), all bulk-safe and
 *      enforced WITH USER_MODE.
 *   2. AUGMENT  - assemble a size-bounded, grounded prompt that combines the retrieved context
 *      with the advisor's natural-language question, plus a language instruction derived from the
 *      running user's locale.
 *   3. GENERATE - delegate to an LlmProvider. A live model is used when configured; otherwise the
 *      orchestrator falls back to a deterministic mock so the experience never fails.
 *
 * The service is exposed to LWC (@AuraEnabled) and to Flow/Screen Flow (@InvocableMethod) so the
 * Section 7 declarative flow can call Apex for language control, logging and robust error handling.
 */
public with sharing class ClientInsightService {

    // Flip to true (and configure the Einstein_Models_API Named Credential) to use a live model.
    // Defaults to false so demos run fully offline against the deterministic mock provider.
    @TestVisible private static Boolean useLiveModel = false;

    // Allows tests to inject a provider deterministically.
    @TestVisible private static LlmProvider providerOverride;

    // Keep prompts well within model/governor limits.
    private static final Integer MAX_PROMPT_CHARS = 8000;
    private static final Integer MAX_CHILD_ROWS = 5;

    // ----- LWC entry point -------------------------------------------------

    @AuraEnabled
    public static InsightResult getInsight(Id recordId, String question) {
        try {
            return buildInsight(recordId, question);
        } catch (Exception e) {
            log('getInsight failed: ' + e.getMessage() + ' / ' + e.getStackTraceString());
            throw new AuraHandledException('Unable to generate insight: ' + e.getMessage());
        }
    }

    // ----- Flow entry point ------------------------------------------------

    @InvocableMethod(
        label='Summarize Client (RAG)'
        description='Generates a grounded, language-aware client summary using Apex RAG. Adds logging, error handling and locale control on top of declarative Screen Flows.'
    )
    public static List<Response> summarizeClient(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response resp = new Response();
            try {
                InsightResult result = buildInsight(req.recordId, req.question);
                resp.answer = result.answer;
                resp.usedLiveModel = result.usedLiveModel;
                resp.language = result.language;
                resp.success = true;
            } catch (Exception e) {
                // Graceful degradation: return a safe message instead of failing the flow.
                resp.success = false;
                resp.answer = 'The summary could not be generated. Please try again or contact support.';
                resp.errorMessage = e.getMessage();
                log('summarizeClient failed: ' + e.getMessage());
            }
            responses.add(resp);
        }
        return responses;
    }

    // ----- Core orchestration ---------------------------------------------

    private static InsightResult buildInsight(Id recordId, String question) {
        String language = resolveLanguage();
        String context = retrieveContext(recordId);
        String prompt = augment(context, question, language);

        InsightResult result = new InsightResult();
        result.language = language;
        result.recordId = recordId;

        LlmProvider provider = resolveProvider();
        try {
            result.answer = provider.generate(prompt, language);
            result.usedLiveModel = !(provider instanceof MockLlmProvider);
        } catch (Exception e) {
            // Live model unavailable/failed -> transparent fallback to the deterministic mock.
            log('Live model failed, falling back to mock: ' + e.getMessage());
            result.answer = new MockLlmProvider().generate(prompt, language);
            result.usedLiveModel = false;
        }
        return result;
    }

    @TestVisible
    private static LlmProvider resolveProvider() {
        if (providerOverride != null) {
            return providerOverride;
        }
        return useLiveModel ? (LlmProvider) new PromptTemplateProvider() : (LlmProvider) new MockLlmProvider();
    }

    private static String resolveLanguage() {
        // Honour the running user's locale so summaries are returned in their language - something
        // a Prompt Template invoked directly from Flow cannot do dynamically.
        String locale = UserInfo.getLocale();
        return String.isBlank(locale) ? 'en_US' : locale;
    }

    @TestVisible
    private static String retrieveContext(Id recordId) {
        if (recordId == null) {
            throw new IllegalArgumentException('A record Id is required to build client context.');
        }

        List<String> parts = new List<String>();

        for (Account acct : [
            SELECT Name, Industry, AnnualRevenue, Type, Description
            FROM Account
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ]) {
            parts.add('ACCOUNT: ' + acct.Name
                + ' | Industry: ' + nv(acct.Industry)
                + ' | Type: ' + nv(acct.Type)
                + ' | Annual Revenue: ' + nv(acct.AnnualRevenue));
            if (String.isNotBlank(acct.Description)) {
                parts.add('ACCOUNT NOTES: ' + acct.Description);
            }
        }

        List<String> opps = new List<String>();
        for (Opportunity opp : [
            SELECT Name, StageName, Amount, CloseDate
            FROM Opportunity
            WHERE AccountId = :recordId
            WITH USER_MODE
            ORDER BY CloseDate DESC
            LIMIT :MAX_CHILD_ROWS
        ]) {
            opps.add('- ' + opp.Name + ' (' + opp.StageName + ', ' + nv(opp.Amount) + ', closes ' + nv(opp.CloseDate) + ')');
        }
        if (!opps.isEmpty()) {
            parts.add('RECENT OPPORTUNITIES:\n' + String.join(opps, '\n'));
        }

        List<String> cases = new List<String>();
        for (Case c : [
            SELECT Subject, Status, Priority
            FROM Case
            WHERE AccountId = :recordId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :MAX_CHILD_ROWS
        ]) {
            cases.add('- ' + nv(c.Subject) + ' (' + c.Status + ', ' + c.Priority + ')');
        }
        if (!cases.isEmpty()) {
            parts.add('RECENT CASES:\n' + String.join(cases, '\n'));
        }

        List<String> files = new List<String>();
        for (ContentDocumentLink link : [
            SELECT ContentDocument.Title, ContentDocument.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            WITH USER_MODE
            LIMIT :MAX_CHILD_ROWS
        ]) {
            files.add('- ' + link.ContentDocument.Title + ' (' + link.ContentDocument.FileType + ')');
        }
        if (!files.isEmpty()) {
            parts.add('ATTACHED DOCUMENTS (e.g. account plans):\n' + String.join(files, '\n'));
        }

        if (parts.isEmpty()) {
            parts.add('No related records were found for this account.');
        }
        return String.join(parts, '\n\n');
    }

    private static String augment(String context, String question, String language) {
        String safeQuestion = String.isBlank(question)
            ? 'Summarize this customer\'s overall engagement.'
            : question.trim();

        String prompt =
            'You are a Bedrock sales assistant. Answer ONLY using the context provided. '
            + 'If the context does not contain the answer, say so. Respond in locale ' + language + '.\n\n'
            + 'QUESTION: ' + safeQuestion + '\n\n'
            + 'CONTEXT:\n' + context;

        // Guard against oversized prompts (model + Apex heap/limits).
        if (prompt.length() > MAX_PROMPT_CHARS) {
            prompt = prompt.substring(0, MAX_PROMPT_CHARS) + '\n[context truncated]';
        }
        return prompt;
    }

    private static String nv(Object value) {
        return value == null ? 'n/a' : String.valueOf(value);
    }

    private static void log(String message) {
        // Centralised hook for observability; in production this could write to a custom log object
        // or Platform Event. Kept as debug here to avoid extra schema for the demo.
        System.debug(LoggingLevel.WARN, 'ClientInsightService: ' + message);
    }

    // ----- DTOs ------------------------------------------------------------

    public class InsightResult {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String answer;
        @AuraEnabled public String language;
        @AuraEnabled public Boolean usedLiveModel = false;
    }

    public class Request {
        @InvocableVariable(required=true label='Record Id') public Id recordId;
        @InvocableVariable(label='Advisor Question') public String question;
    }

    public class Response {
        @InvocableVariable(label='Answer') public String answer;
        @InvocableVariable(label='Language') public String language;
        @InvocableVariable(label='Used Live Model') public Boolean usedLiveModel;
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Error Message') public String errorMessage;
    }
}
