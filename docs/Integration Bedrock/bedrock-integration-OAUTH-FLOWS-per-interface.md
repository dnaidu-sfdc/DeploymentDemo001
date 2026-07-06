# Bedrock Integration — The Exact OAuth Flow for Every Interface

> "OAuth 2.0" is not an answer a judge accepts — **the grant type is the design decision.** This doc
> names the **specific OAuth flow for every INT that authenticates**, and — more importantly — gives
> the **rule that produces it**, so you can defend any interface on the spot.
>
> Companion to the SLIDES (Interface List + Security), the DEFENSE-BRIEF, and the REQ-to-SOLUTION doc.

---

## The rule that decides the flow (memorize this)

Every choice comes from **two questions**:

1. **Is a human present at the moment of the call?**
2. **Who initiates the call — an external system into Salesforce, or Salesforce out to a system?**

That yields exactly **four** flows across the whole solution:

| If… | Use this flow | Why |
|---|---|---|
| **A human is present** (customer/rep in a browser or app) calling **into** Salesforce | **OAuth 2.0 Authorization Code** — **+ PKCE** for mobile/public clients | Runs in the **user's** context → sharing & FLS enforced ("no API user"). PKCE protects a public client that can't keep a secret. |
| **No human**, an **external system** calls **into** Salesforce | **OAuth 2.0 JWT Bearer** (certificate-based) | Machine identity proven by a **signed JWT** — no secret in transit, no browser, mTLS-friendly. Preferred in a regulated bank. |
| **No human**, **Salesforce calls out** to an external machine API | **OAuth 2.0 Client Credentials** (as an **External Credential** on a **Named Credential**) | Salesforce is the client; a client-id/secret (or JWT) obtained per service; secrets stay in the Named Credential, never in code. |
| A rep **embeds** an external app in the console | **Canvas Signed Request** (primary) — or Canvas's **OAuth Authorization Code** method | Carries the rep's identity into the embedded app without a re-login (no swivel). |

> **One-liner for the judge:** *"Human in a browser → Authorization Code, plus PKCE on mobile.
> System-to-system into Salesforce → JWT Bearer. Salesforce calling out → Client Credentials via a
> Named Credential. Embedded UI → Canvas signed request. The flow follows from 'is a person present,
> and who starts the call.'"*

**JWT Bearer vs. Client Credentials for inbound system calls** (the follow-up a sharp judge asks):
both are valid for system→Salesforce. **JWT Bearer is the default here** because the client proves
itself with a **private key / certificate** — **no shared secret crosses the wire**, which pairs
naturally with the mandated **mTLS** and suits a regulated FS context. **Client Credentials** is the
acceptable alternative when you'd rather run as a designated **integration ("run-as") user** and are
comfortable storing a client secret. Either way it is a **scoped, per-integration identity** — *not*
the forbidden shared "API user" (that ban is about **customer-facing** access running as a real
customer; see INT09/INT12).

---

## The per-interface table (all 16)

| INT | Source → Target | Human present? | **OAuth flow** | Where it's configured / notes |
|---|---|---|---|---|
| **INT01** | Marketing Cloud → SF (publish Platform Event, via MuleSoft) | No | **JWT Bearer** | MuleSoft authenticates into SF with a cert-backed Connected App to publish the PE |
| **INT02** | Drupal form → SF (Lead capture) | No — anonymous prospect | **JWT Bearer** (tightly-scoped integration identity) | No customer identity exists yet, so it runs as a **create-Lead-only** scoped Connected App — legitimately *not* an end-user call |
| **INT03** | Business Rules Engine → SF (Bulk API 2.0 upsert) | No | **JWT Bearer** | Cert-backed Connected App; scoped to the call-list objects |
| **INT04** | SF → Mapping service (Flow HTTP Callout) | No — SF is the client | **Client Credentials** *(External Credential on a Named Credential)* — or an API key if that's all the map API offers | Secret/cert lives in the Named Credential, never in the Flow |
| **INT05** | SF → Manager dashboard (CDC/PE via Pub-Sub) | Manager: yes (in SF) / external subscriber: no | Manager's browser uses the **existing Salesforce session** (no separate grant); an **external** Pub-Sub subscriber uses **JWT Bearer** | empApi in the manager's page rides their session |
| **INT06** | SF ↔ Credit Agencies (via MuleSoft) | No | **SF → MuleSoft: Client Credentials** (Named Credential). **MuleSoft → each agency: Client Credentials + OpenID Connect** | Two hops, two configs; agencies authenticated with OIDC as the doc specifies |
| **INT07** | SF → Customer/Position Master (publish PE; MuleSoft subscribes) | No | **JWT Bearer** (MuleSoft subscribing to the SF event bus) | Fan-out to Hadoop/Position Master then uses those systems' own auth |
| **INT08** | Customer Master → SF (provision Experience Cloud user, REST) | No | **JWT Bearer** | Cert-backed Connected App scoped to user provisioning |
| **INT09** | Drupal / Mobile → Experience Cloud (contact info, Cases) | **Yes — the customer** | **Web (Drupal, server-side): Authorization Code. Mobile app (public client): Authorization Code + PKCE** | The "no API user" interface: runs in the **customer's** context, sharing/FLS enforced. Headless — no Communities UI |
| **INT10** | SF Connect → OData source (via MuleSoft) → Core Banking | No — system / named principal | SF Connect external data source: **Named Principal + OAuth 2.0 Client Credentials** (one system identity for high volume; **not** per-user). MuleSoft → core banking uses the bank's auth | Per-user identity type is possible but wrong for a 100k+/hr shared read; **High Data Volume** is enabled (see the transaction-history deep-dive) |
| **INT11** | SF → Customer Master (PE/CDC; MuleSoft subscribes) | No | **JWT Bearer** | Same event-bus subscription model as INT07 |
| **INT12** | Portal → SF (loan application, Composite `allOrNone`) | **Yes — the customer** | **Web: Authorization Code. Mobile: Authorization Code + PKCE** | Same end-user model as INT09 — the loan is submitted **as the customer** |
| **INT13** | SF → External Trading System (Canvas embed) | Rep present | **Canvas Signed Request** (primary) — or Canvas **OAuth Authorization Code** method | Carries the rep's identity into the embedded app; no re-login = "no swivel" |
| **INT14** | SF → consumers (High-Volume PE / Pub-Sub, millions/day) | No | **JWT Bearer** (each external subscriber) | Cert-backed, scoped, replay-capable |
| **INT15** | RockStar ↔ SF (Bulk migration + CDC + remote call-in) | No | **JWT Bearer** on every hop (Bulk load in, CDC subscribe, call-in) | One cert-backed integration identity for the migration/sync backbone |
| **INT16** | SF → Enterprise Data Lake (CDC via Pub-Sub) | No | **JWT Bearer** (MuleSoft subscribing to CDC) | Then streamed to the Data Lake with the lake's own auth; PII filtered in MuleSoft |

---

## Grouped the way you'll say it out loud

**🧑 Authorization Code (a human is present) — runs in the user's context, sharing/FLS enforced:**
- **INT09** — customer self-service (web = Authorization Code, **mobile = + PKCE**)
- **INT12** — loan application (same; submitted **as the customer**)
- **INT13** — rep console embed (**Canvas signed request**, or Canvas OAuth Authorization Code)

**🤖 JWT Bearer (system → Salesforce, no human) — certificate-based, no secret in transit:**
- **INT01, INT02, INT03, INT07, INT08, INT11, INT14, INT15, INT16** (and any external Pub-Sub
  subscriber in **INT05**)

**📤 Client Credentials (Salesforce → external machine API, via Named Credential):**
- **INT04** (map service), **INT06** (SF → MuleSoft; MuleSoft → agencies adds **OIDC**),
  **INT10** (Salesforce Connect named-principal to the OData/MuleSoft endpoint)

**🖥️ Existing Salesforce session (no separate OAuth grant):**
- **INT05** manager dashboard (empApi rides the logged-in manager's session)

---

## Why not the other flows (the rejections that earn the trade-off marks)

- **Why not username-password (Resource Owner Password) anywhere?** It stores/handles a password, is
  incompatible with MFA, and Salesforce is actively retiring it — never use it for system or user auth.
- **Why not Authorization Code *without* PKCE on mobile (INT09/INT12)?** A mobile app is a **public
  client** that can't keep a secret; without PKCE an intercepted authorization code can be redeemed by
  an attacker. PKCE binds the code to the app instance that started the flow.
- **Why not Authorization Code for the system integrations (INT01/03/07/…)?** There is **no human and
  no browser** to complete a redirect or consent — Authorization Code is the wrong tool. JWT Bearer is
  the machine-identity flow.
- **Why not JWT Bearer for the customer portal (INT09/INT12)?** That would run as a system identity and
  **defeat the "no API user" mandate** — the whole point is that the call runs as the **actual
  customer** so per-record sharing applies.
- **Why not Implicit grant?** Deprecated; returns tokens in the browser redirect with weaker
  protection. Authorization Code (+ PKCE) supersedes it.

---

## The 30-second summary

> "There are only four flows in the whole design, and each one is forced by *who's calling*. Customers
> and reps in a browser or app authenticate with **Authorization Code** — **plus PKCE on mobile** —
> so every call runs **as that person** and sharing/FLS are enforced; that's how we satisfy 'no API
> user' on INT09 and INT12. Every system-to-system call **into** Salesforce — the events, the Bulk
> loads, the provisioning, the CDC subscriptions — uses **JWT Bearer**, certificate-based so **no
> secret ever crosses the wire**, which pairs with our mTLS. When **Salesforce calls out** — the map
> service, the credit-agency hop, the OData source — it uses **Client Credentials** via a **Named
> Credential** so secrets stay in the vault. And the trading-desk embed uses a **Canvas signed
> request**. Four flows, each chosen by whether a person is present and who starts the call."
