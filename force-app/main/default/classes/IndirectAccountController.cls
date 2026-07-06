/**
 * Returns the indirect Account relationships for a given Account, derived from
 * the AccountContactRelation (Contacts-to-Multiple-Accounts) model.
 *
 * "Indirect" accounts are other Accounts that share one or more Contacts with the
 * Account being viewed. The number of shared Contacts is surfaced as the
 * relationship-occurrence count so the list can be sorted by relevance.
 *
 * Design notes (for discussion):
 *  - `with sharing` so the class runs in the context of the running user's record access.
 *  - All SOQL uses `WITH USER_MODE` so field-level security and sharing are enforced by the
 *    platform (defence in depth on top of `with sharing`).
 *  - The traversal is done with exactly TWO bulk queries (never SOQL inside a loop), keeping it
 *    governor-safe regardless of how many Contacts/relationships the Account has.
 */
public with sharing class IndirectAccountController {

    /**
     * @AuraEnabled(cacheable=true): exposes the method to LWC AND lets the Lightning Data Service
     * cache the result on the client. cacheable=true requires the method to be read-only (no DML),
     * which it is. The wire adapter in the LWC re-invokes this automatically when its inputs change.
     *
     * @param accountId  the Account whose record page is being viewed (the LWC passes recordId).
     * @param maxItems   max rows to return (an App Builder design attribute set by the admin).
     * @param sortBy     'relationshipCount' (default) or 'name' (also an App Builder attribute).
     */
    @AuraEnabled(cacheable=true)
    public static List<RelatedAccount> getRelatedAccounts(Id accountId, Integer maxItems, String sortBy) {
        // Guard clause: on a brand-new/blank context there may be no recordId yet.
        if (accountId == null) {
            return new List<RelatedAccount>();
        }

        // Defensive defaults so the method behaves even if the LWC passes null/empty inputs.
        Integer limitSize = (maxItems == null || maxItems <= 0) ? 5 : maxItems;
        String sortKey = String.isBlank(sortBy) ? 'relationshipCount' : sortBy;

        // ----------------------------------------------------------------------------------
        // STEP 1: Find every Contact connected to the Account being viewed.
        // AccountContactRelation (ACR) is the junction object behind "Contacts to Multiple
        // Accounts". Each row links one Account to one Contact (direct or indirect). Querying
        // ACR by AccountId therefore gives us all Contacts associated with this Account.
        // We collect them into a Set to de-duplicate and to drive the next bulk query.
        // ----------------------------------------------------------------------------------
        Set<Id> contactIds = new Set<Id>();
        for (AccountContactRelation acr : [
            SELECT ContactId
            FROM AccountContactRelation
            WHERE AccountId = :accountId
            WITH USER_MODE
        ]) {
            contactIds.add(acr.ContactId);
        }

        // If the Account has no related Contacts there can be no indirect Accounts.
        if (contactIds.isEmpty()) {
            return new List<RelatedAccount>();
        }

        // ----------------------------------------------------------------------------------
        // STEP 2: Find the OTHER Accounts those same Contacts are connected to.
        // We query ACR again, this time by the Contact set, excluding the original Account
        // (AccountId != :accountId) so we only get the "indirect" Accounts.
        // We aggregate in memory using a Map keyed by AccountId:
        //   - first time we see an Account, build its wrapper (name/industry/lifetime value);
        //   - every matching ACR row increments relationshipCount (how many shared Contacts);
        //   - we also track the distinct Contact Ids per Account for the "# Contacts" column.
        // One bulk query + in-memory aggregation = no SOQL in loops, fully bulk-safe.
        // ----------------------------------------------------------------------------------
        Map<Id, RelatedAccount> byAccount = new Map<Id, RelatedAccount>();
        for (AccountContactRelation acr : [
            SELECT AccountId, Account.Name, Account.Industry, Account.AnnualRevenue, ContactId
            FROM AccountContactRelation
            WHERE ContactId IN :contactIds AND AccountId != :accountId
            WITH USER_MODE
        ]) {
            RelatedAccount ra = byAccount.get(acr.AccountId);
            if (ra == null) {
                // First time we encounter this indirect Account: capture its display fields.
                ra = new RelatedAccount();
                ra.accountId = acr.AccountId;
                ra.name = acr.Account.Name;
                ra.industry = acr.Account.Industry;
                // Lifetime value is approximated by AnnualRevenue (documented assumption).
                ra.lifetimeValue = acr.Account.AnnualRevenue;
                byAccount.put(acr.AccountId, ra);
            }
            // Each ACR row is one shared Contact => the relevance/occurrence count.
            ra.relationshipCount++;
            ra.contactIds.add(acr.ContactId);
        }

        // Derive the "# Contacts" column from the distinct Contact set we accumulated.
        List<RelatedAccount> results = byAccount.values();
        for (RelatedAccount ra : results) {
            ra.numberOfContacts = ra.contactIds.size();
        }

        // Sort by the requested key, then cap to the admin-configured number of rows.
        sortResults(results, sortKey);

        if (results.size() > limitSize) {
            // Apex List has no subList(); build the capped list manually after sorting.
            List<RelatedAccount> trimmed = new List<RelatedAccount>();
            for (Integer i = 0; i < limitSize; i++) {
                trimmed.add(results[i]);
            }
            results = trimmed;
        }
        return results;
    }

    /**
     * Sorts the wrappers in place. We flag each item with the desired sort mode and delegate to
     * List.sort(), which calls RelatedAccount.compareTo() (the Comparable contract) for each pair.
     */
    private static void sortResults(List<RelatedAccount> results, String sortKey) {
        for (RelatedAccount ra : results) {
            ra.sortByName = ('name' == sortKey);
        }
        results.sort();
    }

    /**
     * DTO returned to the LWC. Only @AuraEnabled members are serialized to the client; the
     * internal helper fields below are used purely server-side for aggregation/sorting.
     * Implements Comparable so a List<RelatedAccount> can be sorted natively.
     */
    public class RelatedAccount implements Comparable {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String industry;
        @AuraEnabled public Decimal lifetimeValue;
        @AuraEnabled public Integer numberOfContacts = 0;
        @AuraEnabled public Integer relationshipCount = 0;

        // Internal helpers (NOT @AuraEnabled, so never sent to the LWC).
        // contactIds backs the distinct "# Contacts" count; sortByName selects the sort mode.
        public Set<Id> contactIds = new Set<Id>();
        public Boolean sortByName = false;

        /**
         * Comparable contract used by List.sort().
         * Return <0 to order 'this' before 'other', >0 to order it after, 0 if equal.
         */
        public Integer compareTo(Object other) {
            RelatedAccount that = (RelatedAccount) other;
            if (sortByName) {
                // Case-insensitive A->Z by Account name.
                String a = (name == null) ? '' : name.toLowerCase();
                String b = (that.name == null) ? '' : that.name.toLowerCase();
                return a.compareTo(b);
            }
            // Default: most-shared Accounts first (descending relationship count).
            return that.relationshipCount - relationshipCount;
        }
    }
}
