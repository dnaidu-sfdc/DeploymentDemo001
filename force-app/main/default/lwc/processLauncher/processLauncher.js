import { LightningElement, api, wire } from 'lwc';
// NavigationMixin lets the component navigate to record pages without hard-coding URLs.
import { NavigationMixin } from 'lightning/navigation';
// getRecord/getFieldValue read fields from the host record (used by Navigation actions to
// resolve a related record Id, e.g. Opportunity.AccountId) without an extra Apex call.
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// Cacheable Apex method that returns the metadata-driven actions for this object.
import getActions from '@salesforce/apex/ProcessLauncherController.getActions';

// Target_Type__c values understood by this component. Behaviour is data-driven: the admin
// sets the type on the Process_Action__mdt record and the LWC dispatches accordingly.
const TARGET_FLOW = 'flow';
const TARGET_NAVIGATION = 'navigation';

// NavigationMixin must wrap LightningElement to expose this[NavigationMixin.Navigate].
export default class ProcessLauncher extends NavigationMixin(LightningElement) {
    // Both injected automatically by Lightning on a record page. objectApiName is the key that
    // makes this component generic: the SAME component shows the right actions on any object.
    @api recordId;
    @api objectApiName;

    // App Builder design attribute: optional title override per placement (no code needed).
    @api cardTitle = 'Business Process';

    actions = [];
    // UI state flags that drive the conditional template (spinner / error / actions / empty).
    isLoading = true;
    hasError = false;
    errorMessage = '';

    // Informational ("Message") modal state.
    showModal = false;
    selectedAction = {};

    // Flow modal state: which flow to run and whether the flow modal is open.
    showFlowModal = false;
    flowApiName;

    // Cached host record, populated only when there are Navigation actions to resolve.
    record;

    // Reactively load the configured actions for the host object. The '$' makes objectApiName
    // reactive, so if the component is reused in a context where it changes, the wire re-runs.
    @wire(getActions, { objectApiName: '$objectApiName' })
    wiredActions({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.actions = data;
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.actions = [];
            // Surface the Apex error message, with a friendly fallback.
            this.errorMessage = error?.body?.message || 'Unable to load configured processes.';
        }
    }

    // Builds the list of fields that Navigation actions need to read from the host record,
    // e.g. ['Opportunity.AccountId']. Returns undefined when there are none, which keeps the
    // getRecord wire below from firing (a wire with an undefined param is not provisioned).
    get navigationFields() {
        if (!this.objectApiName || !this.actions || this.actions.length === 0) {
            return undefined;
        }
        const fields = this.actions
            .filter(
                (a) =>
                    (a.targetType || '').toLowerCase() === TARGET_NAVIGATION &&
                    a.targetName
            )
            .map((a) => `${this.objectApiName}.${a.targetName}`);
        return fields.length ? fields : undefined;
    }

    // Loads the host record's referenced fields so a Navigation action can resolve its target Id.
    @wire(getRecord, { recordId: '$recordId', fields: '$navigationFields' })
    wiredRecord({ data }) {
        if (data) {
            this.record = data;
        }
    }

    // Getters the template uses to decide which block to render.
    get hasActions() {
        return !this.isLoading && !this.hasError && this.actions.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.actions.length === 0;
    }

    // The component instance renders a single style, taken from the first configured action.
    // (All actions for one object share a display style; the admin sets it on the CMDT records.)
    get isChevron() {
        return this.hasActions && this.actions[0].displayStyle === 'chevron';
    }

    get isButtons() {
        return this.hasActions && this.actions[0].displayStyle === 'buttons';
    }

    // Input variables handed to every launched flow. The flow's "recordId" input variable
    // receives the host record's Id, so the flow knows which record it is acting on and can
    // "take over" from there (look up related data, create records, etc.).
    get flowInputVariables() {
        return [{ name: 'recordId', type: 'String', value: this.recordId }];
    }

    // Single entry point for all action types. We look up the clicked action and dispatch on
    // its configured Target_Type__c, so adding a new behaviour is a metadata change here.
    handleActionClick(event) {
        event.preventDefault();
        const key = event.currentTarget.dataset.key;
        const action = this.actions.find((a) => a.key === key);
        if (!action) {
            return;
        }
        this.selectedAction = action;

        const type = (action.targetType || '').toLowerCase();
        if (type === TARGET_FLOW) {
            this.launchFlow(action);
        } else if (type === TARGET_NAVIGATION) {
            this.navigateToTarget(action);
        } else {
            // Default/"Message": just show the informational modal.
            this.showModal = true;
        }
    }

    // FLOW: open the modal and let <lightning-flow> run the configured flow. Target_Name__c
    // holds the Flow API name, so business owners can swap the flow with no code change.
    launchFlow(action) {
        this.flowApiName = action.targetName;
        this.showFlowModal = true;
    }

    // NAVIGATION: read the related record Id from the field named in Target_Name__c
    // (e.g. AccountId on an Opportunity) and navigate to that record's page.
    navigateToTarget(action) {
        const fieldApiName = `${this.objectApiName}.${action.targetName}`;
        const targetId = this.record ? getFieldValue(this.record, fieldApiName) : null;

        if (!targetId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Nothing to open',
                    message: `No related record found in ${action.targetName}.`,
                    variant: 'warning'
                })
            );
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: targetId, actionName: 'view' }
        });
    }

    // Fired by <lightning-flow> as the interview progresses. When the flow finishes we close
    // the modal, confirm, and — if the flow returned a "redirectRecordId" output variable —
    // navigate there, letting the flow decide where the user lands.
    handleFlowStatus(event) {
        const status = event.detail.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            const outputs = event.detail.outputVariables || [];
            const redirect = outputs.find((o) => o.name === 'redirectRecordId');

            this.showFlowModal = false;
            this.flowApiName = undefined;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Done',
                    message: `${this.selectedAction.label} completed.`,
                    variant: 'success'
                })
            );

            if (redirect && redirect.value) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: redirect.value, actionName: 'view' }
                });
            }
        }
    }

    closeFlow() {
        this.showFlowModal = false;
        this.flowApiName = undefined;
    }

    closeModal() {
        this.showModal = false;
        this.selectedAction = {};
    }
}
