# Bedrock IAM Badge — Everything Explained in Plain English

> Companion to the slides, the diagrams, and the defense brief. This one has **no jargon you
> have to already know** — every technical term is explained with a real-world analogy the first
> time it appears. Read it start to finish and the whole solution should "click." Then the
> `.drawio` diagrams and the defense brief will read like a story you already know.

---

## The ONE idea behind the entire design

Two words carry everything. Learn to say them apart and you're 80% of the way there:

- **Authentication** = proving **WHO you are.** (Showing your ID at the door.)
- **Authorization** = what you're **ALLOWED TO DO** once you're inside. (Which doors your badge opens.)

And here is the single trick the whole "One Bedrock" design is built on:

> **Bedrock does not want to store your password.**
> Instead of being the place that *checks* passwords, Salesforce becomes the place that
> **trusts a badge** issued by whoever *already* knows you — your employer's HR system, Google,
> PayPal, and so on. Salesforce just needs to be sure the badge is **genuine and unforged.**

The slogan for this is **"federate, don't rebuild."** Bedrock doesn't recreate everyone's
passwords — it *trusts* the systems that already have them.

### The running analogy: a members' club that trusts badges

Picture Salesforce as an exclusive **members' club**. A normal club keeps its own list of members
and checks a card at the door. Bedrock's club is smarter and safer: **it keeps no password list of
its own.** Instead it trusts **tamper-proof badges** handed out by trusted partners (your employer,
Google, PayPal). The bouncer's only job is to confirm the badge is real. That's the mental model —
every flow below is just a different *kind of visitor* getting a *different kind of badge*.

---

## The cast of characters (the glossary, in plain terms)

| The technical term | What it really means | In the club analogy |
|---|---|---|
| **Salesforce** | The system everyone is trying to get into | The club / the building |
| **MyDomain** | Bedrock's own branded front door + reception desk (e.g. `bedrock.my.salesforce.com`) | The reception desk with **Bedrock's name over it** |
| **IdP** (Identity Provider) | The service that actually knows your password and vouches for you | **HR / the ID-card office** |
| **Federation hub** (Entra ID / AD FS / Ping) | One master ID office sitting in front of several smaller staff directories | **Head-office security** that speaks for every branch |
| **Active Directory / LDAP** | The company's existing list of staff | The old **filing cabinet** of employees |
| **SP** (Service Provider) | The system that *relies on* the badge — here, Salesforce | The club **trusting** the badge |
| **SAML Assertion** | A sealed, signed, tamper-proof statement: "this is Jane, she's legit" | A **hologram wristband** printed for one visit |
| **Browser** | The thing that carries sealed messages back and forth | A **courier who can't open the envelopes** |
| **Token** (access / refresh / id) | A temporary electronic pass | A **time-limited keycard** |
| **MFA / SMS OTP** | A second proof — a code texted to your phone | A **second lock** that needs a texted code |
| **JIT provisioning** | Auto-creating your account the first time you show a valid badge | Reception **makes your locker** on your first visit |
| **SCIM** | HR automatically telling the club the instant you're hired or fired | HR **sends a live memo** on every hire/leave |
| **Consent / ToS Login Flow** | A one-time "I agree to the terms" step | Signing the **guestbook** on your first visit |

Keep this table handy — every flow below is built from these same pieces.

---

## Flow 1 — Employee logs in (SAML SSO + MFA + JIT) — *the headline, 20% of the grade*
📐 Diagram: `bedrock-iam-flow-saml-sso.drawio`

**What's happening, plainly:** An employee clicks into Salesforce from the company intranet. They
**never type a Salesforce password.** Salesforce essentially says: *"I don't check passwords — go
prove yourself to your own company's ID office, then come back with a signed badge."* The browser
carries them to the company's ID office, they log in the normal company way, a code is texted to
their phone as a second check, and the ID office prints a **sealed, signed badge**. The browser
carries that badge back to Salesforce, which checks the seal is genuine — and if it's this person's
**very first visit**, it creates their account on the spot from the details on the badge.

**The analogy:** You want into the club. The bouncer (Salesforce, at its MyDomain reception desk)
doesn't know you and doesn't want your password. He sends you to **your employer's security desk**.
You badge in there the way you always do; they **text you a code** to be doubly sure it's you; then
they hand you a **tamper-proof hologram wristband** stamped "admit Jane." You walk back to the club;
the bouncer inspects the *wristband*, not you. First time here? He quickly **makes you a locker**
(your account) using the info printed on the wristband, and has you **sign the guestbook** (accept
the terms) once.

**The three things a judge listens for:**
1. **The browser is only a courier.** It carries sealed envelopes between offices. It **never sees
   your company password**, and it **can't forge or alter** the signed badge without the seal breaking.
2. **MyDomain is the foundation.** It's Bedrock's own reception desk — the place the badge gets
   handed to. No reception desk, no way to receive badges, no enterprise login story.
3. **The second factor (the texted code) happens *before* the badge is printed** — you can't get a
   valid badge with just a stolen password.

**Remember this one line:** *Salesforce trusts a signed badge from your company's ID office; the
browser just carries it; your password never touches Salesforce.*

---

## Flow 2 — Mobile app acting for you (OAuth Auth-Code + PKCE) — *user authorization, 10%*
📐 Diagram: `bedrock-iam-flow-oauth-pkce.drawio`

**First, the shift:** Flow 1 was about *getting you in* (authentication). This flow is about
*letting an app do things on your behalf* (authorization). Different question, different mechanism.

**What's happening, plainly:** You've got Bedrock's branded phone app. The app **should not hold
your password.** So when it needs access, it opens a proper login page, you log in + enter your
texted code + tap **"Yes, I allow this app."** Salesforce hands back a one-time **claim ticket**
(the "authorization code"). The app then **swaps that ticket** for a **keycard** (access token)
plus a **renewal card** (refresh token) so you're not forced to log in every single time.

**The PKCE part — this is the bit worth truly understanding:** When the app *first* sends you to log
in, it also invents a secret and shows a **padlock made from that secret** (the "code_challenge").
Later, when the app comes back to collect the keycard, it must present **the original secret that
opens that padlock** (the "code_verifier"). Why bother? On a phone, a sneaky app could try to steal
your claim ticket mid-handoff. But a **stolen ticket is useless without the matching secret** — and
that secret never left the real app. Think **tear-in-half ticket stub**: a pickpocket who grabs half
of it can't redeem anything.

**The analogy:** You give a **valet** (the app) permission to fetch your car — but you don't hand
over your house keys, only a **limited valet key** (the keycard/token) that just starts the car.
And PKCE is the **torn ticket stub**: the valet kept the other half, so a thief who copies your half
still can't claim the car.

**Remember this one line:** *A real person is present and taps "allow"; PKCE makes a stolen code
useless because only the genuine app holds the matching secret.*

---

## Flow 3 — Two machines talking, no human (OAuth JWT Bearer) — *server-to-server, 10%*
📐 Diagram: `bedrock-iam-flow-jwt-bearer.drawio`

**The shift:** There is **no person here at all.** A backend system — say, the job that calls the
**credit bureau**, or a nightly data pull — needs to talk to Salesforce. Nobody's there to type a
password or tap "allow." So we can't use Flow 2.

**What's happening, plainly:** The backend system holds a **private signing key** (think: a company
seal kept in a safe — stored in a **Named Credential**, which just means "a secure vault so the key
is never written into the code"). It writes a short note — *"I am system X, acting for user Y, this
message is for Salesforce, valid for the next 5 minutes"* — and **stamps it with its private seal.**
That stamped note is the **JWT.** It sends the note to Salesforce. Salesforce already has the
**matching public seal on file**, checks that the stamp is genuine and not expired, and hands back a
keycard. No browser, no login page, no consent screen — **the signed note *is* the proof.**

**The analogy:** Two businesses that already trust each other. Instead of sending a person, one
business sends a **notarized letter**: *"the bearer is authorized."* The other business recognizes
the **notary's seal** and acts on it. Nobody needs to show up in person — the sealed letter does the
work.

**Remember this one line:** *No human, no browser — a signed letter (JWT) proves the machine's
identity; the private key lives in a Named Credential, never in the code.*

> **The distinction judges probe (Flow 2 vs Flow 3):** *"Is a person present to consent?"*
> **Yes → Auth-Code + PKCE. No → JWT Bearer.** These are two **separate** 10% marks — don't blur them.

---

## Flow 4a — Partners, each with their OWN login (Login Discovery) — *external, part of 10%*
📐 Diagram: `bedrock-iam-flow-partner-paypal.drawio` (Panel A)

**What's happening, plainly:** Bedrock's partners are *other companies.* Each one wants its own
staff to log in with **their own company credentials** — Bedrock shouldn't be issuing passwords to
other firms' employees. So Bedrock runs **one** partner portal (Experience Cloud). Instead of a
password box, it just asks for your **email**. From your email's domain it figures out **which
partner you're from** and routes you to **that partner's own security desk** to get badged — the
exact same SAML dance as Flow 1, just pointed at a different ID office for each partner.

**The analogy:** One **shared building lobby** used by many partner firms. The receptionist doesn't
check passwords — she asks **"who do you work for?"**, sends you to **your own firm's security desk**
to get badged, and lets you in when you return with your firm's badge. **One lobby, many trusted
security desks, zero shared passwords.**

**Remember this one line:** *One portal, many partner ID offices — "type your email, and we'll send
you to your own company to log in."*

---

## Flow 4b — PayPal: prove identity AND pay, in one go — *external, part of 10%*
📐 Diagram: `bedrock-iam-flow-partner-paypal.drawio` (Panel B)

**What's happening, plainly:** At checkout the customer clicks **"Pay with PayPal."** PayPal does
**two jobs at once**: it confirms **who the person is** *and* **authorizes the payment**, in the same
session. When the customer returns, Salesforce's **Registration Handler** matches the PayPal identity
to a Salesforce customer record — creating or linking it as needed. That matching step is called
**identity mapping.** The clever, secure part: Salesforce trusts the **identity** PayPal vouched for,
but the **payment/card details stay walled off inside PayPal** — Bedrock never touches card data.

**The analogy:** A **trusted partner store that also checks your ID.** You pay at PayPal's counter;
PayPal both confirms it's really you *and* takes the payment. You come back holding a **receipt that
also proves who you are.** Bedrock's system says *"ah — this PayPal customer is our member Jane"* and
**links the two records** — all without ever seeing your card.

**Remember this one line:** *PayPal proves identity **and** takes payment in one session; the
Registration Handler links the PayPal identity to a Salesforce user; card data never leaves PayPal.*

---

## Flow 5 — The DMS, where Salesforce becomes the ID office — *no stored credentials*
📐 Narrated in the Defense Brief (Flow 5); conceptually the mirror image of Flow 1.

**The twist:** In every flow so far, an **outside** service vouched *to* Salesforce. Here the roles
**flip.** The document store (**DMS**) holding wealth-management files **can't store passwords** and
has **no system login.** So now **Salesforce is the ID office** that vouches *for* the user. Salesforce
mints a **signed token** for the already-verified user, and the DMS simply **trusts Salesforce's
token.** No credentials are stored in the DMS at all.

**The analogy:** Now **Bedrock is the one vouching.** A partner vault refuses to keep its own guest
list, so when your Salesforce-verified employee needs a document, Salesforce hands them a **signed
note the vault recognizes**: *"I've checked her — let her see her files."* The vault trusts Bedrock's
stamp instead of keeping passwords.

**Remember this one line:** *The roles flip — here Salesforce is the ID office; the DMS trusts
Salesforce's signed token, so no passwords ever live in the DMS.*

---

## Flow 6 — Headless, fully-branded, passwordless portal — *advanced external, 5%*
📐 Narrated in the Defense Brief (Flow 6).

**What's happening, plainly:** Bedrock wants a **completely custom-branded** sign-up and login
experience — its own screens, its own look, **no Salesforce-branded pages** anywhere. "**Headless**"
means Salesforce provides the **identity brains** (via APIs) but **none of the screens** — Bedrock
builds the entire front-end and calls Salesforce quietly behind the scenes. **Passwordless** means
you log in with a **one-time code** (by email or SMS) or a **passkey**, never a stored password.

**The analogy:** Bedrock builds its **own beautiful front door and lobby**, but the actual
**lock-and-key brain behind the wall is still the same trusted security company** (Salesforce),
working invisibly. Guests never see the security company's logo — just Bedrock's.

**Remember this one line:** *Bedrock owns 100% of the look; Salesforce is the invisible identity
engine behind the APIs; no passwords — just one-time codes or passkeys.*

---

## How accounts are born and killed (SCIM vs JIT) — *lifecycle, 15% of the grade*
📐 Slide 7.

This is a big chunk of the score and it confuses people, so here it is in the simplest terms:

- **JIT (Just-In-Time)** = the account is **created the first time** someone logs in with a valid
  badge. Great for **birth.** But it can **only create or update** — it can **never delete.** Why?
  A fired employee simply **never logs in again**, so JIT never fires for them, and their Salesforce
  account would sit there **active forever.** That's a security hole.
- **SCIM** = HR (the IdP) **actively pushes a message** to Salesforce the **instant** someone is
  hired (*"create this account"*) or leaves (*"switch this one off"*). It handles **both birth and
  death** of the account, in real time.
- **So: SCIM is the primary method** (it's the only one that can turn accounts **off**), and **JIT
  is the backup** for create-on-first-login.

**The analogy:** **JIT** is reception making your locker the first time you show up. **SCIM** is HR
sending reception a **live memo** the moment you're hired *or fired*, so the locker list is always
current — **including taking your locker away the day you leave.** Reception-making-a-locker never
removes lockers; only HR's memo does.

**Lost phone?** Same idea, but for one device: **revoke that phone's keycards** (tokens) and
**remove its texted-code registration**, and the app on it **dies instantly.**

**Remember this one line:** *SCIM = live HR feed, handles account birth **and** death; JIT =
auto-create on first login only, can't delete. Pair them, with SCIM in charge.*

---

## The two big judgment calls (the trade-offs), in plain terms

**1. One master ID office (federation hub) vs. wiring up each directory separately.**
- **Hub** = put **one head-office security desk** in front of all the branch filing cabinets.
  Salesforce then has **one clean trust** and **one place** to enforce MFA and policy. Downside:
  you need that hub to exist.
- **Per-directory** = wire Salesforce **directly to each** filing cabinet. No new kit, **but**
  Salesforce now juggles **many** trusts and MFA is configured **many** times.
- **Recommendation:** the **hub** best delivers the "One Bedrock" single-front-door vision; the
  per-directory approach is the graceful **fallback** if there's no hub.

**2. SCIM vs. JIT** — covered just above. **SCIM is primary** for one decisive reason: it's the
**only one that can switch an account OFF** when someone leaves.

---

## If you remember nothing else — the cheat sheet

**The two words:** **Authentication = who you are. Authorization = what you're allowed to do.**

**The whole trick:** *Bedrock stores no passwords it doesn't own — it trusts signed badges from
whoever already knows you.*

**One line per flow:**

| Flow | The one-liner |
|---|---|
| **1. Employee SSO (SAML)** | Signed badge from your company's ID office; browser just carries it |
| **2. Mobile app (Auth-Code + PKCE)** | A person is present and taps "allow"; torn-ticket-stub stops code theft |
| **3. Server-to-server (JWT Bearer)** | No human — a notarized letter proves the machine; key in a Named Credential |
| **4a. Partners (Login Discovery)** | One portal, many partner ID offices; routed by your email domain |
| **4b. PayPal** | Proves identity **and** pays in one session; identity mapped, card data stays at PayPal |
| **5. DMS (Salesforce as IdP)** | Roles flip — Salesforce vouches; the vault trusts its token; no stored passwords |
| **6. Headless portal** | Bedrock owns the look; Salesforce is the invisible engine; passwordless |
| **Lifecycle (SCIM + JIT)** | SCIM = live HR feed (birth + death); JIT = create-on-first-login backup |

**The distinctions a judge will push on:**

| If they ask… | Say… |
|---|---|
| *"How do employees log in?"* | SAML SSO — a signed badge from the company's ID office; MyDomain is our reception desk |
| *"Is a person there to consent?" — **yes*** | OAuth **Auth-Code + PKCE** (the mobile app) |
| *"Is a person there?" — **no**, it's machine-to-machine* | OAuth **JWT Bearer** (the signed letter) |
| *"Why SAML for staff but OIDC for social/PayPal?"* | Enterprise directories speak **SAML**; consumer logins speak **OIDC** — right language per relationship |
| *"Who's vouching for whom?"* | Normally an outside ID office vouches **to** Salesforce; for the DMS it **flips** — Salesforce vouches |
| *"How do you instantly cut off a leaver?"* | **SCIM** switches the account off + revokes tokens/sessions — JIT alone can't |

---

*That's the entire IAM solution in human terms. Read this once, then skim the diagrams — every
arrow on them is now just a courier carrying one of the badges, letters, or keycards described above.*
