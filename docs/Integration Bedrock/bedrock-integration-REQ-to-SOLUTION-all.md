# Bedrock Integration — Every Requirement → Its Solution

> The complete walk-through: **each requirement, stated plainly, followed by the solution** — the
> interface, the integration pattern, the Salesforce API, *why it's the right choice, and why the
> obvious alternatives don't work.* This is the document to study to defend every decision.
>
> Companion to the SLIDES, the DEFENSE-BRIEF, the plain-English EXPLAINED doc, and the deep-dive on
> customer transactions (`bedrock-integration-REQ-to-INTERFACE-customer-transactions.md`), which
> expands INT09/INT10 and the >100k/hr OData scale defense in full.

---

## How to read this

Each entry has the same four parts:

- **📋 Requirement** — what the scenario asks for, in its own terms.
- **✅ Solution** — the interface (INTxx), the pattern, and the Salesforce implementation.
- **💡 Why this works** — the reasoning that earns the marks.
- **❌ Why not the alternatives** — the options considered and rejected (this is the 5% trade-offs
  score, and it's what a judge probes).

The scenario has **three customer journeys** plus a set of **cross-cutting enterprise mandates**.
That's the structure below.

### Master map — requirement → interface → pattern

| # | Requirement (short) | INT | Pattern | Salesforce API |
|---|---|---|---|---|
| **Journey 1 — Marketing & Campaigns** |||||
| 1 | Qualified leads from Marketing Cloud, team swarms them fast | INT01 | Fire-and-Forget (event) | Platform Event / Pub-Sub |
| 2 | Prospect capture from the marketing website form | INT02 | Remote Call-In | REST (Lead) |
| 3 | Daily prioritized call lists (currently slow, SLA at risk) | INT03 | Batch Data Sync | Bulk API 2.0 |
| 4 | Show the call list on a map, nearest office | INT04 | UI mashup / Request-Reply | Flow HTTP Callout |
| 5 | Managers see a live update the moment a high-value call closes | INT05 | UI Update on Data Change | CDC/PE + Pub-Sub |
| **Journey 2 — Conversion & Registration** |||||
| 6 | Credit check across 3+ agencies, compare, ≤1 min, expandable | INT06 | Remote Process Invocation — Request & Reply | Apex Continuation → MuleSoft |
| 7 | Propagate a newly registered customer to the master systems | INT07 | Fire-and-Forget (event) | Platform Event |
| 8 | Provision + activate the portal user, send welcome invite | INT08 | Remote Call-In | Connect/REST API |
| **Journey 3 — Customer Management (self-service)** |||||
| 9 | Retrieve/update contact info; raise an inquiry | INT09 | Remote Call-In (end-user auth) | Experience Cloud + REST/UI API, OAuth |
| 10 | Balances / transaction history at >100k/hr | INT10 | Data Virtualization | Salesforce Connect + OData + Mule cache |
| 12 | Loan application (form + children + docs), all-or-nothing | INT12 | Remote Call-In (transactional) | Composite API `allOrNone=true` |
| 13 | Use the external trading system without swivel-chair; auto-log | INT13 | UI integration | Salesforce Canvas |
| **Cross-cutting enterprise mandates** |||||
| 11 | Customer profile edits propagate back to the master | INT11 | Fire-and-Forget (event) | Platform Event / CDC |
| 14 | Loan-processing lifecycle events at millions/day | INT14 | Fire-and-Forget (high volume) | High-Volume Platform Events |
| 15 | Migrate off RockStar + 3-month bi-directional sync | INT15 | Batch migration + bi-di sync | Bulk API + CDC/Batch |
| 16 | Feed the Data Lake a non-PII, changed-fields, full-history delta | INT16 | Change Data Capture | CDC → Pub-Sub |
| — | Mutual authentication on **all** interfaces | all | — | mTLS + Named Credentials |
| — | End-user (not API user) auth for portal/mobile | INT09/12 | — | OAuth 2.0 authorization-code |
| — | Central monitoring + reusable integration assets | all | — | MuleSoft Anypoint / API-led |
| — | Integration errors queued for an admin to fix & retry | all | — | MuleSoft DLQ / error-hospital |

---

# JOURNEY 1 — Marketing & Campaigns

## INT01 — Qualified leads from Marketing Cloud

**📋 Requirement.** When Marketing Cloud identifies a **qualified lead**, it must land in Salesforce
**near-real-time** so a team can **"swarm"** it immediately. Campaign bursts must not break anything.

**✅ Solution.** **Fire-and-Forget** via a **Platform Event** published through MuleSoft; Salesforce
subscribers react and the UI is notified via **Pub-Sub API / empApi**.

**💡 Why this works.** A qualified lead is a **notification that something happened**, not a request
that needs an answer. Publishing an event **decouples** Marketing Cloud from Salesforce's processing —
a campaign spike queues as events and is absorbed, rather than blocking Marketing Cloud. Multiple
subscribers (assignment, notification, the swarm UI) can react independently.

**❌ Why not the alternatives.**
- **Synchronous REST call from Marketing Cloud** — couples the two systems; a slow Salesforce or a
  burst makes Marketing Cloud wait or fail. Tight coupling is exactly what events avoid.
- **Polling** ("check for new leads every minute") — adds latency and wastes calls; not "near-real-time."

---

## INT02 — Prospect capture from the marketing website

**📋 Requirement.** The marketing **website (Drupal)** has a form where prospects submit their details;
these must become **Leads** in Salesforce. Volume is modest (hundreds, growing to low thousands).

**✅ Solution.** **Remote Call-In** — a simple synchronous **REST API** insert of a Lead, exposed
through the MuleSoft Experience API.

**💡 Why this works.** One user submitting one record is the textbook case for a plain REST create.
It's simple, immediate, and the volume never justifies anything heavier.

**❌ Why not the alternatives.**
- **Bulk API** — built for thousands-to-millions of records per batch; pure overkill for single
  form submissions.
- **Platform Event** — there's no decoupling or multi-consumer benefit for a single user-submitted
  record; an event would add complexity for nothing.

---

## INT03 — Daily prioritized call lists (the SLA problem)

**📋 Requirement.** Each day, reps need a **prioritized call list** built from complex demographic /
geographic / availability rules. Today this processing **takes longer and longer and is threatening
the SLA.** Fix the slowness.

**✅ Solution.** **Batch Data Synchronization** — keep the **business-rules-engine compute
off-platform** (it already exists) and **Bulk API 2.0**-load the finished, prioritized lists into
Salesforce on a daily schedule.

**💡 Why this works.** The root cause is a **compute problem, not an engagement problem.** Heavy rule
evaluation inside Salesforce (Apex) runs into **governor limits** — that's *why* it's slow. Move the
grinding to the off-platform engine that's purpose-built for it, and let Salesforce do what it's good
at: **display and act on** the finished lists. Bulk API 2.0 is engineered for high-volume scheduled
upserts. This removes the SLA risk **at its source.**

**❌ Why not the alternatives.**
- **Do the compute in Apex batch on-platform** — this *is* the current problem; governor limits and
  processing time are the cause of the SLA breach.
- **Row-by-row REST load** — far too slow for the volume of a daily list refresh.

---

## INT04 — Call list on a map

**📋 Requirement.** Reps want to see their call list **plotted on a map**, with the **nearest office /
branch** shown. Nothing needs to be stored.

**✅ Solution.** **UI mashup / Request-Reply** — a **declarative Flow HTTP Callout** (or an LWC calling
a mapping API through a **Named Credential**) that geocodes and returns the map on demand.

**💡 Why this works.** It's a **stateless, read-only, user-facing** lookup — the lightest possible
tool is correct. A **declarative** callout also demonstrates the "declarative vs. Apex callout"
knowledge the rubric rewards (contrast with INT06 below).

**❌ Why not the alternatives.**
- **Store/persist geocodes in Salesforce** — an unnecessary copy of data that's only needed
  momentarily on screen.
- **Apex callout** — works, but it's heavier than needed; reserve Apex for when logic or scale
  actually require it (which INT06 does, and INT04 doesn't).

---

## INT05 — Live manager update when a high-value call closes

**📋 Requirement.** The **moment** a rep closes a **high-value call**, the **manager's dashboard** must
reflect it — live, no manual refresh.

**✅ Solution.** **UI Update on Data Change** — **CDC** (or a Platform Event) on the relevant record,
streamed to the manager's screen via the **Pub-Sub API / empApi**.

**💡 Why this works.** "The moment it happens" = **push on a data change**, not polling. CDC fires on
the record change and streams to subscribed dashboards with **zero polling load**.

**❌ Why not the alternatives.**
- **Page auto-refresh / polling** — latency and wasted server load; never truly "the moment."
- **Scheduled report refresh** — not real-time by definition.

---

# JOURNEY 2 — Conversion & Registration

## INT06 — Credit check across multiple agencies *(crown jewel)*

**📋 Requirement.** During conversion, run a **credit check across 3 or more agencies**, **compare**
the results, return within **~1 minute**, support up to **~30 concurrent** checks, be **easy to expand**
(add a new agency later), and if an agency is slow/down, **surface a per-agency error and retry only
the failed agency** — without losing the good results.

**✅ Solution.** **Remote Process Invocation — Request & Reply.** In Salesforce, an **Apex Continuation**
issues the long call **without holding a server thread**; **MuleSoft's Process API does the
scatter-gather** across all agencies in parallel and normalizes the responses; agency auth is
**OpenID Connect**. **Partial retry** re-invokes only the failed agencies (idempotent by correlation ID).

**💡 Why this works — four requirements, four mechanisms.**
- *Rep waits, ≤1 min* → synchronous Request & Reply.
- *~30 concurrent long calls* → **Apex Continuation** frees the thread during the wait, so 30 in-flight
  checks don't consume 30 held threads (which would breach concurrency limits).
- *3+ agencies compared, easy to add a 4th* → **MuleSoft scatter-gather** calls them in parallel
  (total wait ≈ the *slowest* agency, not the sum) and hides them behind one API, so **adding an
  agency is a MuleSoft-only change — zero Salesforce change.**
- *Retry only the failed agency* → MuleSoft tracks **per-agency status**; on resubmit it re-calls only
  the failures, keeping the successful scores.

**❌ Why not the alternatives.**
- **Synchronous Apex HTTP callout** — holds a server thread for up to 60s; **won't scale to 30
  concurrent** long calls (concurrency governor limits).
- **Call the 3 agencies directly from Apex** — tight coupling, no easy expansion, and you'd hand-build
  parallelism + per-agency retry in Apex.
- **Build the agency abstraction / retry logic in Apex** — that orchestration belongs in **middleware**;
  keeping it in MuleSoft is what makes "add an agency without touching Salesforce" true.

*(Full sequence in DEFENSE-BRIEF §D.1.)*

---

## INT07 — Propagate a newly registered customer to the masters

**📋 Requirement.** When a customer **registers**, the fact must **propagate to the master systems** —
the **Customer Master (Hadoop)** and the **Position Master** — near-real-time.

**✅ Solution.** **Fire-and-Forget** — publish one **Platform Event** ("customer registered");
**MuleSoft fans it out** to the Customer Master, Position Master, and any other consumer.

**💡 Why this works.** It's **one business event with multiple interested consumers.** Publish once,
let each consumer subscribe — the classic decoupled fan-out. New consumers can be added later without
touching the publisher.

**❌ Why not the alternatives.**
- **Multiple point-to-point callouts from Salesforce** — N couplings to maintain; every new consumer
  means a Salesforce change.
- **CDC** — this is a **business milestone with a purposeful payload**, not merely a record-field
  delta; a Platform Event carries the intended, curated message better than a raw change event.

---

## INT08 — Provision and activate the portal user

**📋 Requirement.** After registration, **create and activate an Experience Cloud (portal) user** and
send a **welcome invite** (with temporary credentials / guidance).

**✅ Solution.** **Remote Call-In** — the Customer Master triggers user creation + activation + invite
via the **Connect/REST API**. This can be **chained off the INT07 event.**

**💡 Why this works.** Provisioning is a **discrete, single-record action** initiated by an external
trigger — a straightforward remote call-in. Chaining it off INT07's event keeps the registration flow
decoupled and event-driven end to end.

**❌ Why not the alternatives.**
- **Manual admin provisioning** — doesn't scale to 5M customers.
- **Bulk API** — this is one user at a time, not a batch.

---

# JOURNEY 3 — Customer Management (self-service)

> INT09 and INT10 are covered in depth (with the full >100k/hr OData scale defense) in
> `bedrock-integration-REQ-to-INTERFACE-customer-transactions.md`. Summarized here for completeness.

## INT09 — Retrieve/update contact info; raise an inquiry

**📋 Requirement.** Through the **headless Drupal site and mobile app**, customers must **retrieve and
update** their contact info (address, phone, etc.) and **raise an inquiry**. Access must be
**end-user authenticated — not a shared API user** — and the Communities UI is **not** used.

**✅ Solution.** **Remote Call-In** to **Experience Cloud** via **REST/Connect/UI API**, with customers
signed in through **OAuth 2.0 authorization-code**. "Raise an inquiry" creates a **Case**.

**💡 Why this works.** The data lives **in Salesforce**, so these are ordinary reads/writes. Running
every call **in the customer's own user context** means Salesforce's **sharing rules and field-level
security apply per person** — a customer can only ever see/edit their own record. This directly
satisfies the security team's **"no API user"** mandate. "Headless" = Experience Cloud provides the
security/data layer while Drupal/mobile own the UI.

**❌ Why not the alternatives.**
- **Shared integration/API user** — explicitly forbidden; it would bypass per-user security and wreck
  auditability.
- **Standard Communities LWR UI** — the requirement says the Salesforce-hosted UI is not used.

---

## INT10 — Balances / transaction history at scale *(crown jewel — the scale defense)*

**📋 Requirement.** Customers retrieve **balances and transaction history**, which live in the **core
banking system** and are exposed via an **OData connector.** Within a couple of years — especially at
**holiday peaks** — this will exceed **100,000 calls/hour**, and it must **perform seamlessly.**

**✅ Solution.** **Data Virtualization — Salesforce Connect + OData** for the live, no-copy view
**inside Salesforce** (rep/service console, low volume), **plus a cached MuleSoft Experience API** that
the customer portal/mobile call **directly** for the high-volume traffic.

**💡 Why this works — the crux.** Salesforce Connect's OData adapter is **capped (~20,000 callouts/hr
default, ~100,000/hr maximum)**, and **a cache behind the adapter does not reduce that count** —
External Objects store nothing, so **every** read is a metered callout. So there are **two separate
bottlenecks**, each with its own fix:
- **The adapter limit** → **don't route customer volume through External Objects at all**; the portal
  hits a **MuleSoft Experience API directly**, which never touches the Salesforce Connect limit.
- **Core banking itself** → **short-TTL cache + rate-limiting + circuit breaker** in MuleSoft absorbs
  the spike so the backend sees a smooth trickle.

External Objects then serve only the **low-volume in-org view** (well under 20,000/hr), which is where
Data Virtualization genuinely shines. **No copy of 100M txns/day; live data; seamless under load.**

**❌ Why not the alternatives.**
- **Copy transaction history into Salesforce** — billions of rows, huge storage, always stale, and
  duplicates a system of record Salesforce doesn't own.
- **Nightly ETL** — up to 24h stale; solves the wrong problem (freshness, not live concurrency).
- **All reads via External Objects (no split)** — hard-capped at 20,000/hr (max ~100,000), **below**
  the requirement with **no headroom**, and hammers core banking directly.
- **Just ask for a limit increase** — even the max has no holiday headroom and doesn't protect core
  banking.

*(Numbers, worked 120k/hr example, and full rebuttals in the customer-transactions deep-dive.)*

---

## INT12 — Loan application, all-or-nothing *(crown jewel)*

**📋 Requirement.** A customer submits a **loan application** made of a **parent record + several child
records + uploaded documents.** It must **never be half-saved** — either the whole thing commits or
nothing does.

**✅ Solution.** **Remote Call-In (transactional)** — **Composite API with `allOrNone=true`** (or a
Composite Graph) commits the parent, all children, and the document (**ContentVersion**) inserts in
**one transaction.**

**💡 Why this works.** `allOrNone=true` guarantees **atomicity**: if any single sub-request fails, the
**entire set rolls back** and nothing is saved. The customer can never end up with an orphaned partial
loan (e.g., an application with missing documents).

**❌ Why not the alternatives.**
- **Sequential REST calls** (insert parent, then children, then docs) — a failure midway leaves
  **partial commits** — exactly the outcome the requirement forbids.
- **Bulk API** — has no **cross-object transactional atomicity**; it's for volume, not all-or-none
  integrity.

*(Full sequence in DEFENSE-BRIEF §D.3.)*

---

## INT13 — External trading system without swivel-chair

**📋 Requirement.** Reps must **use an external trading system without "swiveling"** to another app,
and their **interactions should be logged automatically** in Salesforce.

**✅ Solution.** **UI integration** — **Salesforce Canvas** (with **signed-request SSO**) embeds the
external trading app **inside the Salesforce console**; an action **logs the interaction** to a
Salesforce object.

**💡 Why this works.** Canvas embeds the external screen **in place** — no separate login, no tab
switching (the "no swivel" requirement). Signed-request SSO carries the identity so the rep isn't
re-authenticating. Capturing the interaction to a Salesforce object improves handle time and gives a
unified activity history.

**❌ Why not the alternatives.**
- **Plain iframe without SSO** — the rep has to log in again = a swivel by another name.
- **Rebuild the trading flows natively in Salesforce** — enormous effort and defeats the goal of
  *leveraging the existing* system.

---

# CROSS-CUTTING ENTERPRISE MANDATES

## INT11 — Profile edits propagate back to the master

**📋 Requirement.** When a customer **edits their profile** (via INT09), those **updates must propagate
to the Customer Master** so the master stays authoritative — near-real-time.

**✅ Solution.** **Fire-and-Forget** — a **Platform Event** (or **CDC** on Contact/Account) → MuleSoft →
Hadoop Customer Master.

**💡 Why this works.** Decouples the customer's save action from the master's availability — the portal
save succeeds immediately and the propagation happens asynchronously and reliably.

**❌ Why not the alternatives.**
- **Synchronous write-through to Hadoop** — couples the portal save to the master's uptime; if Hadoop
  is briefly unavailable, the customer's save fails. Async decoupling avoids that.

---

## INT14 — Loan-processing events at millions/day

**📋 Requirement.** The loan-processing domain emits **millions of lifecycle events per day** that
downstream consumers need — **large-scale, asynchronous**, and recoverable.

**✅ Solution.** **Fire-and-Forget at high volume** — **High-Volume Platform Events** via the
**Pub-Sub API**; consumers use **replay IDs** to recover.

**💡 Why this works.** High-Volume Platform Events are **engineered for exactly this scale** of
asynchronous throughput, and replay IDs let a consumer that fell behind **resume without gaps.**

**❌ Why not the alternatives.**
- **CDC** — tied to record changes with less control over payload/volume semantics; High-Volume PE is
  the purpose-built tool for millions of business events/day.
- **Synchronous delivery** — impossible at this scale; it would collapse under load.

---

## INT15 — RockStar migration + 3-month bi-directional sync

**📋 Requirement.** **Migrate off the legacy RockStar system** into Salesforce, but keep RockStar live
for **~3 months** as a fallback — during which a **few transactions still occur in RockStar** — so the
two must **stay in sync bi-directionally.** Then **decommission** RockStar.

**✅ Solution.** Two mechanisms: **(a)** a one-time **Bulk API 2.0** migration load; **(b)** a
**3-month bi-directional sync** — Salesforce→RockStar via **CDC**, RockStar→Salesforce via scheduled
batch / remote call-in through MuleSoft — governed by a **conflict-resolution policy**
(source-of-truth precedence or last-writer-wins with timestamps). Retire the interfaces at 3 months.

**💡 Why this works.** Bulk handles the heavy one-time load. Because activity **still happens on both
sides** during the transition, sync must be **two-way**, not one-way. Routing it through MuleSoft gives
**central monitoring and retry**; the explicit conflict policy handles the case where the same record
changes on both sides.

**❌ Why not the alternatives.**
- **One-directional migration only** — the requirement says transactions still occur in RockStar, so a
  one-way sync would lose them.
- **Custom point-to-point sync scripts** — no central monitoring or admin retry; use the backbone
  everything else already runs on.

---

## INT16 — Data Lake delta feed *(crown jewel)*

**📋 Requirement.** Feed the **Enterprise Data Lake** a delta of Salesforce changes with four specifics:
capture **inserts, updates, and deletes**; keep the **full history of changes** (not just the latest
state); sync **only the changed fields**; and include **non-PII data only.**

**✅ Solution.** **Change Data Capture** — CDC change events → **Pub-Sub API** → **MuleSoft (PII
filter)** → Data Lake, which **appends** each event.

**💡 Why this works.** The requirement is a **literal description of what CDC does natively**: it emits
**only changed fields + the change type**, for **every** insert/update/delete. If the consumer
**appends** each event, the **full history is preserved** for free. MuleSoft strips PII on the way
through, and a **Replay ID** lets the consumer resume after downtime with **no gaps.**

**❌ Why not the alternatives.**
- **Nightly Bulk export** — loses intermediate history (only sees the end-of-day state), sends **all**
  fields rather than just changed ones, and can't cleanly express **deletes.**
- **Custom triggers writing an audit table, then ETL** — reinvents, badly, exactly what CDC already
  provides.

*(Full sequence in DEFENSE-BRIEF §D.2.)*

---

## Cross-cutting: mutual authentication on every interface

**📋 Requirement.** **All** interfaces must use **mutual authentication.**

**✅ Solution.** **Two-way TLS (mTLS)** terminated at the **Anypoint gateway in the DMZ** — both sides
present certificates. **Salesforce-initiated** callouts use **Named Credentials configured with client
certificates.** **OAuth 2.0 / OpenID Connect** sits on top for identity.

**💡 Why this works.** mTLS proves **both** ends of every channel; OAuth/OIDC then proves **identity**.
Terminating mTLS once at the gateway means the mandate is enforced **centrally and consistently**,
not re-implemented per integration.

**❌ Why not the alternatives.**
- **One-way TLS + API key** — proves only the server and relies on a shared secret; not mutual auth.
- **Per-integration bespoke auth** — inconsistent, hard to audit; centralize at the gateway.

---

## Cross-cutting: central monitoring + reusable integration assets

**📋 Requirement.** The enterprise wants **central monitoring** of all integrations and a **library of
reusable integration assets / connection templates** to speed future delivery.

**✅ Solution.** **MuleSoft Anypoint** as the backbone, organized **API-led** (System / Process /
Experience APIs published in Anypoint Exchange), with **Anypoint Monitoring / API Manager.**

**💡 Why this works.** A single backbone gives **one place** to monitor every flow, and the API-led
layering makes each connection a **reusable, cataloged asset** — new integrations compose existing
System/Process APIs instead of starting from scratch. These two requirements are, by definition,
**middleware capabilities**, which is the core justification for MuleSoft in this design.

**❌ Why not the alternatives.**
- **Point-to-point integrations with no middleware** — no central monitoring, nothing reusable,
  spaghetti that grows with every new system.
- *(Note: the patterns themselves stay native to Salesforce — MuleSoft is the conduit and governance
  layer, not a replacement for platform features. If the EA group standardizes on a different iPaaS,
  the patterns are unchanged.)*

---

## Cross-cutting: admin error-retry queue

**📋 Requirement.** **Integration errors must be queued for an administrator to correct and retry.**

**✅ Solution.** A **central DLQ / "error hospital"** in MuleSoft (Anypoint) with an **admin console** —
failed events/messages are **parked, inspectable, correctable, and replayable.** Each pattern also has
its own recovery (see DEFENSE-BRIEF §C): PE/CDC **replay IDs**, Bulk **failed-row requeue**, Composite
**automatic rollback**.

**💡 Why this works.** Centralizing failures gives admins **one place** to triage and resubmit, exactly
as the requirement states — nothing is silently lost, and poison messages don't block the pipeline.

**❌ Why not the alternatives.**
- **Log errors and move on** — no recovery path; violates the explicit "queue for admin retry" mandate.
- **Per-integration ad-hoc error handling** — inconsistent and unmonitorable; centralize it.

---

## The 60-second framing for the whole solution

> "Every interface is chosen by two questions — **who starts the conversation, and do we wait for a
> reply?** Where a **user waits**, it's synchronous request-reply (credit check INT06, profile INT09).
> Where systems should be **decoupled**, it's events (leads INT01, registration INT07, profile-sync
> INT11, loan-scale INT14, Data Lake INT16). Where **volume is huge and scheduled**, it's Bulk (call
> lists INT03, migration INT15). Where data **shouldn't be copied**, it's virtualization (transaction
> history INT10). Where the **UI itself is the integration**, it's a mashup or Canvas (map INT04,
> trading desk INT13). It all runs on **one MuleSoft backbone** — mTLS everywhere, end-user OAuth (no
> API user), and a central error-retry queue — because the customer explicitly asked for central
> monitoring, reusable assets, and admin-recoverable errors. The three I'd defend hardest are the
> crown jewels: **INT06** (Continuation + scatter-gather + partial retry), **INT12** (Composite
> all-or-none), and **INT16** (CDC for changed-fields + full history)."

---

*Every requirement now has a stated solution, a reason it works, and the alternatives it beats. Pair
this with the DEFENSE-BRIEF (per-pattern error handling + the three flow diagrams) and the
customer-transactions deep-dive (the >100k/hr OData scale defense) and you can defend any line the
judge points at.*
