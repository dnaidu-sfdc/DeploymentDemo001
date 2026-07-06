# Bedrock Auto — Data Architecture & Management Badge
## Requirements → Solution → Defense

**Audience for the presentation:** Bedrock Auto **CTO / Chief Architect** (technical exec — architecture
rolls up to this role, and the data model needs their sign-off before the build starts).
**Scenario:** Bedrock Auto (BA) — used-car wholesaler. Auctions → **10K dealers** → **2M consumers**,
growing **20% YoY** for 5 years. Already on **Sales Cloud**; now standing up **Service Cloud** to replace a
legacy Service CRM. Data is fragmented across a Legacy CRM, an ERP (master vehicle/dealer/warranty/invoice
store), a Parts system, an ESB, an ETL tool, and an Oracle EDW.

---

## How to use this document

This is the **master solution + defense doc**. It covers **all 9 evaluated objectives** and the **6 required
deliverables**, with the *why* (trade-offs) and a **🎤 Defend-it Q&A** for the 25-minute judge grilling.
The ≤5 presentation slides are distilled from this (see `bedrock-data-SLIDES.md`). The three diagrams
(`data-model.drawio`, `system-landscape.drawio`, `role-hierarchy.drawio`) live in this folder.

**Plain-language rule:** every piece of jargon is explained in simple terms the first time it appears.
The gold standard is *"an External Object = a window into another system's table; Salesforce shows the rows
but never stores them."*

### The rubric — and where each objective is answered

| # | Evaluated objective | Weight | Where it's addressed |
|---|---|---:|---|
| 1 | **Design & Optimization** | **15%** | §5 Data Model · §8 LDV strategy |
| 2 | **Data Migration** | **15%** | §7 Migration (one-time + bi-directional sync) |
| 3 | **Data Quality** | **13%** | §9 Data Quality |
| 4 | **Data Movement** | 10% | §6 System Landscape (movement vs lookup) |
| 5 | **Master Data Management** | 10% | §10 MDM |
| 6 | **Reference Data Management** | 10% | §11 Reference Data |
| 7 | **Data Solution Architecture** | 10% | §3 Licenses/Roles · §6 Landscape · §13 Backup/DR · §14 Future |
| 8 | **Data Archiving** | 9% | §12 Archiving (tiered) |
| 9 | **Data Governance & Stewardship** | 8% | §15 Governance |

### The 6 required deliverables (≤5 slides + a working demo)

1. **Licenses per actor role + high-level Role hierarchy** → §3
2. **Data volume estimates over a 2-year horizon** → §4
3. **Data model** (entities; M-D / lookup / external relationships; ownership; OWD; LDV flags; off-platform) → §5
4. **System landscape** (systems + platforms used) → §6
5. **Data migration processes** (one-time + ongoing sync) → §7
6. **LDV solution** for querying / searching / accessing in the operational Service Cloud → §8

---

## 1. The Case (problem statement — the CTO's words back to them)

> *"We're replacing a dying Service CRM with Service Cloud, but the real problem isn't the CRM — it's that
> our customer truth is scattered across six systems. A service agent can't see a vehicle's history, its
> warranty, its invoices, and its open cases on one screen. Dealer records are full of duplicates, so parts
> ship to the wrong address and we eat the cost. We have 20M vehicles, 100M service records, and 2M
> consumers, and it's growing 20% a year. We need a data architecture that (a) makes Service Cloud fast at
> that scale, (b) gives every actor one trustworthy view, (c) migrates 7 years of case history without
> losing a byte, and (d) keeps us compliant and recoverable — with a clear path to Europe and AI later."*

**The five hard problems inside that:**

1. **Scale (LDV).** 20M vehicles + 100M service records + 2.5M cases. Naïvely loading all of it into
   Salesforce would make the org slow and expensive. *(LDV = "Large Data Volume" = so many rows that
   ordinary queries and sharing recalculations get slow unless you design for it.)*
2. **Migration + coexistence.** Move 2 years of live cases + up to 7 years of history from a file-only
   legacy system, then run **both systems in sync for 3 months** before switching the legacy off.
3. **Fragmentation & quality.** The same dealer exists five times across systems; nobody can fix a record
   and push the fix back to the ERP. Bad data has a **dollar cost** (misshipped parts) the AEs want measured.
4. **One customer / one dealer truth.** A unified customer profile (vehicle + warranty + service + case) and
   a trusted dealer master record — the classic **MDM** problem.
5. **Governance, retention, recovery, and the future.** No central governance body is sticking; 7-year
   retention with tiers; can't lose data; and Europe + AI are coming.

---

## 2. Guiding principles (the architecture "north star")

1. **Store what you operate on; look up what you only reference.** Cases, accounts, contacts, orders live
   *in* Salesforce. Invoices, payments, and 100M service records are *looked up* from the ERP — shown, not
   stored. *(This one decision solves most of the LDV problem.)*
2. **One system of record per data domain.** ERP owns vehicles/warranties/invoices; the MDM owns the
   dealer/customer golden record; Salesforce owns cases and service interactions. No domain has two masters.
3. **Right tool for each data flow.** **ESB** for real-time operational flows (place an order, look up an
   invoice); **ETL** for bulk migration and heavy transforms; **Data Cloud** for unifying and streaming.
4. **Design for the volume you'll have in 2 years, not today.** Every LDV entity gets external IDs,
   selective queries, skinny tables, and an archiving path *from day one*.
5. **Governance by federation, not committee.** Since a central governance board isn't gaining traction,
   push accountability to **domain data owners** with automated guardrails (rules, dashboards, Shield).

---

## 3. Deliverable 1 — Licenses per actor + Role hierarchy  *(Solution Architecture 10%)*

### 3.1 Actors → license mapping

| Actor | Count | Salesforce license | Why this license (plain terms) |
|---|---:|---|---|
| **Service Agents** | 500 (50 regions × 10) | **Service Cloud** (full internal user) | Full case, knowledge, omni-channel, and article-authoring access. |
| **Special Agents** | ~150 (teams of 3/region, fluid) | **Service Cloud** (same license) | Same capability as agents; the "special" part is *access control*, not a different license — handled by a **permission set** + a restricted queue, so a person can move in/out of the special team without a license change. |
| **Regional Service Managers** | 50 | **Service Cloud** | Need their region's cases + agent performance + manage dealers in-region. |
| **Service VP** | 1 | **Service Cloud** (+ **CRM Analytics**) | Cross-region case reporting and high-level operational insight → Analytics for roll-ups. |
| **Service Operations** | small team | **Service Cloud** + **CRM Analytics** + **Data Cloud** | Needs near-real-time dashboards across service records, vehicles, and interactions — streaming + analytics, not weekly EDW reports. |
| **Account Executives** | existing | **Sales Cloud** (already own) | 360° view of large business customers; add **Data Cloud** for the cross-cloud aggregate + recurring-billing view. |
| **Dealers — DSC & DSM** | 75K employees across 15K dealers | **Experience Cloud — Partner Community (login-based)** | Dealers are external *partners* who need **roles** (DSM sits above DSC), **delegated admin** (DSM adds/manages DSC users), reports, cases, invoices, and parts orders. That combination = Partner Community, not the lighter Customer license. Login-based sizing because not all 75K are active daily. |
| **Consumers** | 2M | **Experience Cloud — Customer Community (high-volume, login-based)** | 2M external users who submit cases, order parts, and read articles. **High-Volume Community users have *no role*** — which is exactly what we want at 2M (roles at that scale cause sharing-performance and data-skew pain). Sharing is done with **Sharing Sets**, not the role hierarchy. |
| **Integration / migration** | — | **Salesforce Integration** user + API-only + Data Loader/Bulk | System-to-system accounts for ESB, ETL, and CDC, least-privileged. |

**Platform add-ons (not per-user licenses, but part of the license story):**
**Data Cloud** (unified profile + streaming), **Shield** (encryption + field audit for compliance/7-yr),
**Salesforce Backup** (native backup/recovery), **CRM Analytics** (ops dashboards).

> **Trade-off called out for the CTO:** Partner Community for 75K dealer employees is the biggest license
> cost. We use **login-based** licensing and can reassess member-based once real login frequency is known.
> Consumers *must* be high-volume (login-based) — a role-based community license for 2M users is a
> non-starter on both cost and sharing performance.

### 3.2 High-level Role hierarchy

```
                         ┌─────────────────────┐
                         │      Service VP      │  (cross-region read via hierarchy)
                         └──────────┬───────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
        ┌───────────▼──────┐  ┌─────▼──────┐   ┌─────▼─────────────┐
        │ Regional Service │  │  Service   │   │  Service          │
        │ Manager (×50)    │  │  Operations│   │  Operations (RO)  │
        └───────────┬──────┘  └────────────┘   └───────────────────┘
                    │
        ┌───────────▼───────────┐
        │  Service Agents        │   (10 per region)
        │  (+ Special Agents via │
        │   permission set/queue)│
        └────────────────────────┘

  EXTERNAL (Experience Cloud):
        Dealership Service Manager (DSM)  ──▶  Dealership Service Consultant (DSC)
              (partner role per Dealer Account; DSM = delegated external admin)

        Consumers = High-Volume Community users → NO role (sharing via Sharing Sets)
```

**Design notes the judge will probe:**
- **Regional visibility** is delivered by the role hierarchy (RSM above Agents) **plus owner-based sharing
  rules** keyed on a **Region** field, so an agent sees their region's cases; the RSM rolls up their region;
  the VP rolls up all. *(OWD on Case is Private — see §5.)*
- **Special Agents / dealer complaints** must be **invisible to everyone else**. We give dealer-complaint
  cases a dedicated **record type**, route them to a **region-specific Special-Agent queue**, and apply
  **Restriction Rules** so only members of that queue can see them — even managers above can't, unless
  explicitly added. *(Restriction Rules = a filter that hides records a user would otherwise see; the clean
  modern way to carve out confidential data without breaking the whole sharing model.)*
- **Special Agents are fluid** — moving an agent in/out is a **permission-set-group + queue-membership**
  change, never a license or profile change.
- **DSM delegated admin** = **Experience Cloud partner "Delegated External User Administration,"** letting a
  DSM create/manage DSC users and see all records owned by their DSCs (partner role hierarchy under the
  Dealer Account).

---

## 4. Deliverable 2 — Data volume estimates (2-year horizon)  *(Design & Optimization 15%)*

**Assumption:** 20% YoY business growth compounds on transactional data → **×1.44 over 2 years** (1.2²).
Master/reference data grows with the business too. **Bold = LDV entity** (needs LDV design). The
right-hand column is the key architectural call: **where the data actually lives.**

| Entity | Object (type) | Today | 2-yr projected | Storage tier / decision | LDV? |
|---|---|---:|---:|---|:--:|
| **Vehicles (VINs)** | `Vehicle__c` **or** Asset | 20M | **~28.8M** | **ERP is master.** Replicate a lean copy to SF (indexed, external-ID on VIN) *or* expose via External Object — see §8. | **✅** |
| **Service Records** | **External Object** `ServiceRecord__x` | 100M | **~144M** | **Off-platform — never stored.** Salesforce Connect / Data Cloud. | **✅ (off-platform)** |
| **Cases** | Case (standard) | 500K/yr | **~2.5M** in scope (2-yr operational ~1.3M + ~1M migrated history) | In SF, **2-yr operational window**; older → Big Object (§12). | **✅** |
| Case Comments / Emails | CaseComment / EmailMessage | ~3–5× cases | **~8–12M** | In SF with parent Case; archived with Case. | ✅ |
| **Orders** | Order (standard) | 1M/yr | **~2.6M** over 2 yrs | Header in SF; fulfilled by Parts system. | ✅ |
| **Order Line Items** | OrderItem (M-D child) | 3M/yr | **~7.9M** over 2 yrs | In SF as M-D children of Order. | **✅** |
| Consumer Accounts | Account (Person Account) | 2M | **~2.9M** | In SF; **OWD Private**. | **✅** |
| Dealer Accounts | Account (Business) | 15K | ~21.6K | In SF; MDM-mastered. | — |
| Dealer Employees | Contact | 75K | ~108K | In SF (community users). | — |
| Parts Catalog | Product2 **or** External Object | 500K | ~600K+ | Master in Parts system; replicate or expose (§6). | ✅ (borderline) |
| Invoices / Payments | **External Object** `Invoice__x` | (ERP) | (ERP) | **Off-platform — real-time lookup**, never stored. | ✅ (off-platform) |
| Warranties | `Warranty__c` / Asset-related | (ERP) | (ERP) | ERP master; surfaced via lookup/replication. | — |
| Attachments/Files | ContentVersion | 100K | ~144K | In SF (Files); large binaries can tier to external. | — |
| Knowledge Articles | Knowledge | 50K | ~72K | In SF; multi-channel. | — |

**Storage back-of-envelope (why we don't store everything):** at ~2 KB/record, **144M service records ≈
288 GB** — far beyond sensible Salesforce data storage and pointless to migrate. This single line is the
justification for the External-Object / Data-Cloud strategy in §8. *(Salesforce bills data storage per record;
LDV + cost together kill the "load it all in" option.)*

> **Note on a source discrepancy:** the Parts narrative says "over 500K orders/year," the estimate table
> says "1M Orders/year." **We plan for the higher figure (1M/yr)** so the design is safe at the upper bound;
> flagged as an assumption (§16).

---

## 5. Deliverable 3 — Data Model  *(Data Model + Design & Optimization 15%)*

> Full diagram: **`data-model.drawio`**. Legend: **standard object** (blue) · **custom object** (green) ·
> **external object** (orange, dashed) · **Master-Detail** = solid filled arrow · **Lookup** = open arrow ·
> **External/Indirect lookup** = dashed arrow · 🔒 = OWD Private · **[LDV]** = large-data-volume entity.

### 5.1 Entities, ownership, OWD, LDV, on/off-platform

| Entity | Type | Owner | OWD | LDV | On/Off platform |
|---|---|---|---|:--:|---|
| **Account** (Person = Consumer; Business = Dealer) | Standard | Service Agent / system; Dealer by integration | **Private** 🔒 | ✅ | On |
| **Contact** (DSC/DSM) | Standard | Parent Account | **Controlled by Parent** | — | On |
| **Case** | Standard | Agent / Region Queue / Special queue | **Private** 🔒 | ✅ | On |
| CaseComment / EmailMessage | Standard (child) | Parent | Controlled by Parent | ✅ | On |
| **Vehicle** `Vehicle__c` (or **Asset**) | Custom/Standard | Integration user | **Controlled by Parent** (Account) | ✅ | On (replica); ERP = master |
| **Warranty** `Warranty__c` | Custom | Integration user | Controlled by Parent (Vehicle) | — | On (from ERP) |
| **Order** | Standard | Dealer user / integration | **Private** 🔒 | ✅ | On |
| **OrderItem** (line item) | Standard (**M-D** child of Order) | — (inherits) | Controlled by Parent | ✅ | On |
| **Part / Product** `Product2` | Standard | system | Public Read Only | ✅ | On (replica) or Off (Parts) |
| **Service Record** `ServiceRecord__x` | **External** | — | (external access via data source) | ✅ | **Off (ERP/virtualization)** |
| **Invoice** `Invoice__x` | **External** | — | (external) | ✅ | **Off (ERP, real-time)** |
| **Payment** `Payment__x` | **External** | — | (external) | ✅ | **Off (ERP, real-time)** |
| **Knowledge Article** | Standard | system | Public (channels) | — | On |

### 5.2 Relationships (and *why* each relationship type)

- **Order → OrderItem = Master-Detail.** Line items have no life without their order; roll-up totals
  (order value) are needed. *(Master-Detail = child is owned by and deleted with the parent, and OWD/sharing
  is inherited from the parent — perfect for line items.)*
- **Account → Case = Lookup.** A case references a customer but must survive independently and carry its own
  sharing/ownership. *(Lookup = a loose reference; child keeps its own owner and sharing.)*
- **Account → Vehicle (Asset) = Lookup** (Person Account owns the vehicle; Dealer Account services it).
- **Vehicle → Warranty = Lookup** (or M-D if warranties are strictly vehicle-scoped).
- **Case → Vehicle = Lookup** (a case is about a specific vehicle) and **Case → Invoice (external) = External
  Lookup** for on-screen invoice display.
- **Vehicle → Service Record (external) = Indirect Lookup on VIN.** The 100M service records live in the ERP;
  the External Object relates back to the on-platform Vehicle using **VIN as the External ID**.
  *(Indirect Lookup = link an external row to a Salesforce record by matching an external-ID field — here VIN
  — so agents see a vehicle's full service history without any of it being stored in Salesforce.)*
- **Account → Invoice/Payment (external) = External Lookup** — real-time invoice/payment display on the
  service console (solves the 3–5 min "log into ERP" problem) with **zero storage**.

### 5.3 The sharing model (this is where Design & Optimization is won or lost)

- **Case & Account OWD = Private.** Regional agents see only their region; confidential dealer-complaint
  cases are invisible to others.
- **Regional access** = role hierarchy (VP ▸ RSM ▸ Agents) **+ owner-based sharing rules on a Region field**.
- **Dealer-complaint confidentiality** = record type + Special-Agent queue + **Restriction Rules** (§3.2).
- **2M consumers** = high-volume community users (no roles) → **Sharing Sets** grant each consumer access to
  *their own* vehicles/cases/orders by matching the user's Contact/Account. **This avoids account data skew**
  — we never make one owner own millions of records. *(Data skew = too many child records under one parent
  or one owner, which makes sharing recalculation crawl; high-volume users + sharing sets sidestep it.)*
- **Dealer partner access** = partner role hierarchy under each Dealer Account (DSM ▸ DSC) + sharing sets for
  dealer-scoped records (their cases, invoices, orders).

---

## 6. Deliverable 4 — System Landscape + Data Movement vs Lookup  *(Data Movement 10% · Solution Arch 10%)*

> Full diagram: **`system-landscape.drawio`**.

### 6.1 The platforms in the solution

| System | Role in the target architecture |
|---|---|
| **Salesforce Sales Cloud** | Existing — AE/opportunity, large-customer 360 (feeds from Data Cloud). |
| **Salesforce Service Cloud** | New system of engagement for cases, omni-channel, knowledge, console. |
| **Salesforce Experience Cloud** | Dealer partner portal + consumer self-service portal. |
| **Salesforce Data Cloud** | Unified customer profile, ingest 100M service records, near-real-time ops streaming, AI/segmentation, cross-regional 360. |
| **CRM Analytics** | Ops near-real-time dashboards; DQ scorecards linked to financials; VP roll-ups. |
| **Salesforce Shield + Backup** | Encryption, field-audit (7-yr compliance), native backup/point-in-time recovery. |
| **ERP** | **Master** of vehicles, warranties, dealers (pre-MDM), invoices, payments. Web services available. |
| **Parts System (Java)** | Parts catalog + order processing; exposes order-placement/status web services. |
| **ESB** | **Real-time operational integration bus** — mediates order placement, invoice/payment lookups, case sync. |
| **Enterprise ETL tool** | **Bulk migration + heavy transforms + orchestration** (legacy case load, EDW feeds, batch enrichment). Recommended over hand-built Java ETL. |
| **Oracle EDW** | Analytical archive / long-term historical trending; a target archival tier (§12). |
| **MDM platform** | Dealer + customer golden record, matching, survivorship (build-vs-buy in §10). |
| **3rd-party data provider** | External enrichment (address/identity/firmographic) ingested via ETL/Data Cloud. |

### 6.2 Data **Movement** vs Data **Lookup** — the core distinction the template demands

**Data movement = a copy is physically written into Salesforce** (you own it, store it, report on it,
back it up). **Data lookup = Salesforce displays another system's data live and stores nothing** (you
reference it). Getting this split right is *the* LDV and cost lever.

| Flow | Movement or Lookup? | Mechanism | Why |
|---|---|---|---|
| Legacy case history → SF | **Movement** (one-time) | ETL → Bulk API 2.0 | Cases must be operated on, reported, retained in SF. |
| New cases / comments | **Movement** (native) | Created in SF | System of record for service. |
| Order placement (SF → Parts → ERP invoice) | **Movement + trigger** | ESB, real-time | Order header stored in SF; placement/invoicing pushed downstream. |
| **Invoice / Payment display** | **Lookup** | **External Objects (OData via ESB)** | Real-time, no storage — kills the 3–5 min ERP hunt; ERP stays the master. |
| **Service records (100M)** | **Lookup** (+ Data Cloud) | **Salesforce Connect / Data Cloud** | Volume + cost make storage absurd; agents still see full history. |
| Vehicle master | **Movement** (lean replica) *or* Lookup | ESB sync **or** External Object | Replica if we need relationships/reporting; external if pure reference (§8 decision). |
| Service records → analytics | **Movement** (to Data Cloud/EDW) | ETL / streaming | Trending + AI need the data resident in the analytics tier. |
| Dealer/customer golden record | **Movement** (bi-directional) | MDM ↔ ESB | Golden record synced to SF **and corrections pushed back to ERP**. |

> **Judge bait, answered:** *"Why not just replicate the ERP into Salesforce?"* Because 144M service records
> ≈ 288 GB of storage cost, LDV query pain, and a second copy that drifts from the master. **Look up what you
> only reference; move only what you operate on.**

---

## 7. Deliverable 5 — Data Migration Processes  *(Data Migration 15% · Data Movement 10%)*

### 7.1 One-time migration (legacy Service CRM → Service Cloud)

**Constraint:** legacy CRM supports **file-based integration only**, and we must migrate **2 years
operational + up to 7 years accessible** case data **with full integrity — including case ownership and
related entities.**

**Tooling:** **enterprise ETL** (not hand-built Java) — it handles extract, transform, cleanse, and
**load orchestration** in the right order, with restartability and audit. Load via **Bulk API 2.0** (built
for millions of records).

**Sequence (parents before children, so relationships resolve):**
1. **Reference & master data** first — regions, warranty types, **deduped dealers** (post-MDM), vehicles.
2. **Accounts → Contacts → Assets/Vehicles.**
3. **Cases → Case Comments / Emails → Attachments.**
4. **Ownership & audit fields** preserved.

**Integrity techniques (the details judges want):**
- **Legacy IDs kept as External IDs** on every object → relationships re-link by external key, and re-runs
  are **idempotent** (no duplicates). *(External ID = a field holding the source system's key so you can
  match/"upsert" instead of blindly inserting.)*
- **`setAuditFields` permission** to preserve original CreatedDate/CreatedBy and **owner** — history stays
  truthful.
- **Cleanse in-flight** — dedupe/standardize during transform (§9), not after.
- **LDV load hygiene:** load with **sharing recalculation deferred**, indexes/skinny tables prepared,
  triggers/automation toggled off during bulk load, then re-enabled. Load in **key order** to avoid
  parent-lock contention.
- **Reconciliation:** row counts + checksums per object; a control report signed off before cutover.

### 7.2 Ongoing bi-directional sync (the 3-month coexistence window)

**Constraint:** for **3 months**, changes to current cases in **both** systems must stay in sync; then the
legacy CRM is decommissioned.

**Pattern — ESB as the sync mediator with clear conflict rules:**
- **SF → Legacy:** **Change Data Capture (CDC)** or Platform Events publish case changes → ESB → file/API to
  legacy. *(CDC = Salesforce emits an event whenever a record changes, so downstream systems stay current
  without polling.)*
- **Legacy → SF:** legacy drops change files on a schedule → ESB → **upsert by External ID** (Bulk/Composite).
- **Conflict resolution:** define the **system of record per phase** — during coexistence, **last-modified-
  wins with field-level survivorship**, and after cutover **Salesforce is the SOR**. Every synced record
  carries the external ID + a `LastSyncedTimestamp` so loops are prevented (**idempotency**).
- **Scope discipline:** only *open/current* cases sync (not the full 7-yr history — that's a one-time move),
  keeping the bridge light.
- **Decommission at month 3:** freeze legacy writes, final delta sync, reconcile, retire.

### 7.3 Steady-state ongoing integrations (post-cutover)

- **Orders:** SF → Parts (place) → ERP (invoice) — real-time via **ESB**.
- **Invoice/Payment:** ERP → SF **External Object lookup** (no storage).
- **Service records:** ERP → **Data Cloud** (+ External Object for live console view).
- **Dealer/customer golden record:** MDM ↔ SF/ERP, **corrections pushed back to ERP**.
- **3rd-party enrichment:** provider → ETL/Data Cloud → SF (match + append).

---

## 8. Deliverable 6 — LDV strategy (querying, searching, accessing in Service Cloud)  *(Design & Opt 15%)*

**The problem:** keep the Service Cloud console fast while 20M+ vehicles, 100M+ service records, and 2.5M+
cases sit behind it.

### 8.1 The tiered decision — what lives where

| Data | Strategy | Mechanism |
|---|---|---|
| **Service records (100M+)** | **Don't store** | **Salesforce Connect / External Objects** (indirect lookup on VIN) + **Data Cloud** for analytics/AI. Agents see full history live. |
| **Invoices / payments** | **Don't store** | **External Objects (OData via ESB)** — real-time. |
| **Vehicles (20M)** | **Lean on-platform replica** | Custom object, **External ID on VIN**, **custom indexes**, **skinny table** for console fields; ERP remains master. *(Chosen over pure-external because agents search by VIN constantly and we need relationships to Case/Account.)* |
| **Cases (operational)** | **2-year window on-platform** | Standard Case, indexed, skinny table; older cases → Big Object (§12). |
| **Cases (2–7 yr)** | **Near-line** | **Big Object** `CaseArchive__b` + async SOQL; surfaced read-only in console. |
| **Parts catalog (500K)** | Replica **or** external | Product2 replica if used in orders/reporting; External Object if pure browse. |

### 8.2 Performance techniques (name them explicitly — judges check)

- **Selective queries + custom indexes** on high-cardinality fields (VIN, CaseNumber, Region, external IDs).
  *(Selective query = a filter that hits an index instead of scanning millions of rows.)*
- **Skinny tables** for the console's hot fields (avoid joins across base+custom field tables at read time).
- **Data skew avoidance:** high-volume community users (no roles) + **sharing sets**; never one owner over
  millions of records; distribute ownership; **ownership skew** and **lookup skew** actively designed out.
- **Defer sharing recalculation** during bulk loads; use **Parallel Sharing Recalculation**.
- **Search:** **SOSL** and External Object search for cross-system finds; **Data Cloud** for unified search
  across resident + external data.
- **Archiving + PK chunking** for large extracts (backup/EDW) so reads don't hit the transactional path
  (§12–13). *(PK chunking = split a huge table into ID-range batches so each query stays selective.)*
- **Async & Big Object patterns** (Async SOQL, Bulk API 2.0) for anything touching millions of rows.

---

## 9. Data Quality  *(Data Quality 13%)*

**The pain:** duplicate/inconsistent dealers → misshipped parts → real dollars lost; agents can't correct
data or push fixes back to ERP; AEs want **DQ metrics tied to financial impact**.

**Solution — quality across three levers (process · project · technology):**

- **Prevent at entry (technology):**
  - **Duplicate & Matching Rules** on Account/Contact (fuzzy match on name/address/VIN) — block or warn.
  - **Validation Rules + required standards** (state codes, phone/address formats).
  - **Address verification / 3rd-party enrichment** at point of entry (the evaluated data provider).
- **Cleanse during migration (project):** dedupe + standardize **in the ETL transform** before load, so we
  don't import the mess (§7.1).
- **Sustain (process):** **stewardship workflow** — agents/RSMs flag or fix a dealer record in Salesforce;
  the corrected golden record syncs to the **MDM** and is **pushed back to the ERP** (closing the loop the
  scenario explicitly calls out).
- **Match & reconcile across systems (technology):** the **MDM** performs cross-system matching/survivorship
  (§10); the 3rd-party provider raises accuracy/completeness.
- **Measure & tie to money (the AE ask):** a **CRM Analytics DQ scorecard** tracking **completeness,
  duplicate rate, standardization %, address-accuracy %,** and the **cost of post-process cleanup**
  (e.g., $ per misshipment × misship rate). Metrics linked to financial measures so DQ has a P&L story.

> **Sample DQ dashboard (for the template's "Data Quality" slide):** duplicate-dealer rate ▾, address-
> accuracy ▴, % records enriched, misship-cost trend $, records-corrected-and-synced-to-ERP count,
> completeness by object. (Built in `role-hierarchy.drawio`'s companion — see slides.)

---

## 10. Master Data Management (MDM)  *(MDM 10%)*

**Two master-data problems:** (1) a **trusted dealer record** (dealers exist in ERP, Parts, legacy — full of
dupes), and (2) a **unified customer profile / single identity** across website, mobile, service calls, and
vehicle data.

**Recommendation — a hybrid, and here's the build-vs-buy call the scenario asks for:**

| Option | Verdict | Why |
|---|---|---|
| **Build (custom in Salesforce/Java)** | ❌ for enterprise MDM | Matching/survivorship/stewardship at 20M-vehicle / 2M-customer / multi-source scale is a solved problem — building it is cost and risk we shouldn't own. |
| **Buy — dedicated MDM platform** (e.g., Informatica MDM / Reltio) | ✅ for the **Dealer golden record** | Cross-system matching, survivorship rules, stewardship console, bidirectional sync to ERP + SF. This is the authoritative dealer master. |
| **Cloud — Salesforce Data Cloud** | ✅ for the **unified *customer* profile** | **Identity resolution** across web/mobile/service/vehicle into one profile; real-time, native to SF, feeds AI/segmentation and the AE 360. |

**So:** **Data Cloud for the customer 360 / identity resolution**, **a dedicated MDM tool for the dealer
golden record with write-back to ERP.** Both feed Salesforce; ERP stays the transactional master for
vehicles/warranties/invoices. *(MDM = the discipline of keeping one trusted "golden" version of a core
business entity — here, dealers and customers — and syncing it everywhere.)*

- **Identity resolution** (Data Cloud): match rules on email/phone/address/VIN ownership → one **Unified
  Individual** → powers personalized offers (extend warranty / maintenance program during a call).
- **Governance hook:** golden-record ownership + survivorship rules are where stewardship (§15) bites.

---

## 11. Reference Data Management  *(Reference Data 10%)*

**Reference data = the shared code lists everything else points at** — region codes (50 regions), US state
codes, warranty types, case reasons/types, part categories, year/make/model. If these drift, every report
and integration breaks.

**Solution — one governed source per reference set, by volatility:**

- **Custom Metadata Types** for stable, deploy-managed reference data (region↔state mapping, warranty types,
  case-type taxonomy). *(CMDT = configuration-as-data that moves through orgs in deployments and is cached
  for fast, query-friendly reads — ideal for governed lists.)*
- **Custom Settings / picklists (Global Value Sets)** for simple shared lists reused across objects
  (standardized picklists prevent free-text drift — a DQ win too).
- **Year/Make/Model & part categories** mastered where they naturally live (ERP/Parts) and **distributed**
  to Salesforce via ESB so there's **one source**, not per-org copies.
- **Governance:** reference data changes go through the **domain owner** (§15) + deployment pipeline — no ad-
  hoc picklist edits in production. In the **EU/multi-org future** (§14), reference data is published centrally
  and syndicated so regions stay consistent.

---

## 12. Data Archiving  *(Data Archiving 9%)*

**Requirement:** **5 years on-platform**; **5–7 years available on demand** (not necessarily in the
operational org); closed cases are eating storage now. → **tiered retention.**

| Tier | Age | Where | Access |
|---|---|---|---|
| **Operational (hot)** | 0–2 yrs (cases); 0–5 yrs (customer data) | **Service Cloud** (standard objects) | Full read/write in console. |
| **Near-line (warm)** | 2–5 yrs | **Big Objects** (`CaseArchive__b`, `ServiceRecordArchive__b`) | Read-only, surfaced in console via Async SOQL / Lightning component. |
| **Archival (cold)** | 5–7 yrs | **Oracle EDW / off-platform store** | On-demand retrieval for compliance/reporting; not in the operational org. |

- **Big Objects** hold billions of rows at low cost with no impact on operational limits — the right
  Salesforce-native near-line tier. *(Big Object = a Salesforce store built for massive, append-mostly data,
  queried asynchronously — great for archives and history.)*
- **Archiving job:** scheduled ETL/Batch moves aged closed cases (+comments/attachments) from Case → Big
  Object → (later) EDW, then deletes from the hot object to reclaim storage. **PK chunking** keeps it off the
  transactional path.
- **Seamless access:** a console component queries the Big Object so a 4-year-old case still opens read-only
  for the agent — meeting "seamlessly accessible for viewing" without keeping it hot.

---

## 13. Backup & Recovery / Disaster Recovery  *(Solution Architecture 10%)*

**Requirement:** *cannot afford to lose any data;* need **point-in-time recovery**, **DR**, and extraction
**without impacting operations.**

- **Native Salesforce Backup** (or a proven ISV such as Own/OwnBackup/Gearset) for **automated daily
  backups + point-in-time restore + field-level recovery**. *(Salesforce's shared-responsibility model:
  the platform is resilient, but **you** own backing up your data against your own bad loads/deletes.)*
- **Non-disruptive extraction:** **Bulk API 2.0 with PK chunking, off-peak**, against a **replica/EDW feed**
  where possible — never heavy exports on the live transactional path.
- **DR:** documented **RPO/RTO**, cross-region resilience on **Hyperforce**, and a **tested restore runbook**
  (a backup you've never restored isn't a backup).
- **Retention alignment:** backups honor the 7-year compliance window (§12) and **Shield field-audit** gives
  the tamper-evident history trail regulators expect.

---

## 14. Future-proofing — European expansion, Data Cloud, AI  *(Solution Architecture 10%)*

**BA (in confidence) eyes Europe — multiple CRM environments, cross-regional book-of-business view, AI
recommendations.** The CTO needs to know today's design doesn't box them in.

- **Multi-org vs single-org:** recommend **evaluating a multi-org strategy** for EU (data residency, GDPR,
  localization) with **Data Cloud as the cross-regional unification layer** — one 360° book of business
  across orgs *without* forcing one mega-org. **Hyperforce** gives in-region data residency.
- **AI recommendations:** the unified profile in Data Cloud feeds **Einstein / Agentforce** for
  next-best-action (extend warranty, maintenance program) and agent assist — the "AI-driven
  recommendations" ask.
- **Segmentation & personalization** run on the Data Cloud unified profile (calc insights) — scalable to EU.
- **Design choices that keep the door open:** ISO region/state reference data (§11), external IDs everywhere
  (§7), and "look-up-don't-store" (§6) mean adding an EU org is a *federation* exercise, not a re-platform.

---

## 15. Data Governance & Stewardship  *(Governance & Stewardship 8%)*

**Reality:** a **central governance board isn't gaining traction**, and today **system owners are the
stewards** for their domains. Don't fight that — formalize it.

**Recommend a *federated (domain-based) governance* operating model** with automated guardrails:

- **Domain data owners** — Dealer (MDM/Ops), Customer (Service + Data Cloud), Vehicle/Warranty/Invoice (ERP),
  Case (Service) — each accountable for their domain's rules, quality, and reference data. *(Federated
  governance = accountability lives with each domain's owner, coordinated by a light standard, instead of
  one central committee that stalls.)*
- **A lightweight council** (not a heavyweight board): the domain owners meet on a cadence to ratify
  cross-domain standards — this is the "alternative strategy" that gets traction where a central body didn't.
- **Automated guardrails do the enforcing** (so governance isn't meeting-dependent): duplicate/matching +
  validation rules (§9), MDM survivorship (§10), reference data via CMDT + deployment pipeline (§11),
  **Shield** (encryption + field-audit + event monitoring) for control and compliance evidence.
- **Stewardship workflow + DQ dashboards** (§9) make quality visible and assign remediation — with the
  **fix-and-sync-back-to-ERP** loop as the flagship steward action.
- **Metrics & accountability:** the DQ scorecard (tied to financial impact) is reviewed by domain owners;
  governance is measured, not just declared.

---

## 16. Assumptions (stated, per the instructions)

1. **Orders volume:** planned at the higher **1M/yr** (estimate table) vs. "500K/yr" (narrative) — safer at
   the upper bound.
2. **Person Accounts** used for the 2M consumers (individuals who own vehicles), Business Accounts for the
   15K dealers.
3. **2.5M "Cases"** interpreted as total cases in scope; operational window kept at the mandated **2 years**,
   older tiers archived (§12).
4. **Vehicle** kept as a **lean on-platform replica** (not pure external) because agents search by VIN every
   call and we need relationships to Case/Account; ERP remains master.
5. **Enterprise ETL tool is adopted** (the scenario is "re-evaluating" it) — justified by migration scale,
   transforms, and governance needs over hand-built Java.
6. **Editions:** Enterprise/Unlimited with API, Big Objects, Shield, Backup, Data Cloud add-ons.
7. **Special Agent teams** (~3/region) counted at ~150; adjusted by permission sets, not licenses.

---

## 17. 🎤 Defend-it — Q&A the judge will fire (25 min)

**Q: Why not just replicate everything from the ERP into Salesforce for one clean model?**
A: 144M service records ≈ ~288 GB of data-storage cost, LDV query degradation, and a second copy that drifts
from the master. We **move what we operate on and look up what we only reference** — External Objects/Data
Cloud give agents the full picture with zero storage and no second source of truth.

**Q: Master-Detail or Lookup for Order → OrderItem, and why?**
A: **Master-Detail.** Line items don't exist without the order, we want cascade delete and roll-up totals,
and inheriting the order's sharing is correct. Account → Case stays a **Lookup** because a case needs its
own owner and sharing lifecycle.

**Q: How do agents see a vehicle's 100M-row service history without killing performance?**
A: Service records are an **External Object** related to the on-platform Vehicle by **Indirect Lookup on
VIN**. The console shows them live from the ERP/virtualization layer; nothing is stored or indexed in
Salesforce. Heavy analytics go through **Data Cloud**, not the transactional org.

**Q: 2M consumers — how do you share their data without melting sharing performance?**
A: **High-Volume Community licenses (no roles) + Sharing Sets.** Each consumer sees only their own records by
Contact/Account match. No role hierarchy at 2M users, so **no ownership/data skew** and no giant sharing
recalcs.

**Q: How do the confidential dealer-complaint cases stay invisible — even to managers?**
A: Dedicated **record type** + **Special-Agent queue** + **Restriction Rules** that filter those cases out
for everyone not in the queue, on top of Case OWD = Private. Managers above don't inherit them.

**Q: Walk me through the 3-month bi-directional sync without infinite loops or duplicates.**
A: **ESB mediates.** SF changes via **CDC**; legacy changes via scheduled files; both **upsert by External
ID** with a `LastSyncedTimestamp` for **idempotency**; **last-modified-wins + field-level survivorship**
during coexistence; **Salesforce becomes SOR at cutover**; only open cases sync (history was a one-time
move). Final delta + reconcile, then decommission.

**Q: Build vs. buy for MDM?**
A: **Buy** a dedicated MDM for the **dealer golden record** (matching/survivorship/write-back to ERP at
scale is a solved product) and use **Data Cloud** (cloud) for **customer identity resolution / 360**.
**Don't build** enterprise MDM — it's cost and risk we shouldn't own. ERP stays the transactional master.

**Q: A central governance board isn't working. What do you actually recommend?**
A: **Federated, domain-based governance** — accountable domain owners + a light ratifying council +
**automated guardrails** (dup/validation rules, MDM survivorship, CMDT reference data, Shield) so
enforcement isn't meeting-dependent. It matches how BA already works (system owners as stewards) but
formalizes and measures it.

**Q: Prove the archiving actually meets "7 years, seamlessly viewable."**
A: **Tiered:** 0–2 yr hot (Case), 2–5 yr near-line (**Big Object**, read-only in console via Async SOQL),
5–7 yr archival (**EDW/off-platform**, on demand). A console component renders Big Object records so an old
case still *opens*, satisfying "seamlessly accessible for viewing" without keeping it in the operational tier.

**Q: How do you tie data quality to money for the AEs?**
A: A **CRM Analytics DQ scorecard**: duplicate-dealer rate, address-accuracy, standardization %,
enrichment coverage, and **cost of post-process cleanup** ($/misshipment × misship rate) — DQ metrics mapped
to financial measures, reviewed by domain owners.

**Q: Backup — isn't Salesforce already resilient?**
A: The platform is resilient, but under the **shared-responsibility model** *we* own recovery from our own
bad loads/deletes. **Native Backup (or ISV)** for daily backup + **point-in-time** + field-level restore;
extraction via **Bulk API + PK chunking off-peak / against a replica** so operations aren't impacted;
tested RPO/RTO runbook.

**Q: Does this box us out of Europe?**
A: No. **Data Cloud** unifies cross-regional 360 over a likely **multi-org** EU footprint (residency/GDPR on
**Hyperforce**); external IDs + look-up-don't-store + ISO reference data make adding an EU org a federation
step, not a re-platform. Same unified profile feeds **Einstein/Agentforce** AI recommendations.

---

*Companion files in this folder:* `data-model.drawio` · `system-landscape.drawio` · `role-hierarchy.drawio` ·
`bedrock-data-SLIDES.md` (the ≤5-slide distillation with speaker notes).
