# Bedrock Integration — Requirement → Interface Deep Dive
## Customer Transactions (INT09 & INT10), with the OData scale defense

> A holistic walk from **the written requirement** to **the interfaces that satisfy it**, and then a
> rigorous defense of the hard part: serving **>100,000 transaction-history calls/hour** through a
> Salesforce Connect / OData path that is itself **capped at 20,000 callouts/hour**. This is the
> question a sharp judge will push on — so this doc gives you the numbers, the architecture, and the
> reasons every other option fails.
>
> Companion to the SLIDES, the DEFENSE-BRIEF, and the plain-English EXPLAINED doc in this folder.

---

## 1. The requirement (verbatim)

> **The transactions that may be performed by customers include (not limited to):**
> - Retrieve account **address, phone, and other contact information**
> - **Update** address and phone number
> - Retrieve account **balances / transaction history.** The transaction information is held in their
>   **core banking system.** Transaction history is available via an **OData connector.** Considering
>   the growth rate of business, in a couple of years, especially during **holiday seasons**, Bedrock
>   Financial is expecting that the number of **transaction-history calls will cross > 100,000 per
>   hour.** Bedrock is looking for a strategy so that the system **performs seamlessly under such load.**
> - **Raise an inquiry**

Four customer actions. Three of them are ordinary Salesforce reads/writes. **One of them — transaction
history — is the hard one**, and it's hard for a reason most people miss (see §5).

---

## 2. Requirement → Interface map (the holistic view)

| Customer action | Where the data actually lives | Interface | Pattern | Runs as… |
|---|---|---|---|---|
| Retrieve contact info (address, phone, …) | **Inside Salesforce** (Account / Contact) | **INT09** | 📞 Remote Call-In (REST/Connect/UI API) | the **end-user** (OAuth auth-code) — sharing & FLS enforced |
| Update address / phone | **Inside Salesforce** | **INT09** | 📞 Remote Call-In (write) | the **end-user** |
| Raise an inquiry | **Inside Salesforce** (new **Case**) | **INT09** | 📞 Remote Call-In (create) | the **end-user** |
| Retrieve **balances / transaction history** | **Outside Salesforce** — the **core banking system**, exposed via **OData** | **INT10** | 📌 **Data Virtualization** (Salesforce Connect + OData) **+ MuleSoft cache/gateway** | see §5 |

**The one-line reason the split matters:** *If the data lives in Salesforce, you just read/write it as
the customer (INT09). If it lives in core banking, you must decide whether to copy it or view it live —
and at 100,000+/hour, that decision is the whole ballgame (INT10).*

---

## 3. INT09 — contact info + updates + inquiries (the straightforward three)

These three actions all touch **data that already lives in Salesforce**, so there is no external-system
scale problem here at all.

- **How:** The Drupal website and the mobile app call **Experience Cloud** via **REST / Connect / UI
  API** (headless — no Communities UI). This is the classic **Remote Call-In** pattern: an outside
  front-end calling *into* Salesforce.
- **Security (the point the bank's security team cares about):** every call runs **in the customer's
  own user context** via **OAuth 2.0 authorization-code** — *not* a shared "API user." That means
  Salesforce's **sharing rules and field-level security apply per person**: a customer can only ever
  see and edit **their own** record. (This is the explicit "no API user" mandate.)
- **Raise an inquiry** = create a **Case** through the same authenticated path.

**Volume:** modest and human-paced (a person updating their phone number). No governor-limit drama.
**One line:** *Contact info and inquiries are ordinary reads/writes into Salesforce, done as the real
customer so per-user security is enforced.*

The rest of this document is about the fourth action.

---

## 4. INT10 — the deceptively hard one: transaction history at scale

Three facts about transaction history make it different from everything else:

1. **The data is NOT ours.** It lives in the **core banking system** — the authoritative system of
   record — and is exposed to us only through an **OData connector**. Salesforce is *not* the master
   of this data and should never pretend to be.
2. **The volume is enormous and spiky.** Core banking handles on the order of **100M+ transactions a
   day**, and the *read* traffic from customers is expected to **exceed 100,000 calls/hour**, with
   **holiday-season peaks** pushing higher.
3. **It must be live.** A balance or recent transaction shown stale is worse than useless in banking.

The chosen pattern is **Data Virtualization — Salesforce Connect + OData** (read it live where it
lives; don't copy it in), **fronted by a MuleSoft cache/gateway.** But *why* that works at 100,000+/hr
is the part that needs explaining — because of a limit that quietly caps the obvious design.

---

## 5. The crux: the Salesforce Connect OData limit — and the insight most people miss

### 5.1 The limit
The **Salesforce Connect OData adapter** does not make unlimited callouts. The governing limits are:

| Limit | Value |
|---|---|
| **OData callouts per hour (default)** | **20,000 / hour** per org |
| **Maximum after a limit-increase request** | on the order of **100,000 / hour** |

> ⚠️ **Cite these as the governing numbers, but confirm the current ceiling for your org** — Salesforce
> periodically revises these and grants increases case-by-case. The *argument* below holds regardless
> of the exact ceiling, because the requirement sits **at or above** the maximum with **no headroom**.

Put the numbers side by side and the problem is stark:

```
   Requirement:  > 100,000 transaction-history calls / hour   (higher during holidays)
   SF Connect default limit:   20,000 callouts / hour
   SF Connect absolute max:  ~100,000 callouts / hour
                             ▲
                             └── even the MAX is below the holiday requirement, with zero headroom
```

So a naïve design — **"surface transaction history as an External Object and let every customer read
hit it"** — is capped at 20,000/hr and, even after begging Salesforce for the maximum, has no room for
a holiday spike. **It cannot meet the requirement.**

### 5.2 The insight that makes the whole thing click
Here is the subtle bit a judge will test you on:

> **A cache placed *downstream* of Salesforce Connect does NOT reduce Salesforce Connect's callout
> count.**

External Objects **store no data** — that's the point of virtualization. So **every** read of an
External Object triggers a **fresh OData callout**, and that callout is metered against the 20,000/hr
limit **the moment Salesforce's adapter makes the HTTP call** — *regardless of whether MuleSoft then
serves it from cache.* Caching behind the adapter protects **core banking**, but it does **nothing**
for the **20,000/hr adapter limit**.

That single fact means you **cannot** solve this by "Salesforce Connect + a cache" if *all* the customer
traffic flows through External Objects. You have to **keep the high-volume traffic off the adapter
entirely.**

### 5.3 There are actually TWO different bottlenecks — and two different fixes
This is the key to the whole defense. Don't conflate them:

| # | Bottleneck | What it caps | The fix |
|---|---|---|---|
| **A** | The **Salesforce Connect OData adapter** | 20,000 (max ~100,000) **callouts/hour** | **Don't route the customer-facing volume through the adapter.** Serve it from a **MuleSoft Experience API** the portal/mobile calls **directly** — bypassing External Objects. |
| **B** | The **core banking system** itself | its own throughput under a 100,000+/hr read storm | **MuleSoft cache** (short TTL) + **rate-limiting** + **circuit breaker** — so core banking sees a smooth, de-duplicated trickle, not the spike. |

**Fix A protects the platform limit. Fix B protects the backend. You need both.** "Salesforce Connect +
cache" alone only addresses B and leaves A wide open — which is exactly why the explanation has to be
explicit.

### 5.4 The architecture that meets the requirement
Split the traffic by **who is reading and how much**:

```
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  CUSTOMER-FACING BULK  (>100,000 / hr, holiday spikes)                        │
  │                                                                              │
  │  Drupal / Mobile ──▶  MuleSoft EXPERIENCE API (cached)  ──miss──▶ Core Banking │
  │       (customers)         │  cache HIT → return instantly          (OData)     │
  │                           └── NEVER touches Salesforce Connect  ✅ Fix A       │
  │                               Short-TTL cache + throttle        ✅ Fix B       │
  └──────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  IN-SALESFORCE LIVE VIEW  (reps / service console, low volume < 20,000 / hr)  │
  │                                                                              │
  │  Salesforce UI ──▶ Salesforce Connect (External Objects) ──▶ OData ──▶ Core   │
  │                        │                                              Banking  │
  │                        └── stays comfortably under the 20,000/hr limit ✅      │
  └──────────────────────────────────────────────────────────────────────────────┘
```

- **Customers (the 100,000+/hr crowd)** hit a **MuleSoft Experience API directly.** Cache hits return
  instantly; only **cache misses** forward to core banking. **These reads never consume a single
  Salesforce Connect callout.** → **Fix A.**
- **Reps inside Salesforce** who need the elegant *no-copy, live* view get it through **Salesforce
  Connect External Objects** — but that audience is small and stays **under 20,000/hr.** This is where
  Data Virtualization genuinely earns its place.
- **Both paths** ultimately read the **same** core banking OData source **through the MuleSoft cache**,
  so core banking is protected once, centrally. → **Fix B.**

### 5.5 Worked example (illustrative)
Holiday peak of **120,000 customer reads/hour**:

- **Naïve design (all via External Objects):** 120,000 reads → 120,000 callouts → **breaches even the
  ~100,000/hr max** → throttled/failed requests; core banking also slammed with up to 120,000/hr. ❌
- **This design:**
  - 120,000 customer reads → **MuleSoft Experience API** → **0** Salesforce Connect callouts used. ✅ (Fix A)
  - Holiday spikes are dominated by **repeat/refresh reads** of the **same recent** balances/history, so
    a short-TTL cache absorbs most of them; only the **cache misses** (a fraction) forward to core
    banking, which sees a smooth, de-duplicated trickle instead of 120,000/hr. ✅ (Fix B)
  - Reps' in-org reads (a few thousand/hr) run through Salesforce Connect — **well under 20,000/hr.** ✅
- **Result:** neither the **platform limit** nor **core banking** is the bottleneck. Seamless under load.

> **Robustness note:** Fix A works **even if the cache is cold or every read is unique**, because the
> customer path simply doesn't use the adapter. The cache's job (Fix B) is to protect the *backend*; if
> hit ratios are low, the **circuit breaker + rate-limiter + last-known-value** degrade gracefully
> rather than toppling core banking. The two fixes fail independently, not together.

### 5.6 "Seamless under load" — the supporting mechanisms
- **Short-TTL caching** in MuleSoft (e.g. balances cached for ~30–60s, recent history for a few
  minutes) — tuned to the data's volatility.
- **Rate-limiting / throttling** at the gateway so core banking is never asked for more than it can take.
- **Circuit breaker + last-known-value fallback** — if core banking slows or dips, customers see
  cached/last-known data with a clear "as of HH:MM" rather than errors.
- **Central monitoring** (Anypoint) on the one gateway — you can *see* the holiday spike and scale.
- **Optional headroom:** request a Salesforce Connect limit increase for the *in-org* path as a safety
  margin — a small optimization, **not** the load-bearing part of the solution.

---

## 6. Why the other options don't work

| Option | Why it fails |
|---|---|
| **Copy / replicate transaction history into Salesforce** (custom objects kept in sync) | **Storage explosion** — 100M+ txns/day → billions of rows, huge Salesforce storage cost. **Staleness** — balances must be live; a copy always lags. **Duplicate system of record** — core banking *is* the source of truth; copying invites reconciliation bugs. Doesn't even solve read concurrency, and *adds* write load. You'd be **storing data you don't own and can't keep fresh.** |
| **Nightly ETL / Bulk import** | Data is up to **24 hours stale** — unacceptable for live balances/recent transactions. The holiday problem is **live read concurrency**, not batch freshness — this solves the wrong problem. |
| **Salesforce Connect External Objects for *all* reads, no cache/gateway** (1 read = 1 callout) | Hard-capped at **20,000/hr** (max ~100,000/hr) → **below** the >100,000/hr requirement with **zero holiday headroom**. And every read **hammers core banking directly** — the backend becomes the bottleneck. Breaches **both** limits (§5.3). |
| **Point-to-point: portal/mobile calls core banking directly** (no MuleSoft, no cache) | No cache → core banking takes the **full 100,000+/hr** — the exact bottleneck we must avoid. Plus **no central monitoring, no throttling, no reusable gateway,** and security/credentials scattered across front-ends. |
| **Just ask Salesforce to raise the OData limit** | Even the **maximum (~100,000/hr)** has **no headroom** for holiday peaks that exceed it, and it does **nothing** to protect core banking. A useful *margin* for the in-org path — never a *solution* on its own. |

**The throughline:** every rejected option either **breaches a hard limit**, **serves stale data**, or
**pushes the storm onto the fragile backend.** The winning design **keeps the bulk traffic off the
capped adapter (Fix A)** and **shields core banking with a cache + gateway (Fix B).**

---

## 7. What to say to the judge (60-second version)

> "Contact info, updates, and inquiries are ordinary Salesforce reads and writes over Experience Cloud
> (INT09), run **as the customer** so sharing and field security apply — no shared API user.
>
> Transaction history (INT10) is different: it lives in **core banking**, exposed via **OData**, and
> we'll see **100,000+ reads an hour** at holidays. We use **Data Virtualization — Salesforce Connect —
> for the live, no-copy view *inside* Salesforce**, where rep volume stays under the adapter's
> **20,000-callout/hour** limit. But we do **not** push the customer-facing 100,000+/hr through that
> adapter — a cache behind the adapter wouldn't help, because **every External Object read is a metered
> callout.** Instead, the portal and mobile app call a **cached MuleSoft Experience API directly**,
> which **never touches the Salesforce Connect limit** and **absorbs the spike before core banking ever
> sees it.** So there are really **two bottlenecks** — the **adapter limit** and **core banking** — and
> we solve each with a different mechanism. Copying the data in, nightly ETL, or routing everything
> through External Objects all fail — on storage, staleness, or that 20,000/hour cap."

**Anticipated follow-ups:**
- *"Salesforce Connect caps at 20,000/hr — how do you do 100,000+?"* → We don't route customer volume
  through it; External Objects serve only the in-org rep view. Customers hit the cached MuleSoft API
  directly.
- *"Doesn't the cache fix the adapter limit?"* → No — External Objects store nothing, so every read is a
  metered callout *before* the cache is reached. The cache protects **core banking**, not the adapter.
- *"What protects core banking under the spike?"* → Short-TTL cache + rate-limiting + circuit breaker;
  it sees a smooth de-duplicated trickle, not 100,000+/hr.
- *"What if the cache is cold?"* → The customer path still bypasses the adapter limit; the breaker and
  last-known-value keep the UX graceful.

---

*Bottom line: the requirement is met not by Salesforce Connect alone, but by a deliberate **traffic
split** — Salesforce Connect for the low-volume live view inside Salesforce (under 20,000/hr), and a
cached MuleSoft Experience API for the 100,000+/hr customer storm (off the adapter, shielding core
banking). Name the two bottlenecks, show the two fixes, and the scale question is won.*
