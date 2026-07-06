# Bedrock IAM Badge — Defense Brief & Q&A Prep

> Companion to `bedrock-iam-badge-SLIDES.md`. Use this to narrate the flows and survive Q&A.
> Rubric reminder (where points live): **Auth flow 20% · Lifecycle 15% · authZ user 10% · authZ s2s 10% · external/connected-apps 10%** · platform 10% · capture+security 5% · articulation 5% · trade-offs 5% · advanced external 5%.

---

## PART A — Flow narrations (what to *say*, and the entities exchanged)

### Flow 1 — Employee SAML 2.0 SSO + MFA + JIT *(headline; draw.io built)*
**Say:** "This is **SP-initiated SAML**. The employee hits a protected Salesforce resource through the intranet. Salesforce — at its **MyDomain**, which is the **Service Provider** — generates a **SAML AuthnRequest** and **302-redirects the browser** to our corporate **federation hub IdP**. The **browser is the front-channel relay** — it carries the request but never sees AD credentials. The IdP validates against **Active Directory**, triggers the **SMS OTP second factor**, then issues a **signed SAML Assertion** that the **browser POSTs back to the Assertion Consumer Service**. Salesforce validates the **signature, Issuer, Audience, Conditions, and NotOnOrAfter**, then **Just-in-Time provisions** the user from the assertion attributes if they don't exist. A **high-assurance session** is established with a **Login-IP** check, and on **first login only** a **ToS Login Flow** captures explicit consent before access."
**Entities:** AuthnRequest · signed Assertion (SAML attributes: NameID, email, roles) · SMS OTP · session.
**Tie to reqs:** R1, R2, R3, R4, R12.

### Flow 2 — User authorization: OAuth 2.0 Authorization-Code + PKCE *(10%)*
**Say:** "For the **branded mobile app** we use **OAuth Authorization-Code with PKCE**. The app sends the user (via the system browser) to Salesforce's authorize endpoint with a **code_challenge**. After authentication + MFA and a **consent** screen, Salesforce returns an **authorization code** to the app's redirect URI. The app exchanges the code **plus the code_verifier** for an **access token, refresh token, and id_token**. PKCE defends the public mobile client against code interception — no client secret on the device."
**Entities:** code_challenge/verifier · authorization code · access + refresh + id_token.
**Tie to reqs:** R4, R11. **Contrast:** a *user is present and consents.*

### Flow 3 — Server-to-server: OAuth 2.0 JWT Bearer *(10%)*
**Say:** "Backend integrations — e.g. calling the **credit bureau**, or a system pulling data — use the **OAuth JWT Bearer** flow. The client signs a **JWT** with its private key (cert pre-registered on the Connected App) and posts it to the token endpoint; Salesforce validates the signature and returns an **access token**. **No user, no browser, no interactive consent.** We store the signing cert and endpoint in a **Named Credential** so no secrets live in code."
**Entities:** signed JWT (iss, sub, aud, exp) · access token.
**Tie to reqs:** R16, R7, R11. **Contrast:** *trusted system, no user present.*

### Flow 4a — Partner federation: per-org IdP via Login Discovery *(10% external)*
**Say:** "Partners log into **Experience Cloud**. Because each partner org wants **its own enterprise IdP**, we enable **MyDomain Login Discovery** — instead of a password field, the user enters email; Salesforce **routes by domain** to that partner's **SAML IdP**. One Experience Cloud site, **many SAML trusts**, no shared credentials."
**Entities:** identifier (email/domain) · per-partner SAML Assertion.
**Tie to reqs:** R13. **Connected app concept:** each partner IdP is a configured SAML SSO trust.

### Flow 4b — PayPal: authenticate + authorize payment in one session *(10% external)*
**Say:** "PayPal is configured as an **Auth Provider (OIDC/OAuth)**. At checkout the customer is sent to PayPal, authenticates, and authorizes the payment **in the same session**. On return, a **Registration Handler maps the PayPal identity to a Salesforce user** (identity mapping) — so the authenticated PayPal session becomes a **trusted Salesforce identity** while the **payment context stays isolated** from the auth context. This is the 'secure handoff' the scenario calls out — reduces checkout drop-off."
**Entities:** OIDC id_token / OAuth tokens · mapped federation Id → Salesforce user.
**Tie to reqs:** R14.

### Flow 5 — DMS access: Salesforce as Identity Provider
**Say:** "Wealth-management documents live in an external **DMS that can't store credentials or use a system user**. So **Salesforce acts as the Identity Provider** — the DMS trusts a **SAML/OIDC token** minted by Salesforce for the verified user. Credentials are **never stored or exposed**; access is token-based and per-user."
**Tie to reqs:** R9, R11.

### Flow 6 — Headless passwordless (custom portal)
**Say:** "The custom web portal wants **zero passwords and full UI control**. We use the **Headless Identity APIs** — the front-end owns the entire journey and calls Salesforce identity endpoints directly; **Salesforce remains the authoritative IdP** but renders none of the UI. Passwordless via email/SMS one-time-passcode or passkeys."
**Tie to reqs:** R15.

---

## PART B — The two headline trade-offs

### B1. Federation hub vs. direct per-AD federation (R1)
- **Recommended — federation hub** (Entra ID / AD FS / Ping fronts all ADs): Salesforce holds **one SAML trust**; cleanest "One Bedrock"; central MFA & policy. **Cost:** assumes/introduces a hub.
- **Alternative — direct per-AD SAML + Login Discovery:** no new hub; **but** N SAML trusts to operate, MFA configured per AD, more moving parts. Identity Connect can sync each AD for lifecycle.
- **Verdict:** hub wins on manageability and matches the single-access-point vision; present per-AD as the no-new-infra fallback.

### B2. SCIM vs. SAML JIT for lifecycle (R2)
- **SCIM** = push from IdP, **real-time**, supports **create/update *and* deprovision**. Needs IdP SCIM support.
- **JIT** = pull at login, **create/update only**, **cannot deprovision** (a disabled user simply never logs in again — but the SF user stays active).
- **Verdict:** **SCIM as primary** (it's the only one that deprovisions), **JIT as fallback** for create-on-login. This pairing is the defensible answer.

---

## PART C — Anticipated judge questions & model answers

**Q: What exactly is the browser's role in SAML?**
A: Front-channel **relay/transport**. It carries the AuthnRequest from SP→IdP and POSTs the signed Assertion from IdP→ACS. It **never** receives AD credentials and can't read/modify the signed assertion without detection. It's why SAML is "browser SSO."

**Q: Why is MyDomain mandatory here?**
A: MyDomain is Salesforce's **SP identity and login surface** — it provides the ACS endpoint, lets us bind SAML/Auth Providers, enforce login policy (kill password reset), and enables **Login Discovery** for routing partners to their own IdPs. No MyDomain → no enterprise SSO story.

**Q: SAML or OIDC for employees — why SAML?**
A: Enterprise AD/federation-hub estates are **SAML-native** (AD FS, Entra Enterprise Apps). SAML carries rich attributes for **JIT**. We use **OIDC** where it fits better — social login and PayPal (consumer IdPs), and OAuth for app authorization. Right protocol per relationship.

**Q: How do you deprovision instantly / handle a lost device?**
A: **SCIM deactivation** from the IdP flips the SF user inactive and we **revoke active sessions + OAuth/refresh tokens**; for a lost device we revoke that connected-app's tokens and **remove the registered MFA method**. JIT alone can't do this — that's why SCIM is primary.

**Q: SMS OTP isn't the strongest factor — defend it.**
A: It's the scenario's stated requirement and a real anti-phishing improvement over passwords for mobile. I'd note the trade-off and offer **authenticator/TOTP or passkeys** as a hardening upgrade — but SMS OTP meets the "mobile-appropriate second factor" ask with the widest device reach.

**Q: Auth-Code+PKCE vs JWT Bearer — when each?**
A: **Auth-Code+PKCE** when a **user is present** and must consent (mobile app). **JWT Bearer** for **server-to-server**, no user, no browser — signed JWT proves the client. Two different rubric objectives; never use JWT bearer to dodge a needed user consent.

**Q: Credit check is synchronous in a Login Flow — what if the bureau is down?**
A: The Login Flow calls the bureau via **Named Credential** with a timeout; on failure we **don't provision** and return a **user-friendly error** (per R7), optionally queueing for retry. We never half-provision.

**Q: PayPal identity mapping — how does an external auth become a trusted SF identity safely?**
A: PayPal as **Auth Provider**; the **Registration Handler** maps the PayPal federation Id to a Salesforce user (creating/linking as needed). The **authentication context and payment-authorization context stay separate** — we trust the identity, not the payment channel, for session purposes.

**Q: Headless — why not just standard Experience Cloud login?**
A: The requirement is a **fully branded, passwordless** portal with **complete front-end control**. Headless Identity APIs let the custom UI own the journey while Salesforce stays the **authoritative IdP** — you can't get that UX control from the hosted login pages.

**Q: You're introducing a federation hub — what if they don't have one?**
A: Then fall back to **direct per-AD SAML with Login Discovery** (+ Identity Connect for sync). Same end-user experience; more trusts to operate. I designed for the hub because it best realizes "One Bedrock," but the architecture degrades gracefully.

---

## PART D — Coverage check vs. rubric
- 20% auth flow → Slide 5 + Flow 1 (browser role, MFA, MyDomain) ✓
- 15% lifecycle → Slide 7 + Part B2 (SCIM+JIT, deprovision) ✓
- 10% authZ user → Flow 2 (Auth-Code+PKCE) ✓
- 10% authZ s2s → Flow 3 (JWT Bearer) ✓
- 10% external/connected apps → Flows 4a/4b (partner multi-IdP, PayPal) ✓
- 5% capture-on-login + security → Slide 8 (Login Flows, MyDomain policy) ✓
- 5% advanced external-user auth → Headless (Flow 6) + social ✓
- 5% trade-offs → Part B + matrix trade-off column ✓
- 10% platform features / 5% articulation → spread across slides ✓
