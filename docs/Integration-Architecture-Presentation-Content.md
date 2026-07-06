# Bedrock Financial Services — Integration Architecture
### Presentation content (maps to the badging template; ≤5 content slides)

> **Format:** 20 min present · 25 min Q&A · audience = **Enterprise Architecture Group**. Template allows section-divider slides; the **content** is kept to 5 substantive slides as instructed. Speaker notes are the "what to say"; on-slide text is intentionally lean for a busy exec.

---

## Title slide
**Bedrock Financial Services — Integration Architecture**
Master-data integration across CRM, customer master, position master, core banking & the data lake
*[Your Name] · [Title] · [email] · [date]*

---

## Agenda (template slide — keep as-is)
- Introduction (elevator pitch)
- Problem statement
- Proposed solution — architecture & assumptions
- Interface list (patterns, APIs, security, error handling)
- Integration security
- Summary & trade-offs

---

## Who am I? (template slide — personalize)
Integration / Salesforce architect; experience designing API-led, event-driven integrations for regulated financial-services platforms at scale.

---

# SLIDE 1 — High-Level Problem Statement

**On-slide:**
- BFS struggles with **master data** across customers and securities/products.
- **Customer Master** = Hadoop (EA-owned, partly outsourced, real-time + batch). **Position Master** = separate system; business wants **real-time** access in Salesforce.
- Salesforce = master for Chatter, Opptys, Leads, Cases.
- **Volumes:** 5M customers · ~2 accounts each · 10 txns/account/day (~100M/day) · multi-PB warehouse · 150 sales + 500 service reps.
- **The challenge:** connect many heterogeneous systems **in the right pattern** — near-real-time marketing, multi-agency credit checks, headless self-service, transaction-history virtualization, atomic loan writes, legacy migration & coexistence, and a change-history feed to the data lake — **securely, monitorably, and reusably**.

**Speaker notes:**
"Bedrock's core problem is master data fragmentation. No single system owns the customer, so we must integrate Salesforce with the Hadoop customer master, a separate position master, core banking, Marketing Cloud, a Drupal portal, external credit agencies, a legacy system, and a cloud data lake — each with a different latency, volume, and security profile. The art is choosing the **correct integration pattern** for each, not a one-size-fits-all approach."

---

# SLIDE 2 — Solution Architecture (Context) + Key Assumptions

**On-slide (context diagram description):**
- **Center:** Salesforce (Sales, Service, **headless Experience Cloud**, Platform Events/CDC, Salesforce Connect).
- **Backbone:** **MuleSoft Anypoint (API-led: System → Process → Experience APIs)** — every cross-system interface flows through it for **central monitoring, reusable templates, error queue (DLQ), and mTLS policy**.
- **Spokes:** Marketing Cloud · Drupal portal + hybrid mobile · Credit agencies (×3+) · Core banking (OData) · Customer Master (Hadoop) · Position Master · Legacy **RockStar** · **Enterprise Data Lake**.
- **Three integration styles in play:** **request-reply** (credit checks, portal), **event-driven fire-&-forget** (registration fan-out, loan events, data-lake CDC), **data virtualization** (transaction history).

**Key assumptions (on-slide bullets):**
- MuleSoft Anypoint licensed; certs/identities provisioned by EA.
- Customer Master offers real-time + batch; Position Master has a callable API.
- Core banking exposes OData; credit agencies expose REST + OpenID Connect.
- Data lake can subscribe to a stream; PII field list agreed with governance.
- Salesforce stays master for Chatter/Opptys/Leads/Cases; **no Communities UI** (headless only).

**Speaker notes:**
"We standardize on an **API-led architecture on MuleSoft** — a Salesforce product — as the integration hub. System APIs wrap each backend once; Process APIs orchestrate (e.g., fan-out credit checks); Experience APIs serve the portal and mobile. This is what delivers the brief's explicit asks for central monitoring, a reusable template library, an admin error queue, and mutual auth everywhere."

---

# SLIDE 3 — Interface List  *(the centerpiece — patterns + APIs + security + error handling)*

| ID | Source → Target | Content | Pattern | SF API / Mechanism | Security | Error handling |
|----|------------------|---------|---------|--------------------|----------|----------------|
| INT-01 | Marketing Cloud → SF | Leads near-real-time to **swarm** | Remote Call-In + UI Update | Platform Event / Pub-Sub; `empApi` | OAuth + mTLS | Replay by replayId; DLQ |
| INT-02 | Drupal → SF | Capture **prospect** | Remote Call-In (Req-Reply) | REST API | OAuth + mTLS | Sync error; retry 5xx |
| INT-03 | Rules engine → SF | Daily **call-list** load | Batch Data Sync | **Bulk API 2.0** | Named Cred + mTLS | Failed-row reprocess |
| INT-04 | SF UI → map | Call list **on a map** | UI integration | `lightning-map` / Maps | Key in Named Cred | "Address not found" fallback |
| INT-05 | SF → Manager UI | **High-value call closed** live | UI Update on Data Change | **Platform Event** + `empApi` | Sharing/FLS | Resubscribe + replay |
| INT-06 | SF → Credit agencies | **Credit checks** ×3+, ≤1 min, partial retry | RPC **Request & Reply** | **Apex Continuation** / Flow HTTP Callout → Mule fan-out | **OpenID Connect** + mTLS | "Agency XYZ down"; **resubmit retries only failed** (idempotent) |
| INT-07 | SF → Hadoop + Position Master | Registered customer **near-real-time** | RPC **Fire & Forget** | **Platform Event** → Mule fan-out | mTLS | Retry + DLQ → admin queue |
| INT-08 | Master → Experience Cloud | **Create/activate** user + invite | Remote Call-In | REST + `createExternalUser` | OAuth + mTLS | Retry queue |
| INT-09 | Drupal ↔ Experience Cloud | Real-time self-service **as end-user** | Remote Call-In (Req-Reply) | **Connect REST / headless APIs** | **End-user OAuth — no API user** + mTLS | 401 → re-auth |
| INT-10/12 | Drupal → SF | Contact info / **raise inquiry** | Remote Call-In | REST API (end-user) | End-user OAuth + mTLS | Validation error to UI |
| INT-11 | SF → Core banking | **Transaction history** >100k/hr | **Data Virtualization** | **Salesforce Connect (OData)** + Mule cache | Named Cred + mTLS | Circuit breaker; cached/graceful |
| INT-13 | SF → Customer Master | **Propagate updates** | RPC Fire & Forget | **Platform Event / CDC** → Mule | mTLS | Retry + DLQ |
| INT-14 | Mobile → SF | Same functions as portal | Remote Call-In | **REST / GraphQL** | End-user OAuth (PKCE) + mTLS | Offline retry |
| INT-15 | Drupal/Mule → SF | **Loan app** all-or-nothing | Remote Call-In (transactional) | **Composite API** (`allOrNone`) | OAuth + mTLS | Whole-graph rollback |
| INT-16 | SF ↔ Trading system | **No swivel** + **auto-log** | UI mashup + RPC | **Canvas/iframe + SSO**; log callout | SSO + mTLS | Log retry queue |
| INT-17 | SF → ESB | **Millions of loan events/day** | RPC Fire & Forget (scale) | **HVPE / Pub-Sub API** | OAuth + mTLS | Replay + DLQ; monitor allocations |
| INT-18 | RockStar ↔ SF | **Migration + 3-mo sync** | Batch + near-real-time sync | **Bulk API 2.0** + CDC ↔ Mule | mTLS | Bulk error rows; Mule conflict rules |
| INT-19 | SF → Data Lake | **Non-PII**, ins/upd/del, **history, changed-fields-only** | RPC Fire & Forget (event-driven) | **Change Data Capture** → Mule | mTLS + PII filter | Replay; gap detect; DLQ |

**Speaker notes (hit the high-weight objectives explicitly):**
- **Patterns (20%):** "Each interface is tagged with one of the five catalog patterns — request-reply, fire-&-forget, batch sync, remote call-in, UI update, and data virtualization."
- **APIs (15%):** "Single small records → REST; millions of rows → Bulk; atomic graph → Composite; push to screens/decouple → Streaming/Pub-Sub + Platform Events; expose without copying → Salesforce Connect."
- **Event-driven (10%):** "Custom business moments → **Platform Events** (INT-01/05/07/13/17); replicate *what changed* incl. deletes & history → **CDC** (INT-19)."
- **Callouts (10%):** "Declarative **Flow HTTP Callout** for simple calls; programmatic **Apex Continuation** for the ≤1-min, 30-concurrent credit checks so we don't hold threads."
- **Virtualization (10%):** "Transaction history stays in core banking via **Salesforce Connect/OData**; we cache the hot path in Mule to survive 100k+/hr."

---

# SLIDE 4 — Integration Security

**On-slide:**
- **Mutual TLS on every interface** (explicit requirement) — enforced centrally at MuleSoft API Manager + via Named Credentials.
- **Outbound:** Named/External Credentials; **OpenID Connect / OAuth 2.0** to credit agencies — no secrets in code.
- **Inbound:** OAuth 2.0 — client-credentials for server-to-server (Drupal form), **Authorization Code / PKCE** for end-user & mobile.
- **End-user, not API user** (INT-09): portal/mobile call Experience Cloud with the **end-user's token**, honoring **sharing & FLS** — meets BFS security mandate.
- **Data protection:** Shield encryption for PII at rest; **PII excluded** from the data-lake CDC stream; field filtering in Mule.
- **Governance:** least-privilege connected apps/permission sets; central policy, threat protection & audit at API Manager + Salesforce Event Monitoring.

**Speaker notes:**
"Two security points the EA group will care about most: first, **mutual auth is universal** and centrally enforced at the Mule layer; second, **the community is accessed strictly as the authenticated end-user, never an API user**, so per-user sharing is preserved — exactly as the security team mandated."

---

# SLIDE 5 — Summary & Trade-offs

**On-slide:**
- **One API-led backbone (MuleSoft):** delivers the brief's **central monitoring**, **reusable connection templates**, **admin error queue (DLQ)**, and **uniform mTLS** — and **justifies the license**: reuse → faster GTM, lower TCO, fewer governor-limit issues, audit-ready in a regulated industry; new agency/system = **config, not code**.
- **Right pattern per use case:** request-reply (credit), fire-&-forget events (registration, loan, lake), batch (migration/call-list), virtualization (history), UI update (manager screen), transactional (loan all-or-nothing).
- **Key trade-offs articulated:**
  - **Virtualize vs replicate** transaction history → virtualize (Salesforce Connect) + cache hot path; don't store 100M+/day.
  - **Sync vs async credit checks** → Apex Continuation (async) to scale 30 concurrent ×1 min.
  - **Platform Events vs CDC** → CDC for INT-19 (native history + changed-fields + deletes).
  - **Native vs middleware** → middleware where monitoring/reuse/error-queue/security uniformity pays off; native for pure UI (map) and direct atomic writes.
- **Quantified outcomes:** scales to 5M customers / ~100M txns/day / >100k history calls/hr / millions of loan events/day; resilient (replay + DLQ); secure (mTLS + end-user auth); reusable (API-led assets).

**Speaker notes:**
"In summary: an **API-led, event-driven** design on a **MuleSoft backbone**, with the **correct integration pattern and Salesforce API chosen per interface**, secured with **mutual TLS and end-user authentication**, and resilient through **replay and dead-letter retry**. The middleware investment pays for itself through reuse, faster go-to-market, and centralized monitoring and security in a regulated financial-services context."

---

## Thank you (template closing slide)
*Questions?*
