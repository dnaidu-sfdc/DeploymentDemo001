// Deploys the Process_Action__mdt seed records via the Apex Metadata API.
// Workaround for the file-based CustomMetadata deploy returning UNKNOWN_EXCEPTION in this org.

Metadata.DeployContainer container = new Metadata.DeployContainer();

Map<String, Map<String, Object>> records = new Map<String, Map<String, Object>>{
    'Process_Action.Opp_View_Customer' => new Map<String, Object>{
        'label' => 'Opp - View Customer',
        'Object_API_Name__c' => 'Opportunity',
        'Action_Label__c' => 'View Customer',
        'Action_Type__c' => 'View',
        'Display_Style__c' => 'chevron',
        'Icon__c' => 'utility:company',
        'Sort_Order__c' => 1,
        // Navigation: the LWC reads the field named in Target_Name__c (AccountId) from the
        // host record and navigates to that related record's page.
        'Target_Type__c' => 'Navigation',
        'Target_Name__c' => 'AccountId',
        'Active__c' => true
    },
    'Process_Action.Opp_Create_Order' => new Map<String, Object>{
        'label' => 'Opp - Create Order',
        'Object_API_Name__c' => 'Opportunity',
        'Action_Label__c' => 'Create Order',
        'Action_Type__c' => 'Create',
        'Display_Style__c' => 'chevron',
        'Icon__c' => 'utility:add',
        'Sort_Order__c' => 2,
        // Flow: the LWC launches the flow named in Target_Name__c and passes the host
        // record Id into the flow's recordId input variable.
        'Target_Type__c' => 'Flow',
        'Target_Name__c' => 'Bedrock_Create_Order',
        'Active__c' => true
    },
    'Process_Action.Opp_Log_Task' => new Map<String, Object>{
        'label' => 'Opp - Log Task',
        'Object_API_Name__c' => 'Opportunity',
        'Action_Label__c' => 'Log Task',
        'Action_Type__c' => 'Create',
        'Display_Style__c' => 'chevron',
        'Icon__c' => 'utility:task',
        'Sort_Order__c' => 3,
        'Target_Type__c' => 'Message',
        'Target_Name__c' => 'Creating a follow-up Task related to this Opportunity.',
        'Active__c' => true
    },
    'Process_Action.Opp_View_Hierarchy' => new Map<String, Object>{
        'label' => 'Opp - View Hierarchy',
        'Object_API_Name__c' => 'Opportunity',
        'Action_Label__c' => 'View Hierarchy',
        'Action_Type__c' => 'Hierarchy',
        'Display_Style__c' => 'chevron',
        'Icon__c' => 'utility:hierarchy',
        'Sort_Order__c' => 4,
        'Target_Type__c' => 'Message',
        'Target_Name__c' => 'Displaying the account hierarchy for this deal.',
        'Active__c' => true
    },
    'Process_Action.Case_Escalate' => new Map<String, Object>{
        'label' => 'Case - Escalate',
        'Object_API_Name__c' => 'Case',
        'Action_Label__c' => 'Escalate',
        'Action_Type__c' => 'Update',
        'Display_Style__c' => 'buttons',
        'Icon__c' => 'utility:priority',
        'Sort_Order__c' => 1,
        'Target_Type__c' => 'Message',
        'Target_Name__c' => 'Escalating this case to tier-2 support (demonstrates reuse on another object).',
        'Active__c' => true
    }
};

Set<String> fieldNames = new Set<String>{
    'Object_API_Name__c','Action_Label__c','Action_Type__c','Display_Style__c',
    'Icon__c','Sort_Order__c','Target_Type__c','Target_Name__c','Active__c'
};

for (String fullName : records.keySet()) {
    Map<String, Object> data = records.get(fullName);
    Metadata.CustomMetadata cm = new Metadata.CustomMetadata();
    cm.fullName = fullName;
    cm.label = (String) data.get('label');
    for (String f : fieldNames) {
        Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
        v.field = f;
        v.value = data.get(f);
        cm.values.add(v);
    }
    container.addMetadata(cm);
}

Id jobId = Metadata.Operations.enqueueDeployment(container, null);
System.debug('Enqueued CMDT deployment job: ' + jobId);
