/**
 * Supplies the configured, per-object process actions for the generic processLauncher LWC.
 *
 * Actions are defined declaratively in the Process_Action__mdt custom metadata type, so business
 * owners (Sales, Support, HR, Marketing managers) can add or reorder steps without code changes.
 * Because the component is driven entirely by metadata keyed on the object API name, the same LWC
 * can be dropped on any record page and will render the actions relevant to that object.
 */
public with sharing class ProcessLauncherController {

    /**
     * Returns the active actions configured for the given object, already ordered for display.
     *
     * cacheable=true: read-only, so LWC can cache it and the @wire adapter re-runs automatically
     * when objectApiName changes. The LWC simply passes its own objectApiName, which means the
     * exact same component renders Opportunity actions on an Opportunity, Case actions on a Case, etc.
     *
     * @param objectApiName API name of the host record's object (the LWC provides this).
     */
    @AuraEnabled(cacheable=true)
    public static List<ActionConfig> getActions(String objectApiName) {
        List<ActionConfig> configs = new List<ActionConfig>();
        // Defensive guard: nothing to do without an object context.
        if (String.isBlank(objectApiName)) {
            return configs;
        }

        // Pull only the rows for THIS object that are flagged Active, ordered by Sort_Order__c.
        // NULLS LAST keeps un-numbered records at the bottom; Action_Label__c is a stable tie-break.
        // Reading metadata via SOQL means new/changed actions appear instantly with no code deploy.
        for (Process_Action__mdt action : [
            SELECT MasterLabel, Action_Label__c, Action_Type__c, Display_Style__c,
                   Icon__c, Sort_Order__c, Target_Type__c, Target_Name__c
            FROM Process_Action__mdt
            WHERE Object_API_Name__c = :objectApiName AND Active__c = true
            ORDER BY Sort_Order__c ASC NULLS LAST, Action_Label__c ASC
        ]) {
            // Map each CMDT row to a lightweight, serializable DTO for the LWC.
            configs.add(new ActionConfig(action));
        }
        return configs;
    }

    /**
     * Serializable view of a Process_Action__mdt record sent to the LWC.
     * We expose a curated DTO (rather than the raw SObject) so the client contract is explicit
     * and decoupled from the metadata field API names.
     */
    public class ActionConfig {
        @AuraEnabled public String key;          // unique key for list iteration / click lookup
        @AuraEnabled public String label;        // button/step text shown to the user
        @AuraEnabled public String actionType;   // how the action behaves (navigate, flow, etc.)
        @AuraEnabled public String displayStyle; // 'chevron' (path) or 'buttons'
        @AuraEnabled public String icon;         // SLDS icon name (e.g. utility:add)
        @AuraEnabled public Decimal sortOrder;   // surfaced for transparency/debugging
        @AuraEnabled public String targetType;   // what to launch (Flow, LWC, URL, ...)
        @AuraEnabled public String targetName;   // the specific target (API name / URL)

        public ActionConfig(Process_Action__mdt action) {
            // MasterLabel is the CMDT record's developer-facing label; used as a stable key.
            this.key = action.MasterLabel;
            this.label = action.Action_Label__c;
            this.actionType = action.Action_Type__c;
            // Normalize display style: default to 'chevron' and lowercase so the LWC comparison is safe.
            this.displayStyle = String.isBlank(action.Display_Style__c) ? 'chevron' : action.Display_Style__c.toLowerCase();
            this.icon = action.Icon__c;
            this.sortOrder = action.Sort_Order__c;
            this.targetType = action.Target_Type__c;
            this.targetName = action.Target_Name__c;
        }
    }
}
