/**
 * Live-model implementation of LlmProvider. It posts the grounded prompt to a model endpoint
 * exposed through the 'Einstein_Models_API' Named Credential (e.g. the Models API / a configured
 * GenAiPromptTemplate gateway) and returns the generated text.
 *
 * If the Named Credential is not configured or the callout fails, the exception propagates so the
 * orchestrator (ClientInsightService) can transparently fall back to MockLlmProvider. This keeps
 * the production path real while guaranteeing the demo never breaks.
 */
public with sharing class PromptTemplateProvider implements LlmProvider {
    private static final String NAMED_CREDENTIAL = 'callout:Einstein_Models_API';

    public String generate(String prompt, String language) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/generations');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        Map<String, Object> body = new Map<String, Object>{
            'prompt' => prompt,
            'localization' => new Map<String, Object>{ 'defaultLocale' => language }
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Model endpoint returned HTTP ' + res.getStatusCode());
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object generation = parsed.get('generation');
        if (generation == null) {
            generation = parsed.get('text');
        }
        return generation == null ? res.getBody() : String.valueOf(generation);
    }
}
