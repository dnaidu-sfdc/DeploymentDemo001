# Bedrock Apex & Visualforce — Requirements Mapping, Thought Process & Trade-offs

This document is the reasoning artifact behind the solution. For each scenario requirement it records:

- **What is being asked** (in plain terms)
- **Classification** — does it need a built/demoed solution, a design, or pseudo-code? (and *why*, based on the scenario wording)
- **Options considered** with pros/cons
- **Decision and rationale** (the thought process)
- **Trade-offs & considerations** — scale, performance, governor limits, security, maintainability
- **Mapping to artifacts** — where it lives in this repo / org

Source documents: `docs/Bedrock Scenario - Apex & Visualforce - 2025.pdf`, presentation template `docs/DN - Bedrock Programmatic Scenario - Presentation.pptx.pdf`.

---

## 1. Classification legend

| Tag | Meaning | How it was decided |
| --- | --- | --- |
| **BUILD** | Working solution deployed to the org + code shown in IDE | Scenario explicitly says "deploy", "demo", "show your code", or the rubric assigns weight to *implementing* it |
| **DESIGN** | Architecture/approach only, no code | Scenario explicitly says "code is not required" / "propose a solution" |
| **PSEUDO-CODE** | Algorithm written as pseudo-code, not deployed | Scenario explicitly says "write pseudo code" |

---

## 2. Requirements traceability matrix

| # | Requirement (scenario) | Scenario wording that drove the decision | Classification | Primary platform feature |
| --- | --- | --- | --- | --- |
| S1 | Home-page map pinned to Bedrock HQ | "create the component in an IDE and deploy to an org… Be prepared to demo… Consider, but do not implement, testing/security" | **BUILD** | LWC `lightning-map` |
| S2 | Client Plan PDF + interactive JS map in the PDF | "Describe the challenges… propose a solution. **Code is not required.**" | **DESIGN** | Visualforce renderAs PDF + LWC map + Apex/ContentVersion |
| S3 | Process up to 1M staged quotes into standard Quotes | "Design a native solution… **Write pseudo code** of the solution." | **PSEUDO-CODE** | Batch Apex (`Database.Batchable`, `Stateful`) |
| S4A | Indirect Account relationships component | "custom Lightning Web Component… admins… App Builder… configurable… **Be prepared to show and discuss your code.**" | **BUILD** | LWC + Apex over `AccountContactRelation` |
| S4B | Dynamic, configurable, reusable, secure process component | "render as chevron or buttons… leverage the same component on other objects… **demonstrate your solution and show the code.**" | **BUILD** | LWC + Custom Metadata Type + Apex |
| S5a | Order auto-creation on Closed Won (scale) | "Bedrock may have thousands of line items… **Code is not required.**" | **DESIGN** | Async (Queueable/Batch) + Platform Event |
| S5b | Consolidate/coordinate event-driven logic | "recommendation… both declarative and programmatic options" | **DESIGN** | Trigger handler framework / Flow Orchestration |
| S5c | Enable/disable customization + manual override | "**Code is not required.**" | **DESIGN** | Hierarchy Custom Setting / Custom Permissions |
| S5d | Opportunity name pre-populated with Date+Time before Save | "**Code is not required.**" | **DESIGN** | LWC/quick action override of New |
| S6 | Customer 360 unified profile (Data Cloud) | "design a solution… identity resolution… nightly batches" | **DESIGN** | Data Cloud connectors, DMOs, identity resolution |
| S7 | AI assistant using RAG via Apex + LWC | Rubric: "able to **implement** RAG using Apex and integrate intelligent insights into LWC" (10%) | **BUILD** | Apex RAG orchestration + `@InvocableMethod` + LWC |

---

## 3. Per-requirement deep dive

### S1 — Sales-app Home Page map  → BUILD
**Ask:** A Home-page component showing a pin at `The Landmark @ One Market, Suite 300, San Francisco, CA 94105`, zoomed in but still showing the city, built with modern techniques in an IDE and deployed.

**Options considered**

| Option | Pros | Cons |
| --- | --- | --- |
| A. Base `lightning-map` component | No API key, auto-geocoding, mobile/accessible, minimal code, secure | Less control over map tiles/styling |
| B. Custom Google Maps JS via static resource | Full control, custom styling | API key management, billing, security review, LWS/CSP config, more code |

**Decision & rationale:** Option A. The brief explicitly rewards "modern and efficient techniques." A base component is the leanest, most maintainable, secure-by-default path and needs no Apex. Zoom level 16 is the sweet spot between street detail and the city label remaining visible.

**Trade-offs & considerations**
- *Performance:* renders client-side, no server round-trip, no Apex governor impact.
- *Security:* no Apex means no FLS/sharing surface; rely on Lightning Web Security. (Scenario said to *consider but not implement* security/testing — would add Jest tests + review CSP if going custom.)
- *Scale:* single static marker; trivial.

**Artifacts:** `force-app/main/default/lwc/bedrockHqMap/` (deployed to `AFCAPQA1`).

---

### S2 — Client Plan: interactive map → single-click PDF attached as a File  → DESIGN (code not required)
**Ask:**
- On the **Client Plan Lightning record page**, add an **interactive JavaScript map** that dynamically highlights the countries where Bedrock does business with this customer, plus key growth markets. This map renders **client-side, in the browser**.
- Provide a **single button** on that page that turns the current Client Plan — *including that map* — into a **PDF** and **attaches it to the Account as a File** (`ContentVersion`), with **no manual print-screen or save-as**. Today users print-screen precisely because no automated bridge exists.

**The core challenge (the crux to articulate): a client/server gap, not "JS inside a PDF".**
The map and the document are produced in two different places:
- The interactive map's pixels exist **only in the browser**, drawn at runtime by JavaScript (canvas/SVG/WebGL) from this customer's data.
- The Client Plan PDF is generated **server-side** (Apex / Visualforce `renderAs="pdf"`). The server **has no visibility into what the browser rendered** — it never sees the live map.

So the real question is: **how do you get the browser-rendered map into a server-generated PDF automatically, on one click?** (A secondary, related fact — that you can't just drop the JS-map markup into a VF PDF page and expect it to self-render, because the server-side PDF path has no JavaScript runtime — is *why the naive approach fails*, but it is not the heart of the requirement.)

**Options considered**

| Option | How it bridges client → server | Pros | Cons |
| --- | --- | --- | --- |
| A. Capture client-side, generate server-side | LWC asks the map library for an image of its current state (canvas `toDataURL()` / `html2canvas`), passes the base64 image + record context to Apex; Apex composes the Client Plan PDF (Account/Contact data, pipeline, entitlements + the captured map image) and saves it as a `ContentVersion` | One click, no print-screen, PDF faithfully shows what the advisor sees, fully in-platform | Image is a snapshot (static in the PDF); relies on the map lib exposing an export |
| B. Regenerate the map server-side as a static image | Apex re-creates the same map via a static-map image service using the same country set, embeds it in the VF PDF | No client capture needed | Duplicates the "which countries" logic in two places; can drift from the on-screen map |
| C. Headless-browser service | A real browser (e.g., headless Chrome on Heroku) loads the live page, runs the JS so the map fully renders, then prints the whole page to PDF | Highest fidelity to the live page | Extra infrastructure, callout, cost, maintenance; rarely justified since a PDF is static anyway |

**Decision & rationale:** Option A — **capture-and-pass**. The interactive map stays an LWC on the record page; the single button captures the rendered map as an image, hands it to Apex, and Apex generates the Client Plan PDF and attaches it as a File on the Account. This is one click, removes print-screen/save-as, faithfully reflects what the advisor sees, and stays entirely on-platform. Option B is the fallback if the map library can't export an image; Option C only if pixel-perfect rendering of the *entire* live page in the document ever becomes a hard requirement.

**Trade-offs & considerations**
- *Client/server bridge:* the whole design hinges on moving the browser-rendered map to the server; capture-and-pass keeps that bridge simple and in-platform.
- *Fidelity vs complexity:* A reflects exactly what's on screen with no extra infra; C is more faithful for the full page but adds a service and a callout; B avoids client capture at the cost of duplicated logic that can drift.
- *Performance/limits:* building the PDF `Blob` in Apex consumes heap and the base64 image inflates payload size — keep the plan lean, constrain image resolution, paginate large plans, and generate asynchronously if the document is heavy.
- *UX:* single-click generate + auto-attach removes manual steps; the on-screen map remains fully interactive.

**Artifacts:** Design only (covered on the "Client Plans" slide). No code per the scenario.

---

### S3 — High-volume quote processing  → PSEUDO-CODE
**Ask:** Nightly, process up to **1M** `Healthcare_Quote_Staging__c` rows (+ up to 10 detail rows each) into standard `Quote`/`QuoteLineItem` linked to Accounts, natively, with no advanced ETL.

**Options considered (execution context):** the heart of this requirement is choosing the right Apex execution context for ~1M parent rows (+ up to 10 children each). Each option below runs under different governor limits.

| Option | Per-run capacity | Fit for 1M rows | Verdict |
| --- | --- | --- | --- |
| **Synchronous** (trigger / button / single transaction) | 50k SOQL rows, 10k DML rows, 6 MB heap, 10s CPU | Impossible — exceeds every limit by orders of magnitude | Rejected |
| **`@future`** | Single async transaction: 50k SOQL rows, 10k DML rows, 12 MB heap; primitives-only args; no chaining; hard to monitor | Can't scan/process 1M in one transaction; no chunking; can't pass sObjects | Rejected |
| **Queueable** | Single async transaction (same 50k/10k/12 MB limits); typed state; supports chaining + callouts | Can't process 1M in one run. Self-chaining would require hand-rolled keyset pagination (SOQL `OFFSET` caps at 2000), a manual cursor, and DIY tallies — reinventing Batch with weaker monitoring | Rejected as the primary engine; good for follow-up orchestration |
| **Batch Apex** (`Database.Batchable` + `Stateful`) | `start()` returns a `QueryLocator` that can address up to **50M** rows; the platform retrieves them and divides them into `execute()` scopes (default 200, up to 2000); **each scope gets fresh governor limits**; built-in job monitoring, scope control, restartability | Designed exactly for this volume | **Chosen** |
| **Scheduled Apex** | Not a processing engine — a *trigger mechanism* | Used to *initiate* the batch at 11pm (or fire it from a Platform Event) | Complementary, not an alternative |

**Decision & rationale:** **Batch Apex.** Only Batch can process millions of rows by dividing a `QueryLocator` result set into chunks and resetting governor limits per chunk, which is precisely what 1M parents + child details demand. Synchronous and `@future` can't hold the volume in a single transaction; Queueable would mean hand-building pagination, cursor state, and tallies that Batch provides natively (with better operability). Queueable/`@future` remain the right tools for *smaller* volumes, callout sequencing, or chained follow-up work — and Batch's `finish()` can chain a Queueable/second Batch if needed.

**Design elements & rationale**
- **Initiation:** `Schedulable` at 11pm, *chained after* the middleware load — or, more robustly, fired by a Platform Event the middleware publishes when the load completes (avoids race conditions with the 11pm clear/populate).
- **Encapsulation:** mapping + upsert logic in a service class → unit-testable, reusable, single responsibility.
- **Idempotency:** **upsert by External Id** so re-runs update rather than duplicate.
- **Error handling:** `Database.upsert(records, false)` (allOrNone=false) so clean rows commit; failures captured to a `Quote_Load_Error__c` log object (not silently lost); `Database.Stateful` accumulates processed/failed tallies for the `finish()` notification.
- **Scope size:** ~200 (not 2000) because each parent also drives child detail DML — protects against per-transaction DML/CPU limits.
- **Staging cleanup:** the 11pm integration *clears then re-populates* staging at the start of each cycle, but our batch also **deletes the staging rows it has successfully processed** (parents + their details), within `execute()`, so (a) the staging area doesn't accumulate, (b) a re-run/restart never reprocesses the same rows, and (c) **failed** rows are intentionally **retained** (and logged) for investigation rather than deleted.

**Pseudo code (verbose)**

```
// ============================================================
// 1) INITIATION  (Scheduled Apex, fired at 11pm AFTER the load)
// ============================================================
global class QuoteStagingScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Scope size 200: each parent also queries/►upserts up to 10 child details,
        // so keep per-scope DML/CPU well within limits.
        Database.executeBatch(new QuoteStagingBatch(), 200);
    }
}
// Alternatively, subscribe to a "StagingLoadComplete__e" Platform Event the middleware
// publishes when its populate step finishes, and call executeBatch there — this avoids
// any race with the 11pm clear/populate window.

// ============================================================
// 2) BULK PROCESSING  (Batch Apex + Stateful for run-level tallies)
// ============================================================
global class QuoteStagingBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    global Integer quotesUpserted = 0;
    global Integer linesUpserted  = 0;
    global Integer failedRows     = 0;

    // ---- start: return the staging parents (QueryLocator can address up to 50M rows) ----
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, External_Id__c, Account_Ext_Id__c, Status__c, Expiration__c, ' +
            '       Total__c, LastModified_Source__c ' +
            'FROM Healthcare_Quote_Staging__c ' +
            // Optional guard so partial re-runs only pick up not-yet-processed rows.
            'WHERE Processed__c = false ' +
            'ORDER BY Account_Ext_Id__c'
        );
    }

    // ---- execute: runs once per scope (~200 rows), fresh governor limits ----
    global void execute(Database.BatchableContext bc,
                        List<Healthcare_Quote_Staging__c> scope) {
        Savepoint sp = Database.setSavepoint();   // optional, for scope-level safety
        try {
            // -- 2a. Resolve Accounts in bulk (no SOQL in loops) --
            Set<String> acctExtIds = new Set<String>();
            for (Healthcare_Quote_Staging__c s : scope) acctExtIds.add(s.Account_Ext_Id__c);

            Map<String, Id> accountIdByExtId = new Map<String, Id>();
            for (Account a : [SELECT Id, External_Id__c
                              FROM Account
                              WHERE External_Id__c IN :acctExtIds
                              WITH USER_MODE]) {
                accountIdByExtId.put(a.External_Id__c, a.Id);
            }

            // -- 2b. Map staging -> standard Quote (idempotent: keyed by External Id) --
            List<Quote> quotesToUpsert = new List<Quote>();
            Map<String, Healthcare_Quote_Staging__c> stagingByExtId =
                new Map<String, Healthcare_Quote_Staging__c>();
            List<Healthcare_Quote_Staging__c> unresolved =
                new List<Healthcare_Quote_Staging__c>();

            for (Healthcare_Quote_Staging__c s : scope) {
                Id acctId = accountIdByExtId.get(s.Account_Ext_Id__c);
                if (acctId == null) {                 // can't link -> log, don't delete
                    logError(s.External_Id__c, 'No matching Account for ' + s.Account_Ext_Id__c);
                    unresolved.add(s);
                    failedRows++;
                    continue;
                }
                Quote q = new Quote(
                    QuoteExternalId__c = s.External_Id__c,   // External Id => upsert key
                    Name               = 'Quote ' + s.External_Id__c,
                    // OpportunityId / AccountId association per your data model
                    ExpirationDate     = s.Expiration__c,
                    Status             = s.Status__c
                );
                quotesToUpsert.add(q);
                stagingByExtId.put(s.External_Id__c, s);
            }

            // -- 2c. Upsert Quotes by External Id, allOrNone=false (partial success) --
            Schema.SObjectField key = Quote.QuoteExternalId__c;
            Database.UpsertResult[] qRes = Database.upsert(quotesToUpsert, key, false);

            Set<String> succeededExtIds = new Set<String>();
            Map<String, Id> quoteIdByExtId = new Map<String, Id>();
            for (Integer i = 0; i < qRes.size(); i++) {
                String extId = quotesToUpsert[i].QuoteExternalId__c;
                if (qRes[i].isSuccess()) {
                    quotesUpserted++;
                    succeededExtIds.add(extId);
                    quoteIdByExtId.put(extId, qRes[i].getId());
                } else {
                    logError(extId, errText(qRes[i].getErrors()));
                    failedRows++;
                }
            }

            // -- 2d. Load child detail rows for the parents we just processed --
            //         (up to 10 per parent; bulk query, no SOQL-in-loop)
            List<QuoteLineItem> linesToUpsert = new List<QuoteLineItem>();
            for (Healthcare_QuoteDetail_Staging__c d : [
                    SELECT Id, Detail_External_Id__c, Quote_Ext_Id__c,
                           Product_Code__c, Quantity__c, UnitPrice__c
                    FROM Healthcare_QuoteDetail_Staging__c
                    WHERE Quote_Ext_Id__c IN :succeededExtIds
                    WITH USER_MODE]) {

                Id quoteId = quoteIdByExtId.get(d.Quote_Ext_Id__c);
                if (quoteId == null) continue;
                linesToUpsert.add(new QuoteLineItem(
                    LineExternalId__c = d.Detail_External_Id__c,   // upsert key for lines
                    QuoteId           = quoteId,
                    // PricebookEntryId resolved from Product_Code__c in a real impl
                    Quantity          = d.Quantity__c,
                    UnitPrice         = d.UnitPrice__c
                ));
            }

            // -- 2e. Upsert line items (partial success) --
            if (!linesToUpsert.isEmpty()) {
                Database.UpsertResult[] lRes =
                    Database.upsert(linesToUpsert, QuoteLineItem.LineExternalId__c, false);
                for (Integer i = 0; i < lRes.size(); i++) {
                    if (lRes[i].isSuccess()) linesUpserted++;
                    else { logError(linesToUpsert[i].LineExternalId__c,
                                    errText(lRes[i].getErrors())); failedRows++; }
                }
            }

            // -- 2f. CLEAR STAGING for successfully processed rows only --
            //         Delete processed parents + their details; KEEP failed rows for review.
            if (!succeededExtIds.isEmpty()) {
                delete [SELECT Id FROM Healthcare_QuoteDetail_Staging__c
                        WHERE Quote_Ext_Id__c IN :succeededExtIds];
                delete [SELECT Id FROM Healthcare_Quote_Staging__c
                        WHERE External_Id__c IN :succeededExtIds];
                // (If you prefer a soft delete, set Processed__c = true instead of delete.)
            }
        }
        catch (Exception e) {
            Database.rollback(sp);                 // keep this scope atomic on hard failure
            logError('SCOPE', e.getMessage() + ' / ' + e.getStackTraceString());
            failedRows += scope.size();
        }
    }

    // ---- finish: notify ops; chain follow-up work if required ----
    global void finish(Database.BatchableContext bc) {
        // Send summary (email / Platform Event): quotesUpserted, linesUpserted, failedRows.
        // Optionally chain: if any Healthcare_Quote_Staging__c remain, enqueue next run,
        // or kick a downstream Queueable (e.g., notify integration that processing is done).
    }

    // ---- helpers ----
    private void logError(String sourceKey, String message) {
        // Insert Quote_Load_Error__c (Source_Key__c, Message__c, Run_Id__c, CreatedDate).
        // Bulk these in a real impl rather than inserting one-by-one.
    }
    private String errText(Database.Error[] errs) {
        List<String> parts = new List<String>();
        for (Database.Error err : errs) parts.add(err.getStatusCode() + ': ' + err.getMessage());
        return String.join(parts, '; ');
    }
}

// ============================================================
// 3) TESTING  (illustrative)
// ============================================================
@isTest
private class QuoteStagingBatchTest {
    @isTest static void processesCreatesUpdatesAndClearsStaging() {
        // Given: Accounts (with External_Id__c) + staging parents/details, incl. one bad row.
        Test.startTest();
        Database.executeBatch(new QuoteStagingBatch(), 200);
        Test.stopTest();
        // Then: assert Quotes/QuoteLineItems upserted, bad row logged in Quote_Load_Error__c,
        //       successfully processed staging rows deleted, failed rows retained.
    }
}
```

**Trade-offs & considerations**
- *Scale:* a `QueryLocator` can address up to 50M rows, which the platform processes in chunks; 1M is comfortable.
- *Performance vs safety:* smaller scope = more transactions but safer governor headroom with child DML; tune by measuring.
- *Resilience:* partial-success + error log means one bad row doesn't fail a 1M-row run.
- *Testing:* `@isTest` with `Test.startTest/stopTest` over a representative staging set; assert created vs updated, bad rows logged, limits respected.

**Artifacts:** Pseudo-code on the "Quote Processing" slides. Not deployed (scenario asks for pseudo-code).

---

### S4A — Indirect Accounts component  → BUILD
**Ask:** On the Account record, show indirect Account relationships via shared Contacts (name, industry, # contacts, lifetime value, …); admin-placeable in App Builder; configurable item count and sort (name | relationship frequency).

**Thought process:** "Indirect" = other Accounts reachable through this Account's Contacts. The `AccountContactRelation` junction (Contacts-to-Multiple-Accounts, confirmed enabled in the org) is the natural model: read this Account's Contacts, then the *other* Accounts those Contacts relate to, and **count the occurrences** as the relevance signal.

**Options considered**

| Option | Pros | Cons |
| --- | --- | --- |
| A. LWC + Apex (`@AuraEnabled cacheable`) over `AccountContactRelation` | Full control, caching, configurable, testable | Custom code to maintain |
| B. Report/related list | No code | Can't compute indirect traversal + occurrence count or expose design attributes |

**Decision & rationale:** Option A. Only code can traverse the junction, aggregate occurrence counts, and expose App Builder design attributes.

**Trade-offs & considerations**
- *Performance:* `@AuraEnabled(cacheable=true)` enables client caching; single-pass aggregation in a `Map`; bounded result set.
- *Governor limits:* two bulk SOQL queries (contacts, then related ACRs), no SOQL-in-loops.
- *Security:* `WITH USER_MODE` enforces FLS + sharing; only whitelisted fields returned.
- *Configurability (the how/why):* `targetConfig` design attributes `maxItems` (1–50) and `defaultSortBy` (`relationshipCount` | `name`) let admins reconfigure with no deploy; sorting also available interactively in the datatable.

**Artifacts:** `lwc/indirectAccounts/`, `classes/IndirectAccountController.cls`, `classes/IndirectAccountControllerTest.cls` (deployed; tests pass).

---

### S4B — Dynamic Process Launcher  → BUILD
**Ask:** Regional Sales Managers define dynamic, attribute-driven processes; admins drop a component on Opportunity (and reuse on other objects for Support/HR/Marketing); renders chevrons or buttons; each opens a modal for a specific process; must be secure (no inadvertent data exposure to third-party AppExchange components) and look native.

**Thought process:** Three forces shape this: (1) **dynamic configuration by business users** → drive everything from **Custom Metadata** (not hard-coded); (2) **reuse across objects** → a *generic* LWC that reads `objectApiName`/`recordId` and looks up config keyed by object; (3) **security in a regulated industry** → isolation so other components can't read this one's data.

**Options considered**

| Concern | Option chosen | Alternatives rejected (why) |
| --- | --- | --- |
| Configuration store | **Custom Metadata Type** `Process_Action__mdt` | Custom Settings (not as deploy-friendly/typed for this); hard-coding (not "dynamic/by managers") |
| Reusability | One generic LWC on `lightning__RecordPage`, object-agnostic | One component per object (not DRY, won't scale to HR/Marketing) |
| Rendering | SLDS path (chevron) or `lightning-button-group` | Custom CSS widgets (breaks "native look & feel") |
| What an action *does* | **`Target_Type__c` dispatch** — `Flow`, `Navigation`, or `Message` | Hard-coding behaviour per action in JS (defeats "managers define processes") |
| Security/isolation | Lightning Web Security + no record data on shared message channels; minimal `@api` | Broadcasting on a global LMS channel (leaks to unauthorized components) |

**Decision & rationale:** Metadata-driven generic LWC. Adding/reordering a process = adding a `Process_Action__mdt` row, **no code or deploy**. The same component instance renders chevrons on Opportunity and buttons on Case purely from configuration.

**Action behaviour is also metadata-driven.** Each record's `Target_Type__c` tells the LWC *how* to run the step, and `Target_Name__c` supplies the parameter:

| `Target_Type__c` | `Target_Name__c` holds | What the LWC does | Shipped example |
| --- | --- | --- | --- |
| `Flow` | Flow API name | Opens a modal hosting `<lightning-flow>`, runs that flow, and passes the host record Id into the flow's **`recordId`** input variable. The flow then "takes over" the UX (lookups, screens, DML). On finish, if the flow returns a `redirectRecordId` output variable the LWC navigates there. | **Create Order** → `Bedrock_Create_Order` screen flow (gets the Opportunity, collects order details, logs an order-request Task linked via `WhatId = recordId`). |
| `Navigation` | relationship field API name | Reads that field off the current record (via `getRecord`) and uses `NavigationMixin` to open the referenced record's page. | **View Customer** → `AccountId` (opens the Opportunity's Account/Customer page). |
| `Message` | message body | Shows an informational SLDS modal (lightweight placeholder for design-only steps). | Log Task, View Hierarchy, Case → Escalate. |

This is the crux of the requirement: **the flow name (and the navigation target) are configuration, not code.** Swapping the Create Order flow for a different flow, or pointing View Customer at a different relationship field, is a one-field metadata edit with no deployment. The flow receives the record context automatically and owns the rest of the journey.

**Trade-offs & considerations**
- *Flow vs. hard-coded screens:* delegating to Flow lets business owners change the multi-step process themselves; the LWC stays a thin, generic launcher. The contract between LWC and flow is a single convention — an input variable named `recordId` (and an optional `redirectRecordId` output) — kept deliberately small.
- *Navigation without a flow:* opening a directly-related record (View Customer) doesn't justify a flow, so it's a pure `NavigationMixin` call driven by the relationship-field name in metadata — faster for the user and still fully configurable.
- *Security (key ask):* LWS isolates the component; it does **not** publish record data to shared channels, so unauthorized AppExchange components can't read it unless explicitly integrated; the public surface is minimal `@api` properties. Flows run in the user's context and honour FLS/sharing.
- *Look & feel:* built entirely with SLDS to match Lightning Experience.
- *Performance:* `getActions` is `cacheable=true`, `WITH USER_MODE`; the `getRecord` wire only fires when Navigation actions exist (its field list is `undefined` otherwise); config volume is tiny.
- *Extensibility:* new object support, new steps, and new behaviours are data, not code.

**Artifacts:** `lwc/processLauncher/`, `classes/ProcessLauncherController.cls`, `classes/ProcessLauncherControllerTest.cls`, `objects/Process_Action__mdt/`, `flows/Bedrock_Create_Order.flow-meta.xml` (the configurable Create Order screen flow), seed records in `customMetadata/` (deployed; records seeded via Apex Metadata API — see note in §4).

---

### S5a — Order sync on Closed Won (scale)  → DESIGN
**Ask:** On Closed Won, create an Order, sync Opportunity line items to order line items, set "Ready for Integration", and notify the ESB; must scale to thousands of line items per Opportunity.

**Decision & rationale:** Trigger detects the stage change, but the **line-item sync runs asynchronously** (Queueable, or Batch for very large sets) to stay within DML/CPU limits at thousands of lines. Emit a **Platform Event** to the ESB rather than a synchronous callout — decouples Salesforce from the Sales Order Processing system and is bulk/retry friendly.

**Trade-offs & considerations**
- *Scale/limits:* async avoids hitting limits on big line-item sets; bulkified DML.
- *Reliability:* event-based hand-off survives downstream outages (replayable) vs a brittle sync callout.
- *Ordering:* the "Ready for Integration" flag + event ensures the ESB only pulls complete orders.

---

### S5b — Coordinating event-driven logic (extensibility)  → DESIGN
**Ask:** Stop logic being scattered across classes/tools with unknown execution order; recommend declarative + programmatic options.

**Decision & rationale:** **One trigger per object** delegating to a **handler / Trigger Actions Framework** that makes execution order explicit and centrally registered (programmatic). Declarative counterpart: **Flow + Flow Orchestration** for ordered, multi-step processes. Recommend standardizing on a single framework so order is deterministic and logic is discoverable.

**Trade-offs & considerations**
- *Maintainability:* known order, single entry point, easier onboarding.
- *Declarative vs programmatic:* Flow for admin-owned/low-complexity steps; Apex handlers for complex, bulk, or performance-sensitive logic.

---

### S5c — Enable/disable customization + override  → DESIGN
**Ask:** Turn large chunks of customization on/off by user or profile, with a manual override to suspend logic during big data loads, then re-apply.

**Decision & rationale:** A **hierarchy Custom Setting** (org/profile/user) and/or **Custom Permissions** that every automation checks at entry; plus a global **"bypass automation"** switch so a data load can suspend logic and re-enable afterward. Both declarative (Flow entry conditions) and programmatic (handler guard clauses) honor the same switch.

**Trade-offs & considerations**
- *Data loads:* bypass prevents triggers/flows from firing on millions of inserted rows (performance + correctness), with a defined re-apply step afterward.
- *Governance:* profile/user granularity supports phased rollout.

---

### S5d — Opportunity name pre-population (Date+Time, before Save)  → DESIGN
**Ask:** When a user creates a new Opportunity, the **Name** must already be filled with the current **Date+Time** on the standard create form **before the user clicks Save**, and it must behave identically whether they start from the **Account related-list "New"** or the **Opportunity tab/global "New"**.

**The catch — why the obvious declarative tools don't fit:**
- A **before-save record-triggered Flow** (or a `before insert` trigger) only fires *when the user clicks Save*. The requirement is explicitly *before* Save, while the form is on screen, so the user can see/edit the value. That rules out save-time automation.
- A **default value on the field** can't help either: the standard **Opportunity Name** field doesn't expose a default-value formula, and even where defaults exist they're evaluated at create time, not as a live `NOW()` painted into the input.
- A **Quick Action with predefined field values** can pre-fill fields, but predefined values are static / source-record formulas — they can't inject the *current* timestamp at the moment the form opens, and a global/tab "New" doesn't run an object Quick Action.

So the only way to put a *dynamic* value into the standard form *before* Save is to **take over the New action** and pre-seed the field as the form renders.

**Options considered**

| Option | How it works | Why not / caveats |
| --- | --- | --- |
| A. Custom "New" **List Button** (URL/`defaultFieldValues`) | Replace the standard New button on the Account related list and list views with a custom button that opens the create form with the Name prefilled | Must be re-pointed on **every** list view and related list; **doesn't cover the tab/global New**, so behaviour is inconsistent — fails "both entry points" |
| B. **Override the standard New action** (chosen) | Override Opportunity → **New** once; a component computes the timestamp and forwards to the standard form with the Name pre-filled | One override covers **related list *and* tab/global New**; the catch is it must be an **Aura** override and must avoid recursion (see below) |

**Decision & rationale:** Override the **standard New action** on Opportunity (Option B), because a single override is honoured from *both* launch points, giving the consistency the requirement demands.

**Mechanism (the important details):**
1. **It must be Aura, not LWC.** Standard action overrides only accept a Visualforce page or an **Aura** component (`lightning:actionOverride`). An LWC **cannot** be selected directly — so the override is a thin Aura wrapper (which may in turn host an LWC, but the logic is small enough to live in the wrapper).
2. **Compute the value and forward to the standard form** using the navigation service with `defaultFieldValues`. The values must be URL-encoded with `encodeDefaultFieldValues`:

```js
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
// ...
const defaults = encodeDefaultFieldValues({
    Name: `Opportunity - ${new Date().toLocaleString()}`
});
this[NavigationMixin.Navigate]({
    type: 'standard__objectPage',
    attributes: { objectApiName: 'Opportunity', actionName: 'new' },
    state: {
        nooverride: '1',                 // CRITICAL — see #3
        defaultFieldValues: defaults
    }
});
```

3. **`nooverride: '1'` is the trap everyone hits.** Our override navigates to the Opportunity *New* page — which is the very action we just overrode. Without a guard that would call our component again → **infinite recursion**. Passing `nooverride: '1'` in the navigation `state` tells the platform "use the **built-in** New form this time, not my override," which breaks the loop and lands the user on the real standard create page with the Name already populated.

(The older Aura `e.force:createRecord` event accepts `defaultFieldValues` too, but the navigation-service + `nooverride` approach is the reliable, documented way to both prefill *and* avoid the recursion.)

**Trade-offs & considerations**
- *Consistency (the key ask):* one New-action override is honoured from the related list and the tab/global New, so the timestamped name appears everywhere — no per-list-view maintenance.
- *Aura requirement:* a small Aura shell is unavoidable for a standard-action override; keep all real logic minimal/in an LWC if reused elsewhere.
- *Recursion:* `nooverride: '1'` is mandatory; without it the page loops.
- *Before Save, editable:* the value is painted into the standard form, so the user sees it and can still change it before saving — satisfying "before hitting Save" literally.
- *Locale/format:* format the timestamp with the user's locale (or a fixed business format) rather than a raw ISO string.
- *Code-not-required:* this is a **DESIGN** item — the override is described and sketched, not built, per the scenario ("Code is not required").

---

### S6 — Customer 360 with Data Cloud  → DESIGN
**Ask:** Unify CRM, quote back-end, service, marketing/ERP into one profile with identity resolution; keep current near-real-time or nightly; surface to advisors; scale to millions; bulk-safe write-back.

**Decision & rationale:** Ingest via **connectors / Ingestion API** (not CSV) into **DMOs**; map sources consistently to the Customer 360 model; **identity resolution** rules merge duplicates; resolve attribute conflicts via source-precedence / recency rules. Refresh streaming where possible, otherwise efficient **nightly (11pm) deltas**. Surface via Data Cloud-related components or a custom LWC on Account/Contact. Any **write-back to core must be bulk-safe** and governor-aware.

**Trade-offs & considerations**
- *Scale:* Data Cloud is built for large volumes; the risk is the *write-back* to core — must be bulk-safe.
- *Data quality:* identity resolution + conflict rules are the crux; test that merges are correct.
- *Synergy:* this unified profile becomes the richest **retrieval source for the RAG assistant (S7)**.

---

### S7 — AI assistant with RAG via Apex + LWC  → BUILD
**Ask:** Advisors ask natural-language questions about a client; a Generative AI answers using the 360 profile + related data via **Retrieval-Augmented Generation**, implemented in Apex, surfaced in an LWC, configurable in App Builder, with language control, logging, and reliability (the scenario also flags that Prompt Templates called directly from Flow can't adapt language and lack logging/error handling).

**Thought process — RAG in three explicit steps:**
1. **Retrieve** — Apex queries grounding data (Account, recent Opportunities, Cases, attached account-plan files) `WITH USER_MODE`, bulk-safe with row caps.
2. **Augment** — assemble a **size-bounded** prompt (protects prompt/heap limits), inject the **running user's locale** for language, instruct the model to answer *only* from context.
3. **Generate** — call the model behind an `LlmProvider` interface.

**Options considered**

| Option | Pros | Cons |
| --- | --- | --- |
| A. Prompt Template invoked directly from Flow | Low-code | Can't adapt language to locale; no custom logging/error handling/pre-processing (exactly the scenario's pain points) |
| B. **Apex-orchestrated RAG** (chosen), exposed to LWC + Flow | Language control, logging, error handling, input pre-processing, testable, reusable | More code |

**Decision & rationale:** Option B. Apex adds precisely what Flow-only lacks. The generation step is an **interface** with two implementations — a **live provider** (Named Credential to the Models API / prompt-template gateway) and a **deterministic mock** — selected by config with **automatic fallback**, so the demo is always reliable and the production path is real. Exposed as `@AuraEnabled` (LWC) **and** `@InvocableMethod` so the existing Screen Flow gains Apex language/logging/error handling without losing its declarative simplicity.

**Trade-offs & considerations**
- *Governor/prompt limits:* prompt is truncated to a safe size; retrieval is capped and bulk-safe.
- *Hallucination mitigation:* answer strictly from retrieved context; UI disclaimer; answer validation hook; (extendable with few-shot/templates).
- *OOP:* the provider interface demonstrates polymorphism/strategy — swap models without touching orchestration.
- *Reliability:* mock fallback guarantees a working demo even with no live model; flip one flag + a Named Credential to go live.
- *Security:* `WITH USER_MODE` retrieval; no data leaves the platform unless the live provider is explicitly configured.

**Artifacts:** `classes/ClientInsightService.cls`, `classes/LlmProvider.cls`, `classes/MockLlmProvider.cls`, `classes/PromptTemplateProvider.cls`, `classes/ClientInsightServiceTest.cls`, `lwc/clientInsight/` (deployed; tests pass).

---

## 4. Cross-cutting considerations

| Concern | How it's addressed across the solution |
| --- | --- |
| **Governor limits** | Bulkified SOQL/DML, no queries in loops, `cacheable` reads, batch scope tuning, size-bounded AI prompts, async for large work (orders, quotes). |
| **Scale** | Batch Apex for 1M quotes; async + Platform Events for large order syncs; Data Cloud for millions of profile records; bulk-safe write-backs. |
| **Security** | `WITH USER_MODE` on all built controllers; Lightning Web Security + minimal `@api` for the process launcher; no record data on shared channels; AI retrieval respects FLS/sharing. |
| **Execution context (sync/async/batch)** | Sync LWC controllers for interactive reads; Batch for 1M-row processing; Queueable/Batch + Platform Events for order sync. Chosen per use case, not by default. |
| **Declarative vs programmatic** | Map/launcher prefer base components + metadata; Apex used only where traversal, scale, security, or AI orchestration require it. |
| **Maintainability / extensibility** | Metadata-driven launcher (no-code changes), provider interface for AI (swap models), service-class encapsulation, single trigger-per-object recommendation. |
| **Testing** | Apex tests for every built controller (94–100% coverage on new classes); AI tested via injected mock + HTTP-callout mock; LWC testing noted as a next step where the scenario said "consider but do not implement". |

---

## 5. Note on the org deployment

All four BUILD items are deployed to `AFCAPQA1` and their Apex tests pass. The `Process_Action__mdt` *records* were seeded via the Apex Metadata API (`scripts/deployProcessActions.apex`) because the file-based custom-metadata deploy returned a generic server-side `UNKNOWN_EXCEPTION` in this org; the record source files remain in `customMetadata/` as the source of truth. Components are intentionally placed on pages via App Builder during the demo, since "admins drop the component via App Builder (with configurable properties)" is itself part of S1/S4A/S4B/S7.
