# Bedrock Auto — Data Architecture Badge
## Presentation content (≤5 solution slides) + speaker notes

**Audience:** Bedrock Auto **CTO / Chief Architect**
**Format:** 20-min present · 25-min Q&A · 15-min feedback. Template allows **max 5 content slides** + a
functioning demo. This maps content onto the template's flow: *Title → Agenda → Who Am I → Case →
[5 content slides] → Executive Summary → Thank you.* Full rationale + Q&A: `bedrock-data-REQ-to-SOLUTION.md`.

> **How to build the deck:** paste each block into the matching template slide. The three diagrams
> (`system-landscape.drawio`, `data-model.drawio`, `role-hierarchy.drawio`) export to PNG and drop onto
> slides 1, 2, and 4 respectively. Keep bullets terse on-slide; the detail lives in the speaker notes so you
> can *say* it, not read it.

---

### Title slide
- **Domain:** Data Architecture & Management
- **Bedrock Auto — Scaling Service Cloud on a Single Source of Truth**
- *[Your name] · [Title] · [email]*

### Agenda (template slide)
- Introduction (elevator pitch)
- Business case overview
- System landscape
- Large Data Volume calculation
- Data model · Data quality · Role hierarchy
- Executive summary

### Who Am I? (template slide)
- *[Your bio — Salesforce data-architecture experience, migrations at LDV scale, MDM/governance work.
  One or two proof points relevant to a CTO audience.]*

### Case slide (template's `<Case>` slide)
**"The CRM isn't the problem — the scattered truth is."**
- Replacing a dying Service CRM with **Service Cloud**, but customer truth lives across **6 systems**.
- Agents can't see vehicle + warranty + invoice + case on one screen; **dealer duplicates** misship parts
  (a measurable $ cost).
- Scale: **20M vehicles · 100M service records · 2.5M cases · 2M consumers**, **+20% YoY**.
- **Mandate:** fast Service Cloud at scale · unified view per actor · migrate 7 yrs of cases losslessly ·
  compliant, recoverable · ready for **EU + AI**.

> **Speaker note:** State the mandate in the CTO's language and preview the 4 hard problems: LDV,
> migration+coexistence, quality/MDM, governance+retention+recovery. Everything else answers these.

---

## SLIDE 1 — Application / System Landscape *(Data Movement 10% · Solution Arch 10%)*
> **Visual:** `system-landscape.drawio` (export PNG).

**On-slide bullets**
- Three zones: **Source/legacy** (Legacy CRM, ERP, Parts, EDW, 3rd-party, MDM) → **Integration & data
  layer** (ESB, ETL, Data Cloud) → **Salesforce** (Service/Sales/Experience, External Objects, CRM
  Analytics, Shield, Backup, Big Objects).
- **Right tool per flow:** **ESB** = real-time ops (orders, invoice lookup, case sync); **ETL** = bulk
  migration + heavy transforms; **Data Cloud** = unify + stream + AI.
- **The core distinction:** **Data Movement** (solid — a copy is *written into* Salesforce; stored,
  reportable, backed up) vs **Data Lookup** (dashed — Salesforce shows another system's data *live* and
  stores nothing).

**Speaker notes**
- ERP stays the **master** of vehicles/warranties/invoices; Salesforce is the **system of engagement**.
- Leverage the CIO's under-used ESB for real-time; add enterprise ETL for migration scale (justified next).
- Invoices/payments and 100M service records are **looked up, not stored** — this is what keeps the org
  fast and cheap. Segue to the LDV math.

---

## SLIDE 2 — LDV Calculation + Data Model *(Design & Optimization 15% · Data Model)*
> **Visual:** `data-model.drawio` (export PNG). Optionally split volume table + model across a 2-column layout.

**On-slide: 2-year volume (× 1.44 from 20% YoY)**

| Entity | 2-yr | Where it lives |
|---|---:|---|
| Vehicles | ~28.8M | lean SF replica (VIN ext-ID) · ERP master · **[LDV]** |
| Service Records | ~144M | **External Object — off-platform** · **[LDV]** |
| Cases | ~2.5M | SF (2-yr window) → Big Object · **[LDV]** |
| Order line items | ~7.9M | M-D child of Order · **[LDV]** |
| Consumers | ~2.9M | Person Accounts · Private |

**On-slide: model rules**
- **Master-Detail:** Order → OrderItem (roll-ups, cascade, inherited sharing).
- **Lookup:** Account→Case, Account→Vehicle, Vehicle→Warranty.
- **External / Indirect Lookup:** Vehicle→ServiceRecord (**by VIN**), Case→Invoice — *look up, don't store.*
- **OWD:** Case & Account **Private**; sharing by role hierarchy + region rules; consumers via Sharing Sets.

**Speaker notes**
- **The headline number:** 144M service records ≈ **~288 GB** — pointless and slow to store → External
  Objects/Data Cloud. This one decision solves most of the LDV problem.
- LDV techniques: **custom indexes + selective queries + skinny tables**, **defer sharing recalc** on load,
  **data-skew avoidance** (high-volume users, distributed ownership), async/Bulk for millions of rows.

---

## SLIDE 3 — Data Migration + Coexistence *(Data Migration 15% · Data Movement 10%)*
> **Visual:** a simple 2-phase timeline (one-time load → 3-month bi-directional sync → decommission).

**On-slide bullets**
- **One-time (legacy → Service Cloud):** ETL extract from file-based legacy → cleanse/dedupe in-flight →
  **Bulk API 2.0** load in **parent-before-child order**; **legacy IDs as External IDs**; **preserve
  CreatedDate/CreatedBy/Owner** (`setAuditFields`); **reconcile** row counts + checksums.
- **3-month coexistence (bi-directional):** **ESB** mediates — SF changes via **CDC/Platform Events**,
  legacy via scheduled files; **upsert by External ID** + `LastSyncedTimestamp` for **idempotency**;
  **last-modified-wins + field-level survivorship**; only *open* cases sync.
- **Cutover:** freeze legacy → final delta → reconcile → **Salesforce becomes SOR** → decommission.

**Speaker notes**
- Stress **integrity**: external IDs make loads restartable and re-runnable without duplicates; audit fields
  keep history truthful (ownership matters for compliance).
- Coexistence scope discipline: history is a one-time move; only live cases ride the sync bridge → keeps it
  light and loop-free.

---

## SLIDE 4 — Data Quality, MDM, Reference Data, Governance & Archiving
*(DQ 13% · MDM 10% · Reference Data 10% · Governance 8% · Archiving 9%)*
> **Visual:** DQ dashboard mock (duplicate-rate ▾, address-accuracy ▴, misship-cost $ trend) + a small
> tier ladder. (Role hierarchy — `role-hierarchy.drawio` — can go here or on its own slide if you split.)

**On-slide bullets**
- **Data Quality:** prevent (Duplicate/Matching + Validation rules, address verification) · cleanse in
  migration · **sustain** via steward workflow that **fixes in SF and syncs back to ERP** · **DQ scorecard
  tied to $** (cost of misshipment).
- **MDM (build vs buy):** **buy** a dedicated MDM for the **dealer golden record** (matching/survivorship/
  write-back); **Data Cloud** for **customer identity resolution / 360**. Don't build enterprise MDM.
- **Reference Data:** **Custom Metadata Types** + global value sets; one governed source per code list
  (regions, warranty types), distributed via ESB.
- **Governance:** central board stalled → **federated, domain-owner governance** + a light ratifying council
  + **automated guardrails** (rules, MDM survivorship, CMDT, **Shield**).
- **Archiving (tiered):** 0–2 yr **hot** (Case) · 2–5 yr **near-line** (**Big Objects**, read-only in
  console) · 5–7 yr **archival** (EDW, on demand). Meets "7 yrs, seamlessly viewable."

**Speaker notes**
- Tie DQ to money for the AEs — that's the line that lands with a CTO who reports to the business.
- Federated governance matches how BA already works (system owners as stewards) but formalizes + measures it
  — the "alternative strategy" the scenario asks for.

---

## SLIDE 5 — Role Hierarchy, Licenses, Backup/DR & the Future
*(Solution Architecture 10%)*
> **Visual:** `role-hierarchy.drawio` (export PNG).

**On-slide bullets**
- **Licenses:** Service Cloud (agents/managers/VP) · Sales Cloud (AEs) · **Partner Community** (75K dealers,
  login-based, DSM delegated admin) · **Customer Community High-Volume** (2M consumers, **no role**) ·
  Data Cloud · CRM Analytics · Shield · Backup.
- **Role hierarchy:** VP ▸ RSM (×50) ▸ Agents; Special Agents via **permission set + Restriction Rules**
  (dealer complaints invisible); external DSM ▸ DSC; consumers share via **Sharing Sets**.
- **Backup/DR:** native **Backup** (daily + point-in-time + field-level) · **Bulk API + PK chunking
  off-peak** so ops aren't impacted · tested RPO/RTO on Hyperforce.
- **Future:** **Data Cloud** unifies a likely **multi-org EU** footprint (GDPR/residency) + **Einstein/
  Agentforce** AI recommendations — today's design (external IDs, look-up-don't-store, ISO reference data)
  makes EU a *federation*, not a re-platform.

**Speaker notes**
- Call out the biggest cost lever (75K partner logins) and the deliberate **no-role** choice for 2M
  consumers (performance + skew).
- End by connecting back to the mandate: fast at scale, one truth per actor, lossless migration, compliant &
  recoverable, EU/AI-ready.

---

## Executive Summary (template slide)
- **One trusted profile** across 6 systems: Data Cloud (customers) + MDM (dealers), ERP stays master.
- **Fast at scale:** store what we operate on, **look up** 144M+ records we only reference; LDV-tuned org.
- **Lossless migration:** ETL + Bulk + external IDs + audit-field preservation; **3-month bi-directional**
  coexistence, then clean cutover.
- **Quality with a P&L:** prevention + stewardship + **DQ metrics tied to dollars**, corrections synced to
  ERP.
- **Compliant & recoverable:** tiered 7-yr retention (hot/near-line/archival) + Backup + Shield.
- **Future-ready:** EU multi-org + AI on the same unified foundation.

## Thank you (template slide)
- *[Name · contact] — questions?*

---

## Demo checklist (the "functioning demo of core components")
Pick 2–3 you can actually show; a working demo beats slides for the judge:
1. **External Object invoice/service-record lookup** on a Case/Vehicle — data shown live, none stored.
2. **Duplicate/Matching rule** blocking a dupe dealer + a **DQ dashboard** tile.
3. **Big Object** archived case surfaced read-only in the console.
4. **Sharing:** a consumer community user seeing only their own vehicle/cases (Sharing Set).
5. **Restriction Rule** hiding a dealer-complaint case from a normal agent.

---

## Coverage check — every rubric objective is on a slide

| Objective | Weight | Slide(s) |
|---|---:|---|
| Design & Optimization | 15% | 2 (LDV + model) |
| Data Migration | 15% | 3 |
| Data Quality | 13% | 4 |
| Data Movement | 10% | 1, 3 |
| Master Data Management | 10% | 4 |
| Reference Data Management | 10% | 4 |
| Data Solution Architecture | 10% | 1, 5 |
| Data Archiving | 9% | 4 |
| Data Governance & Stewardship | 8% | 4 |

| Required deliverable | Slide(s) |
|---|---|
| Licenses + Role hierarchy | 5 |
| 2-yr volume estimates | 2 |
| Data model (M-D/lookup/external, OWD, owner, LDV, off-platform) | 2 |
| System landscape | 1 |
| Migration (one-time + ongoing sync) | 3 |
| LDV access strategy | 1, 2 |
