/**
 * Deterministic, offline implementation of LlmProvider. It produces a coherent, grounded-looking
 * summary from the prompt without any external callout, so the component always demos successfully
 * even when the org has no live model configured. It intentionally only restates supplied context,
 * which also illustrates the anti-hallucination principle of grounding answers in retrieved data.
 */
public with sharing class MockLlmProvider implements LlmProvider {
    public String generate(String prompt, String language) {
        String langNote = String.isBlank(language) ? 'en_US' : language;
        return 'Summary (generated in ' + langNote + '):\n'
            + 'Based strictly on the retrieved Salesforce context below, here is a concise overview '
            + 'of this client\'s engagement. The advisor question and the grounding data were used to '
            + 'produce this answer; no information beyond the retrieved records was introduced.\n\n'
            + '----- Grounding context used -----\n'
            + prompt;
    }
}
