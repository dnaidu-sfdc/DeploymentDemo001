# Bedrock Integration Architecture — Requirements Mapping, Thought Process & Trade-offs

This document is the reasoning artifact behind the Integration Architecture solution for **Bedrock Financial Services (BFS)**. For each scenario requirement it records:

- **What is being asked** (in plain terms)
- **The integration pattern** selected (from the Salesforce *Integration Patterns and Practices* catalog) and *why*
- **The Salesforce API / mechanism** that realizes the pattern
- **Security** (auth model per interface)
- **Error handling** appropriate to that pattern
- **Trade-offs, alternatives, and considerations** — scale, performance, limits, extensibility
- **Mapping to the Interface List** used on the presentation

Source documents: `docs/Bedrock Scenario - Integration Architecture - 2025.pdf`, presentation template `docs/Integration Architecture Badging Presentation Template.pptx.pdf`.

> **Nature of this badge.** Integration Architecture is a **design** badge. The deliverable is a ≤5-slide presentation to the customer's Enterprise Architecture Group plus a Q&A. No code is deployed; the centerpiece is the **Interface List** (pattern + API + security + error handling per interface) backed by justified trade-offs.

---

## 1. The five integration patterns (the vocabulary we score on)

The 20% "correct integration pattern per use case" objective is graded against the canonical catalog. Every interface below is tagged with one of these:

| Pattern | When to use | Timing | Typical Salesforce mechanism |
| --- | --- | --- | --- |
| **Remote Process Invocation — Request & Reply** | SF calls an external system **and needs the response now** to continue | Synchronous | Apex callout, Flow HTTP Callout, Apex Continuation, External Services |
| **Remote Process Invocation — Fire & Forget** | SF triggers an external process but **doesn't wait** for the result | Asynchronous | Platform Events, Outbound Message, future/Queueable callout |
| **Batch Data Synchronization** | Bulk import/export / keep two stores aligned on a schedule | Asynchronous, scheduled | Bulk API 2.0, MuleSoft batch, ETL |
| **Remote Call-In** | An **external system calls Salesforce** to CRUD data or invoke logic | Sync or async | REST API, SOAP API, Bulk API, Composite API, Connect REST/Experience Cloud APIs, Pub/Sub API |
| **UI Update Based on Data Changes** | A user's screen must refresh **the moment** data changes elsewhere | Near-real-time push | Platform Events + `lightning/empApi`, CDC, Pub/Sub API |
| **Data Virtualization** | Read/expose external data **without copying it** into Salesforce | Real-time, on-demand | Salesforce Connect (OData 2.0/4.0 adapter, custom Apex adapter), external objects |

---

## 2. Requirements traceability matrix (Interface List)

Each scenario requirement maps to one or more interfaces. This table is the backbone of the **Interface List** slide.

| ID | Interface (Source → Target) | Content | Pattern | Salesforce API / Mechanism | Security | Error handling |
| --- | --- | --- | --- | --- | --- | --- |
| **INT-01** | Marketing Cloud → SF (via MuleSoft) | New **Leads** in near-real-time to "swarm" | Remote Call-In + UI Update | Pub/Sub API / **Platform Event** in; LWC `empApi` to alert reps | OAuth 2.0 + mTLS at Mule | Event replay by `replayId`; DLQ for failed publishes |
| **INT-02** | Drupal form → SF | Capture **prospect** details for rep follow-up | Remote Call-In (Request & Reply) | **REST API** (create Lead/Prospect) | OAuth 2.0 client-credentials at Mule, mTLS | Synchronous error to portal; retry on 5xx |
| **INT-03** | Rules engine (Heroku/Mule) → SF | Daily **call-list** load; offload heavy compute | Batch Data Synchronization | **Bulk API 2.0** (upsert by External Id) | Named Credential + mTLS | Per-row job errors → reprocess failed rows; error log |
| **INT-04** | SF UI → mapping/geocoding | Render call list **on a map** to route reps | UI Integration (Data Virtualization assist) | `lightning-map` / Salesforce Maps; geocode callout | API key in Named Credential / Protected Custom Setting | Graceful "address not found" fallback |
| **INT-05** | SF → Manager's screen | Manager sees rep **closed a high-value call** instantly | UI Update Based on Data Changes | **Platform Event** + `lightning/empApi` subscription | Platform (sharing/FLS); CometD session | Client resubscribe + replay from last `replayId` |
| **INT-06** | SF → Credit agencies (via MuleSoft) | **Credit checks**, ≥3 agencies, ≤1 min, partial retry | Remote Process Invocation — Request & Reply | **Apex Continuation** (or **Flow HTTP Callout**) → Mule canonical Credit API that fans out | **OpenID Connect** (External/Named Credential) + mTLS | Per-agency status; show "Agency XYZ unavailable"; **idempotent resubmit retries only failed** agencies |
| **INT-07** | SF → Hadoop + Position Master (via Mule) | Registered customer pushed **near-real-time** to 3 systems | Remote Process Invocation — Fire & Forget | **Platform Event** → Mule fan-out | mTLS, per-system credentials at Mule | Event retry + DLQ; admin error queue |
| **INT-08** | Customer Master → SF (Experience Cloud) | **Create + activate** community user, send invite | Remote Call-In | REST API + `Site.createExternalUser` (Apex) | OAuth, mTLS | Synchronous failure surfaced; retry queue |
| **INT-09** | Drupal ↔ Experience Cloud | Real-time self-service **as the authenticated end-user** | Remote Call-In (Request & Reply) | **Connect REST API / Experience Cloud headless APIs** | **End-user OAuth (Authorization Code/SSO) — no API user**; mTLS | 401 → re-auth; user-facing error |
| **INT-10** | Drupal → SF | Retrieve/update **address, phone, contact** | Remote Call-In | REST API (sObject / Composite) as end-user | End-user OAuth, mTLS | Validation errors returned to UI |
| **INT-11** | SF → Core banking (OData) | **Transaction history**, >100k calls/hr at peak | **Data Virtualization** | **Salesforce Connect — OData adapter**, external objects (+ Mule caching/throttle) | Named (External) Credential, mTLS; per-user OAuth where required | Source-down → cached/graceful message; circuit breaker at Mule |
| **INT-12** | Drupal → SF | Raise an **inquiry** (Case) | Remote Call-In | REST API (create Case) as end-user | End-user OAuth, mTLS | Validation error to portal |
| **INT-13** | SF → Customer Master (via Mule) | Propagate **customer info updates** | Remote Process Invocation — Fire & Forget | **Platform Event** / CDC → Mule | mTLS, Mule credentials | Event retry + DLQ; admin error queue |
| **INT-14** | Hybrid mobile app → SF | Same self-service functions as portal | Remote Call-In | **REST / GraphQL API**, Connect REST | End-user OAuth (PKCE), mTLS | Same as portal; offline-tolerant retries |
| **INT-15** | Drupal/Mule → SF | **Loan application** = parent + children, all-or-nothing | Remote Call-In (transactional) | **Composite API** (`allOrNone=true`) / sObject Tree | End-user/OAuth, mTLS | Whole graph rolls back; structured error per node |
| **INT-16** | SF ↔ External trading system | Reps work it **without swiveling**; **auto-log** the interaction | UI Integration + Remote Process Invocation | **Canvas app / iframe + SSO** (UI mashup); RPC callout to log | SSO (SAML/OAuth), mTLS | Log failures queued for retry |
| **INT-17** | SF → ESB/consumers | **Millions of loan-processing events/day** | Remote Process Invocation — Fire & Forget (event-driven at scale) | **High-Volume Platform Events** / **Pub/Sub API** | mTLS, OAuth | Replay + DLQ; monitor event delivery usage |
| **INT-18** | RockStar ↔ SF | **Migration** + 3-month **bi-directional sync** | Batch Data Sync (migration) + near-real-time sync | **Bulk API 2.0** (load) + CDC/Platform Events ↔ Mule (sync) | mTLS, Mule credentials | Bulk error rows reprocessed; conflict rules in Mule |
| **INT-19** | SF → Enterprise Data Lake (via Mule) | **Non-PII** customers + transactions; inserts/updates/deletes; **full history; changed fields only** | Remote Process Invocation — Fire & Forget (event-driven) | **Change Data Capture (CDC)** → Mule → lake | mTLS; field-level filtering of PII | Replay from `replayId`; gap detection; DLQ |

---

## 3. Per-requirement deep dive

### Section 1 — Marketing / Campaigns

#### INT-01 — Near-real-time Leads to "swarm" (Marketing Cloud → SF)
**Ask:** Marketing Cloud generates leads from email/social campaigns; the team wants them in **near-real-time** to immediately swarm and track.

**Pattern & mechanism:** **Remote Call-In** feeding an event, plus **UI Update Based on Data Changes**. Marketing Cloud (via MuleSoft) publishes a **Platform Event** (or creates the Lead) into Salesforce; a trigger/Flow routes/assigns it, and reps' list views update. "Swarm immediately" is the give-away for an **event**, not a nightly batch.

**Trade-offs:** Platform Event (decoupled, replayable, fan-out to multiple subscribers) vs. a direct REST Lead insert (simpler, but tightly coupled and no replay). At low volume either works; the event wins because the same lead event can also notify a Slack/CTI swarm channel without re-integrating.

#### INT-02 — Prospect capture form (Drupal → SF)
**Ask:** Prospect details from a Drupal form, followed up by reps; volume low hundreds → 1000+ in two years.

**Pattern & mechanism:** **Remote Call-In, Request & Reply** via **REST API** (create Lead/Prospect, return the Id/confirmation to the portal). Volume is tiny, so synchronous is fine.

**Trade-offs:** REST (lightweight JSON, ideal for a web form) over SOAP (heavier contract) or Bulk (overkill for single records). Routed through MuleSoft so the same "create prospect" System API is reusable by other channels later.

#### INT-03 — Call-list generation is getting slow (rules engine → SF)
**Ask:** A **complex custom business-rules engine** (demographics, rep availability, geography) builds reps' call lists, maintained in Salesforce and updated daily. Run times are growing and threaten the SLA for high-value prospect callouts.

**The crux:** heavy, complex computation does **not** belong in Apex Batch competing for governor limits. **Offload the compute** to where it scales (Heroku / the rules engine / MuleSoft batch), then **load the finished call list into Salesforce**.

**Pattern & mechanism:** **Batch Data Synchronization** using **Bulk API 2.0** (upsert by External Id) on a daily schedule. Delta loads only (changed assignments) to keep run time down.

**Trade-offs:** Keeping the engine in Apex Batch (no extra infra, but bound by Apex limits and the very slowness we're trying to fix) vs. offloading (scales independently, removes SLA risk, but adds an external compute component). Given the explicit "run times getting longer / SLA risk," offload + Bulk load is the defensible choice. Bulk API 2.0 over REST because it's built for large daily volumes and is asynchronous with built-in job-level error reporting.

#### INT-04 — Call list on a map (UI integration)
**Ask:** Show the call list **on a map** using the form-provided address to route the rep to the nearest Bedrock office.

**Pattern & mechanism:** **UI integration**. Use `lightning-map` / Salesforce Maps (auto-geocoding, no API key) for the markers; if custom routing is needed, a geocoding callout via a Named Credential.

**Trade-offs:** Base `lightning-map` (secure, no key, mobile/accessible) vs. custom Google Maps JS (more control, but API-key management, CSP/LWS, billing). The base component is the lean, secure default.

#### INT-05 — Manager real-time screen update (SF → manager UI)
**Ask:** A manager's Salesforce screen must update **the moment** a rep closes a call with a high-value prospect.

**Pattern & mechanism:** **UI Update Based on Data Changes**. On call close, publish a **Platform Event**; the manager's LWC subscribes via **`lightning/empApi`** (CometD/Streaming) and updates live — no polling.

**Trade-offs:** Platform Event (purpose-built custom event, decoupled) vs. **CDC** on the Task/call object (zero-code change feed, but couples the UI to the data model and emits on *every* change, noisier). For a specific business moment ("high-value call closed"), a purpose-named Platform Event is cleaner than filtering CDC. Polling/auto-refresh is rejected (latency + load).

### Section 2 — Customer Conversion / Registration

#### INT-06 — Credit checks across multiple agencies (SF → agencies)
**Ask:** Reps run **credit checks** through external agencies (**REST, OpenID Connect**); **30 concurrent** reps; **≤1 min** response acceptable; compare **≥3 agencies**, must be **extensible** to more; if an agency is down, show "Agency XYZ unavailable", allow **resubmit**, and **only re-run the failed checks**.

**This is the richest interface — it touches callouts (10%), APIs (15%), security (5%), error handling (5%), and trade-offs (5%).**

**Pattern & mechanism:** **Remote Process Invocation — Request & Reply**. Salesforce makes **one** call to a **MuleSoft "canonical Credit Check" API**; Mule **fans out** to the N agencies in parallel, aggregates the scores, and returns a single response. Because a credit check can take up to a minute and 30 reps may be concurrent, the Salesforce side uses **Apex Continuation** (asynchronous callout that does **not** hold a thread or consume the synchronous concurrent-request limit) — or, declaratively, a **Flow HTTP Callout / External Service** action for a low-code build.

**Why middleware here is decisive:**
- **Extensibility:** adding a 4th/5th agency is a Mule config/connector change — **no Salesforce change**. Satisfies "flexible to expand with additional agencies."
- **Partial-failure semantics:** Mule tracks per-agency status and supports an **idempotent resubmit that retries only the failed agencies** (keyed by a request correlation Id). Doing this natively in Apex would mean hand-building per-agency state and retry tracking.
- **Aggregation:** comparing 3+ scores belongs in the integration tier, not in the rep's transaction.

**Security:** **OpenID Connect** to the agencies, modeled as an **External Credential + Named Credential** (or enforced at Mule), plus **mTLS**. No secrets in code.

**Error handling:** response carries per-agency `{agency, status, score|error}`; the LWC shows "Agency XYZ is unavailable"; **resubmit** sends only the failed agency set; correlation Id guarantees idempotency so successful agencies aren't re-charged/re-queried.

**Trade-offs:** Continuation (scales to many concurrent long callouts, async) vs. synchronous Apex callout (simpler, but ties up the request and risks the concurrent-long-running-request limit at 30 reps × ~1 min). Flow HTTP Callout (declarative, admin-maintainable) vs. Apex (full control of aggregation/retry) — we note both to satisfy the "declaratively *and* programmatically" objective; the heavy aggregation/retry logic favors Mule + Apex Continuation, with Flow HTTP Callout as the low-code alternative for simpler agency calls.

#### INT-07 — Distribute the registered customer near-real-time (SF → Hadoop + Position Master)
**Ask:** A registered customer must be passed to **Hadoop DB, Salesforce, and the Position Master** near-real-time.

**Pattern & mechanism:** **Remote Process Invocation — Fire & Forget**. Salesforce publishes a **Platform Event**; MuleSoft subscribes and **fans out** to Hadoop and the Position Master. SF doesn't block on the downstream systems.

**Trade-offs:** Fire-and-forget event (decoupled, survives downstream outages, replayable) vs. synchronous multi-callout (brittle — one slow/down system blocks registration). The event is the resilient choice; Mule provides the DLQ + admin retry the scenario asks for.

#### INT-08 — Provision & invite the community user
**Ask:** From the customer master, **create and activate** the Experience Cloud user and send an invite with login + temp password.

**Pattern & mechanism:** Triggered by the registration event; provisioning via Apex (`Site.createExternalUser`) or Flow. Mostly platform automation rather than a distinct external interface, but listed for completeness.

### Section 3 — Customer Management

#### INT-09 — Drupal drives Experience Cloud as the end-user (headless)
**Ask:** The Drupal portal must interact with the **Experience Cloud** self-service solution **in real-time**, but **the Communities UI is not used**, and access must be **as an authenticated end-user, not an API user**.

**Pattern & mechanism:** **Remote Call-In, Request & Reply** against **Connect REST API / Experience Cloud "headless" APIs**. Drupal renders the UI; Salesforce is the data + identity + business-logic layer. The customer authenticates (SSO / OAuth **Authorization Code** flow), and Drupal calls Salesforce **with the end-user's access token**, so every call runs in that user's context and honors sharing/FLS.

**Security (key requirement):** **no integration/API user** — the end-user's OAuth token is used, satisfying the BFS security mandate. This is the crux of Section 3 and a strong security-objective talking point.

**Trade-offs:** End-user OAuth (honors per-user sharing, auditable, meets the mandate) vs. a single API/integration user (simpler but **explicitly forbidden** and would over-expose data). Headless Experience Cloud (reuse Salesforce sharing/s-controls while keeping the Drupal UX) vs. rebuilding everything in Drupal against raw APIs (loses Experience Cloud's licensing/sharing model).

#### INT-10 / INT-12 — Retrieve & update contact info; raise an inquiry
**Pattern & mechanism:** **Remote Call-In** via **REST API** as the authenticated end-user (same token as INT-09). Reads/updates of address/phone/contact; Case creation for inquiries. Updates trigger INT-13 (propagation to the Customer Master).

#### INT-11 — Transaction history via OData at scale (Data Virtualization)
**Ask:** Balances/transaction history live in **core banking**, exposed via an **OData connector**; in peak seasons the volume will exceed **100,000 history calls/hour**, and the system must perform seamlessly.

**Pattern & mechanism:** **Data Virtualization** via **Salesforce Connect (OData adapter)** → **external objects**. Data is **not copied** into Salesforce (avoids storing 5M × 2 × 10/day = 100M+ rows/day of transactions); it's read **on demand** and presented in Lightning/related lists like any sObject.

**The performance crux (100k+/hr):** raw Salesforce Connect has per-org callout/limit ceilings and the source must sustain the load. Strategy:
- Front the OData source with **MuleSoft** providing **caching, throttling, and a circuit breaker** so repeat lookups (same account, same day) don't hammer core banking.
- Use **indirect lookups / external object** relationships so the UI is native.
- For the hottest data (recent transactions), consider a **cached/replicated read-model** (write-through cache) while keeping deep history virtualized — a virtualize-vs-cache trade-off the EA group will expect.

**Trade-offs:** Salesforce Connect/virtualization (no storage, always current, lower license/data cost) vs. **replication** via Bulk/CDC into Salesforce (fast reads, offline-capable, but huge storage + sync burden and stale risk). At 100k/hr the answer is *virtualize + cache the hot path*, not blind replication.

#### INT-13 — Propagate customer updates to the Customer Master (SF → master)
**Pattern & mechanism:** **Remote Process Invocation — Fire & Forget** via **Platform Event / CDC** → MuleSoft → Hadoop customer master. Near-real-time, decoupled, replayable.

#### INT-14 — Hybrid mobile app
**Pattern & mechanism:** **Remote Call-In** via **REST / GraphQL API** + Connect REST, same end-user OAuth (with **PKCE** for the mobile client). GraphQL noted for efficient, low-chattiness fetches on mobile.

#### INT-15 — Loan application: all-or-nothing (Drupal/Mule → SF)
**Ask:** A loan application is an `Application` parent plus several child records; **no partial commits** — if any record fails, the **entire set rolls back**.

**Pattern & mechanism:** **Remote Call-In** with **transactional integrity** via the **Composite API** (`allOrNone=true`) or **sObject Tree API**, which commit the whole object graph in **one atomic transaction**.

**Trade-offs:** Composite/`allOrNone` (single round-trip, atomic, server-side rollback) vs. multiple discrete REST calls + client-side compensation (chatty, race-prone, must hand-roll rollback). Composite is the textbook answer for atomic multi-object writes.

#### INT-16 — Work the external trading system without swiveling; auto-log
**Ask:** Reps must navigate an external system's **complex screen/process flows** to answer trading queries **without swiveling**, and the logging to that system should be **automated** (improving handle time + CSAT).

**Pattern & mechanism:** **UI integration (mashup)** — embed the external app inside the Salesforce record page via a **Canvas app / iframe with SSO** so the rep never leaves Salesforce. Pair it with **Remote Process Invocation** to **auto-log** the interaction (a callout writes the log entry, or the external system call-ins to log).

**Trade-offs:** UI mashup/Canvas (fastest path to "no swivel", reuses the external system's complex flows as-is) vs. rebuilding those flows natively in Salesforce (huge effort, duplicates a working system). Canvas + SSO is the pragmatic, lower-risk choice.

### Other / cross-cutting requirements

#### INT-17 — Millions of loan-processing events per day (async at scale)
**Ask:** Account for **large-scale async** with **millions of events/day** from loan processing.

**Pattern & mechanism:** **Event-driven, Fire & Forget** using **High-Volume Platform Events** consumed via the **Pub/Sub API** (gRPC, efficient, modern replacement for the Streaming API). MuleSoft or external consumers subscribe.

**Trade-offs:** HVPE/Pub-Sub (built for high throughput, replay, decoupling) vs. row-by-row callouts (won't survive millions/day, will blow callout/async limits). Must monitor **event delivery allocations** and design idempotent consumers.

#### INT-18 — RockStar migration + 3-month bi-directional sync
**Ask:** Migrate all data from legacy **RockStar** to Salesforce pre-go-live; keep RockStar live for **3 months** post-go-live with a small number of transactions, so **both systems stay in sync** until RockStar is decommissioned.

**Pattern & mechanism:** Two phases:
1. **Migration** — **Batch Data Synchronization** via **Bulk API 2.0** (parallel, large volume, job-level error rows).
2. **Coexistence sync (3 months)** — near-real-time **bi-directional sync** mediated by **MuleSoft**: SF changes flow out via **CDC/Platform Events**; RockStar changes flow in via Mule using **upsert by External Id**. Mule owns **conflict resolution** (source-precedence / last-writer-wins / timestamp rules) and idempotency.

**Trade-offs:** Middleware-mediated sync (central conflict handling, monitoring, retry) vs. point-to-point triggers/callouts (no conflict authority, hard to monitor). For a temporary dual-run with write-backs on both sides, the middleware hub is the safer pattern. Bulk API for the one-time load; events for ongoing deltas (not repeated full extracts).

#### INT-19 — Data lake sync: history of changes, changed fields only, non-PII
**Ask:** Post-go-live, sync **all customers (non-PII fields only)** and related transactions from Salesforce to a cloud **Enterprise Data Lake**: **all inserts, updates, deletes**; for updates, the **full history** of changes (not just the latest); and **only the changed fields** (not all fields).

**This is the textbook Change Data Capture use case** — and a clean way to bank the 10% event-driven objective.

**Pattern & mechanism:** **Change Data Capture (CDC)**. CDC emits a change event for **every** create/update/delete, the event header carries the **`changeType`** (CREATE/UPDATE/DELETE/UNDELETE) and the **list of changed field names**, and the payload contains **only the changed fields** — exactly matching "changed fields only" and "history of updates, not just last values" (each update is its own event, so the lake reconstructs full history). MuleSoft subscribes via the **Pub/Sub API** and writes to the lake; **PII fields are excluded** at the CDC channel/field-selection level (and again filtered in Mule).

**Trade-offs:** **CDC** (no custom publish code, automatic field-level deltas + change type, replayable) vs. **custom Platform Events** (you'd hand-build the delta/changed-field logic and history) vs. **nightly Bulk extract** (only last values, no per-change history, no deletes — fails the requirement). CDC is the only option that natively satisfies *history + changed-fields-only + deletes*. Manage the **3-day CDC retention / replayId** window for catch-up.

---

## 4. Salesforce API selection (the 15% objective)

A clear "which API, when" view. The Interface List above already assigns one to each interface; this is the justification the judge will probe in Q&A.

| API | Style | Best for | Where used in Bedrock |
| --- | --- | --- | --- |
| **REST API** | Synchronous, JSON, lightweight | Web/mobile CRUD, single/small record ops, request-reply | Prospect form (INT-02), contact info, inquiries, mobile (INT-10/12/14) |
| **SOAP API** | Synchronous, XML, strongly-typed WSDL contract | Enterprise/legacy systems that need a formal contract or are SOAP-only | Fallback for any agency/core system that only speaks SOAP; mentioned for completeness |
| **Bulk API 2.0** | Asynchronous, batched | **Large data volumes** — migrations and scheduled loads | Call-list daily load (INT-03), RockStar migration (INT-18) |
| **Streaming API (PushTopic/Generic) → Pub/Sub API** | Subscribe / push | **Event subscription** and near-real-time UI | Manager screen (INT-05), CDC/event consumers (INT-17/19) |
| **Composite API / sObject Tree** | Synchronous, multi-op, transactional | **Atomic multi-record writes** (`allOrNone`) | Loan application all-or-nothing (INT-15) |
| **Connect REST / Experience Cloud APIs** | Synchronous, end-user context | Headless community / portal interactions as the end-user | Drupal ↔ Experience Cloud (INT-09) |
| **GraphQL API** | Synchronous, client-shaped queries | Efficient, low-chatter mobile fetches | Hybrid mobile app (INT-14) |
| **Pub/Sub API** | gRPC, publish + subscribe | High-throughput events, CDC consumption, replay | HVPE (INT-17), CDC to data lake (INT-19) |

**Decision rules to state aloud:** *single small record / interactive →* REST; *millions of rows / scheduled →* Bulk; *need the whole graph atomic →* Composite; *push to a screen / decouple →* Streaming/Pub-Sub + Platform Events; *expose external data without copying →* Salesforce Connect (not an API per se, an adapter); *strict contract / SOAP-only partner →* SOAP.

---

## 5. Event-driven integration: Platform Events vs Change Data Capture (the 10% objective)

| | **Platform Events** | **Change Data Capture (CDC)** |
| --- | --- | --- |
| What fires it | **You** publish (Apex, Flow, API) a custom-defined event | **The platform** auto-fires on record create/update/delete/undelete |
| Schema | Custom event fields you design | Mirrors the object; header carries `changeType` + **changed field names** |
| Best for | Business moments / commands ("lead arrived", "customer registered", "order ready") | **Data replication / audit** — keep another store in sync with *what changed* |
| Bedrock use | INT-01 swarm, INT-05 manager UI, INT-07/13 fan-out, INT-17 loan events | INT-19 data-lake sync (history + changed-fields-only + deletes), INT-18 SF→RockStar deltas |
| Delivery | Pub/Sub API, `empApi`, Flow, Apex triggers; **replayId** for replay | Same channel; **replayId**; ~3-day retention |

**Talking point:** choose **Platform Events** when *you* define the business signal and may have multiple intent-specific subscribers; choose **CDC** when the requirement is literally "tell another system what fields changed on these records, including deletes and history" — which is INT-19 verbatim.

---

## 6. Callouts — declarative *and* programmatic (the 10% objective)

The rubric explicitly wants both, so we show both and say when to use each.

| | **Declarative** | **Programmatic (Apex)** |
| --- | --- | --- |
| Tools | **Flow HTTP Callout**, External Services (OpenAPI → invocable actions), Outbound Message | Apex callouts (`HttpRequest`), **Continuation** (async, long-running), `@future`/Queueable callouts |
| Strengths | No code, admin-maintainable, fast to stand up, governed | Full control: aggregation, looping, retry/idempotency, complex error handling, long-running via Continuation |
| When | Simple, stable request-reply; admin owns it (e.g., a single agency lookup, a status check) | Fan-out + aggregation + partial retry (INT-06), anything needing custom logic/transformation |
| Bedrock use | **Flow HTTP Callout** as the low-code option for a straightforward credit-agency call or address validation | **Apex Continuation** for the ≤1-min, 30-concurrent credit-check orchestration (INT-06) so threads aren't held |

**Continuation matters here:** at 30 concurrent reps × up to 60s, synchronous callouts would risk the concurrent long-running request limit. Continuation issues the callout asynchronously and resumes when the response arrives — the right programmatic tool for slow request-reply.

---

## 7. Integration security (the 5% objective, woven through every interface)

| Concern | Approach in Bedrock |
| --- | --- |
| **Transport** | **Mutual TLS (two-way SSL)** on **all** interfaces (explicit requirement) — client + server certificates; enforced centrally at MuleSoft and via Named Credentials |
| **Outbound auth (SF → external)** | **Named Credentials + External Credentials**; **OpenID Connect / OAuth 2.0** to credit agencies (INT-06); per-system credentials at Mule (INT-07/13) — **no secrets in code** |
| **Inbound auth (external → SF)** | **OAuth 2.0** (client-credentials for server-to-server like the Drupal form; **Authorization Code/PKCE** for end-user and mobile) |
| **End-user, not API user** (INT-09) | Drupal/mobile call Experience Cloud **with the end-user's token**, honoring per-user **sharing & FLS** — meets the BFS security mandate |
| **Data protection** | **Shield Platform Encryption** for PII at rest; **exclude PII** from the data-lake CDC stream (INT-19); field-level filtering in Mule |
| **Least privilege** | Scoped connected apps, permission sets, IP/login restrictions; integration identities limited to required objects/fields |
| **Monitoring/governance** | Central policy enforcement, threat protection, and audit at **MuleSoft API Manager** + Event Monitoring in Salesforce |

---

## 8. Error handling per pattern (the 5% objective)

| Pattern | Error-handling strategy | Bedrock example |
| --- | --- | --- |
| **Request & Reply** | Return the error synchronously to the user; **idempotent resubmit**; retry only failures | INT-06 credit checks — "Agency XYZ unavailable", resubmit re-runs only failed agencies |
| **Fire & Forget** | Event **retry** + **dead-letter queue**; surface failures to an **admin error queue** for manual correct-and-retry | INT-07/13 fan-out; the scenario's "errors queued for an Administrator to correct and retry" |
| **Batch Data Sync** | Job-level + **per-row error capture**; reprocess only failed rows; reconciliation report | INT-03 call-list load, INT-18 migration |
| **UI Update / Streaming** | Client **resubscribe** + **replay from last `replayId`**; gap detection | INT-05 manager screen |
| **Data Virtualization** | Source-down → **graceful message / cached read**; **circuit breaker** + timeout at Mule | INT-11 transaction history |
| **CDC** | **Replay by `replayId`**; monitor the ~3-day retention; idempotent lake writes; gap alerts | INT-19 data lake |

**The "admin error queue" requirement** is satisfied by MuleSoft DLQ/reprocessing **plus** a Salesforce **Integration_Error__c** custom object (or Big Object for volume) that an admin works from a console — failed events are never silently lost.

---

## 9. Why MuleSoft / Anypoint — and why the license spend is justified

The scenario contains several requirements that, taken together, make a point-to-point native approach the *wrong* answer and an **API-led middleware backbone the right one**. MuleSoft is a **Salesforce company / product**, so it is the natural, well-integrated choice (unified support, Anypoint + Salesforce connectors, **MuleSoft Composer** for clicks-not-code citizen integration, and the **MuleSoft Direct / Salesforce integration** tooling).

**Requirements that *explicitly* demand middleware capabilities:**

| Scenario requirement | Native point-to-point | MuleSoft Anypoint |
| --- | --- | --- |
| "all integrations can be **centrally monitored**" | No single pane — each callout/flow monitored separately | **Anypoint Monitoring / Visualizer** — one dashboard across all interfaces |
| "**library of connection templates** … reusable integration assets … faster GTM" | Rebuilt per integration | **Anypoint Exchange** + **API-led (System/Process/Experience APIs)** — publish once, reuse everywhere |
| "integration **errors queued for an Administrator** to correct and retry" | Hand-built per interface | Built-in **DLQ / reprocessing** + alerting |
| "**Mutual Authentication** for **all** interfaces" | Configured/maintained per endpoint | Centrally enforced **mTLS + security policies** at **API Manager** |
| Credit checks: **≥3 agencies, extensible, partial retry** (INT-06) | Apex must hand-roll fan-out/aggregation/retry; new agency = code + deploy | Fan-out/aggregate in one Process API; **new agency = config**, no SF change |
| **Millions of events/day** (INT-17), **bi-directional RockStar sync** (INT-18) | SF absorbs orchestration + conflict logic + load | Offloaded to Mule; protects **Salesforce governor/callout limits** |

**The license-cost justification (say this to the EA group):**
- **Reuse & GTM speed:** API-led design turns N×(N-1) brittle point-to-point links into a **reusable hub-and-spoke**; each new channel/agency/system is configuration against an existing System API, not a new custom build — directly delivering the requested "reusable integration assets" and "faster go-to-market."
- **Lower total cost of ownership:** less bespoke Apex to write, test, and maintain; fewer governor-limit firefights; one place to monitor, secure, and retry — fewer production incidents in a **regulated financial-services** context.
- **Risk & compliance:** centralized mTLS, OAuth/OIDC policy, PII filtering, audit, and DLQ are **audit-friendly** and consistent — hard to achieve uniformly across dozens of native point-to-point integrations.
- **Decoupling & resilience:** Salesforce stays the system of engagement; Mule absorbs downstream outages (retry/DLQ) and high volume (INT-17/18) so the CRM experience stays fast.
- **Salesforce-native:** as a Salesforce product, Anypoint avoids a foreign tech stack; **MuleSoft Composer** lets admins build simpler flows declaratively, widening who can integrate.

**Where native is still fine (balance):** the on-page map (INT-04) is pure UI; the loan-app atomic write (INT-15) is a direct Composite API call from the portal/Mule; CDC (INT-19) could in principle be consumed directly off the Pub/Sub API. We route them through Mule **only** where monitoring/templates/error-queue/security uniformity add value — we don't add hops for their own sake.

---

## 10. Key assumptions

- Bedrock has (or will license) **MuleSoft Anypoint Platform**; integration identities and certificates are provisioned by the EA group.
- The **Customer Master (Hadoop)** offers both real-time and batch interfaces (stated); the **Position Master** exposes a callable API for near-real-time reads/writes.
- Core banking exposes **OData** for transaction history (stated) and can sit behind a Mule cache.
- Credit agencies expose **REST + OpenID Connect** (stated) and accept a correlation Id for idempotent retries.
- The **Enterprise Data Lake** can subscribe to a stream (Pub/Sub API) or accept Mule-pushed deltas; PII field list is agreed with governance.
- Volumes per the brief: 5M customers, ~100M transactions/day, peak >100k history calls/hr, millions of loan events/day.
- Salesforce remains master for Chatter, Opportunities, Leads, Cases; **no Communities UI** is used (headless Experience Cloud only).

---

## 11. Mapping to the 5 presentation slides

| Slide | Content | Rubric objectives covered |
| --- | --- | --- |
| **1. Problem Statement** | BFS landscape, master-data problem, volumes, the integration challenges | Identify requirements (5%) |
| **2. Solution Architecture + Assumptions** | API-led / MuleSoft context diagram (SF, Marketing Cloud, Drupal, Experience Cloud, agencies, core banking, masters, data lake) + key assumptions | Articulate design (5%), leverage platform (10%) |
| **3. Interface List** | The INT-01…INT-19 table: pattern + API + security + error handling | **Patterns (20%)**, **APIs (15%)**, **event-driven (10%)**, **callouts (10%)**, **virtualization (10%)** |
| **4. Integration Security** | mTLS everywhere, OIDC/OAuth, end-user (no API user), PII handling, Named Credentials, central policy | Security (5%) |
| **5. Summary + Trade-offs** | MuleSoft license justification, virtualize-vs-replicate, sync-vs-async, Platform Events-vs-CDC; quantified outcomes | Trade-offs (5%), error handling (5%) |


