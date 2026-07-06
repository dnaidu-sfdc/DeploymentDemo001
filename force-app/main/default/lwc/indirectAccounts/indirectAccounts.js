import { LightningElement, api, wire } from 'lwc';
// Import the cacheable Apex method as a wire-able function. The '@salesforce/apex/...' module
// resolves to ClassName.methodName and works with both @wire (reactive) and imperative calls.
import getRelatedAccounts from '@salesforce/apex/IndirectAccountController.getRelatedAccounts';

// Column definitions for lightning-datatable. fieldName must match the @AuraEnabled property
// names returned by the Apex wrapper (RelatedAccount). 'currency'/'number' types format the
// values for us; sortable enables the column header sort affordance.
const COLUMNS = [
    { label: 'Account Name', fieldName: 'name', type: 'text', sortable: true },
    { label: 'Industry', fieldName: 'industry', type: 'text', sortable: true },
    {
        label: '# Contacts',
        fieldName: 'numberOfContacts',
        type: 'number',
        cellAttributes: { alignment: 'left' },
        sortable: true
    },
    {
        label: 'Lifetime Value',
        fieldName: 'lifetimeValue',
        type: 'currency',
        cellAttributes: { alignment: 'left' },
        sortable: true
    },
    {
        label: 'Relationships',
        fieldName: 'relationshipCount',
        type: 'number',
        cellAttributes: { alignment: 'left' },
        sortable: true
    }
];

export default class IndirectAccounts extends LightningElement {
    // recordId is injected automatically by Lightning when the component is on a record page.
    @api recordId;

    // App Builder design attributes (declared in the js-meta.xml targetConfig). Admins set these
    // per placement with NO code: how many rows to show and the initial sort field.
    @api maxItems = 5;
    @api defaultSortBy = 'relationshipCount';

    columns = COLUMNS;
    rows = [];
    // UI state flags drive the conditional markup (spinner / error / table / empty state).
    isLoading = true;
    hasError = false;
    errorMessage = '';
    // Tracks the datatable's current sort so the header arrow reflects the active column.
    sortedBy;
    sortedDirection = 'desc';

    // Lifecycle hook: runs once when the element is inserted. We translate the admin's chosen
    // default sort field into the datatable's initial sorted column + direction.
    connectedCallback() {
        this.sortedBy = this.defaultSortBy === 'name' ? 'name' : 'relationshipCount';
        this.sortedDirection = this.defaultSortBy === 'name' ? 'asc' : 'desc';
    }

    // @wire reactively calls the Apex method. The '$' prefix makes each parameter reactive:
    // whenever recordId / maxItems / defaultSortBy changes, the wire re-runs and the cached
    // result is reused when available (because the Apex method is cacheable=true).
    @wire(getRelatedAccounts, {
        accountId: '$recordId',
        maxItems: '$maxItems',
        sortBy: '$defaultSortBy'
    })
    wiredAccounts({ data, error }) {
        // The wire delivers either data or error; handle both and clear the loading state.
        this.isLoading = false;
        if (data) {
            this.rows = data;
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.rows = [];
            // error.body.message holds the AuraHandledException/Apex message; fall back to a generic one.
            this.errorMessage =
                error?.body?.message || 'Unable to load related accounts.';
        }
    }

    // Getters used by the template to decide which block to render.
    get hasRows() {
        return !this.isLoading && !this.hasError && this.rows.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError && this.rows.length === 0;
    }

    get cardTitle() {
        return 'Indirect Account Relationships';
    }

    get recordCountLabel() {
        return this.hasRows ? `${this.rows.length} related accounts` : '';
    }

    // Client-side re-sort when a user clicks a column header. Apex already returned the rows in
    // the default order; here we sort the in-memory copy so re-sorting is instant and doesn't
    // re-hit the server. We clone first because @api/@track arrays should be replaced, not mutated.
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        const cloned = [...this.rows];
        const multiplier = sortDirection === 'asc' ? 1 : -1;
        cloned.sort((a, b) => {
            // Null-safe comparison: default missing numbers to 0 and missing text to ''.
            const aVal = a[fieldName] ?? (typeof a[fieldName] === 'number' ? 0 : '');
            const bVal = b[fieldName] ?? (typeof b[fieldName] === 'number' ? 0 : '');
            if (aVal > bVal) return 1 * multiplier;
            if (aVal < bVal) return -1 * multiplier;
            return 0;
        });
        this.rows = cloned;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
    }
}
