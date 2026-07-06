/**
 * Abstraction over the text-generation step of the RAG pipeline so the orchestration logic in
 * ClientInsightService does not depend on a specific model implementation. Swapping a live model
 * for the deterministic mock (or vice versa) is a one-line change and keeps the demo reliable.
 */
public interface LlmProvider {
    /**
     * @param prompt   Fully grounded prompt (retrieved context + the advisor's question).
     * @param language Target response language derived from the running user's locale.
     * @return Generated narrative answer.
     */
    String generate(String prompt, String language);
}
