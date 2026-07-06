# Bedrock Enterprises — Identity & Access Management Domain Badge
## Presentation Content (mapped 1:1 to the official IAM template)

> Maps to `Identity and Access Management Template 1.0.pptx`. Slide titles below match the template sections.
> Audience: **Enterprise IT Architect.** ≤10 content slides. Diagrams are draw.io files (this folder) — export PNG/SVG.
> Theme: **"One Bedrock" — Salesforce as the central identity hub** unifying Financials, Healthcare, Transportation.

---

## SLIDE 1 — Title
**Bedrock Enterprises — Identity & Access Management**
"One Bedrock" Unified Identity · Presented to Enterprise IT Architecture
*[Your name / title / email]*

---

## SLIDE 2 — Agenda
- Scenario & key objectives
- System Landscape
- Authentication & Authorization Flows
- Requirement / Solution Matrix (with trade-offs)

---

## SLIDE 3 — Scenario Brief

**"One Bedrock": unify access across three divisions into one secure, scalable identity model — Salesforce as the central hub for access orchestration.**

- **Internal staff** (Fin/HC/Trans) span business units → need a **single access point** via existing **LDAP/AD** (multiple instances, on-prem + cloud; *no change to AD*), through the **corporate intranet only**, with **automatic** access on join/leave and **central** password recovery (suppress Salesforce reset).
- **Mobile** (staff + clients): branded app, **strong second factor (SMS OTP)**, anti-phishing, **remote session revoke** on lost device.
- **Customers**: self-registration + **social login** (Google/FB/LinkedIn); **real-time credit check** gating provisioning; **one-time ToS** consent on first login; **passwordless, fully branded** custom portal (headless).
- **Partners** (B2B, Experience Cloud): each org authenticates with **its own enterprise IdP**.
- **External services**: SMS gateway, credit bureau, **DMS** (no stored creds / no system user), **PayPal** (authenticate + authorize payment in one session).
- **Cross-cutting**: industry-standard encryption & signed/validated tokens; highly regulated (Healthcare + Financial).

> *Speaker notes:* Lead with the one-liner — **"Salesforce becomes the identity hub; we federate what exists, we don't rebuild it."** Group the ask into three audiences (employees, customers, partners) + external services. Flag the two non-negotiables an IT architect will probe: **don't touch AD**, and **never store credentials** (DMS, PayPal). Everything maps to a native Salesforce Identity capability — shown in the matrix.

---

## SLIDE 4 — System Landscape

**Salesforce Identity Hub at the center; federate to existing directories; broker every external service token-based.**

- **Internal:** intranet portal → **MyDomain (SP)** → **SAML 2.0** to a **federation hub** (Entra ID / AD FS / Ping) that fronts the multiple ADs → **SCIM** drives lifecycle.
- **Partners:** Experience Cloud → **MyDomain Login Discovery** routes each partner to **their own SAML IdP**.
- **Customers:** social sign-up via **Auth Providers (OIDC)**; passwordless via **Headless Identity APIs**.
- **External services:** **SMS gateway** (OTP), **credit bureau** (REST via Named Credential), **DMS** (Salesforce **as IdP**, no creds), **PayPal** (OAuth/OIDC, identity-mapped).

### Diagram 4.1 — System Landscape
> 📐 **File:** [`bedrock-iam-landscape.drawio`](./bedrock-iam-landscape.drawio) — open in diagrams.net / VS Code Draw.io ext → export PNG/SVG.
> Connector **colour = protocol**: blue **SAML 2.0** · green **OIDC** · purple **SCIM** · orange **OAuth 2.0** · red **REST+Named-Cred** · grey-dashed **LDAP**.

> *Speaker notes:* Walk left→right by audience band. The architect's takeaway: **one SP (MyDomain), many trust relationships, the right protocol per relationship.** Emphasize the federation hub collapses N ADs into one SAML trust = true "One Bedrock" SSO. Note the colour legend so the protocol story is readable at a glance.

---

## SLIDE 5 — Flow: Employee SAML SSO + MFA + JIT *(the 20% objective)*

**SP-initiated SAML 2.0; the browser relays every redirect; MyDomain is the Service Provider (ACS); MFA via SMS OTP; Just-in-Time provisioning on first login; one-time ToS Login Flow.**

### Diagram 5.1 — SAML SSO + MFA + JIT
> 📐 **File:** [`bedrock-iam-flow-saml-sso.drawio`](./bedrock-iam-flow-saml-sso.drawio)

**Entities exchanged:** SAML `AuthnRequest` (SP→IdP, via browser) → credential validation at AD → SMS OTP second factor → **signed SAML `Assertion`** (IdP→ACS, via browser POST) → SP validates signature/Issuer/Audience/Conditions → **JIT** user create/update → high-assurance session + Login-IP check → **ToS consent** (first login only) → session granted.

> *Speaker notes:* This is where 20% of the score lives — narrate it crisply. Three things the judge listens for: **(1) the browser's role** — it's the front-channel relay; it never sees AD credentials, only carries the AuthnRequest and the signed Assertion. **(2) MyDomain** — without it there's no SP/ACS endpoint, no per-org SAML, no Login Discovery; it's the foundation. **(3) MFA placement** — second factor before the assertion is issued. Then mention JIT (no pre-provisioning needed) and the ToS Login Flow fires once on first login.

---

## SLIDE 6 — Flows: Authorization (user · server-to-server · external)

*(Per the rubric's three authZ objectives — each now has its own draw.io sequence diagram in this folder.)*

| Flow | When | Pattern & entities | Diagram |
|------|------|--------------------|---------|
| **User authZ** (10%) | Branded mobile app / connected app | **OAuth 2.0 Authorization-Code + PKCE** → `code` → **access + refresh + id_token**; user consent screen; high-assurance session | [`bedrock-iam-flow-oauth-pkce.drawio`](./bedrock-iam-flow-oauth-pkce.drawio) |
| **Server-to-server** (10%) | Backend ↔ credit bureau / system integrations | **OAuth 2.0 JWT Bearer** — signed JWT (no user, no browser) → access token; Named Credentials hold the cert | [`bedrock-iam-flow-jwt-bearer.drawio`](./bedrock-iam-flow-jwt-bearer.drawio) |
| **External / connected apps** (10%) | Partners + PayPal | **Partners:** per-org **SAML IdP** via **Login Discovery**. **PayPal:** **Auth Provider (OIDC)** authenticates *and* authorizes payment in one session; **identity mapping** ties the PayPal identity to a Salesforce user; secure handoff authN→payment | [`bedrock-iam-flow-partner-paypal.drawio`](./bedrock-iam-flow-partner-paypal.drawio) *(2 panels)* |
| **DMS access** | Wealth-mgmt documents | **Salesforce as IdP** (SAML/OIDC) → DMS trusts SF tokens; **no credentials stored**, no system user | *(narrated in Defense Brief, Flow 5)* |

### Diagrams 6.1 – 6.3 — Authorization flows
> 📐 **Files** (open in diagrams.net / VS Code Draw.io ext → export PNG/SVG):
> - [`bedrock-iam-flow-oauth-pkce.drawio`](./bedrock-iam-flow-oauth-pkce.drawio) — **User authZ:** Auth-Code + PKCE (mobile). Shows `code_challenge`/`code_verifier`, consent + MFA, `code` → access/refresh/id_token.
> - [`bedrock-iam-flow-jwt-bearer.drawio`](./bedrock-iam-flow-jwt-bearer.drawio) — **Server-to-server:** JWT Bearer. Shows JWT claims (iss/sub/aud/exp), signature validation, Named Credential — no user/browser.
> - [`bedrock-iam-flow-partner-paypal.drawio`](./bedrock-iam-flow-partner-paypal.drawio) — **External:** *Panel A* partner per-org SAML via Login Discovery; *Panel B* PayPal OIDC authN + payment authZ + Registration-Handler identity mapping.
> Same visual grammar as the SAML flow: solid arrow = request/front-channel, dashed-open = response (code/tokens/assertion), yellow note = server-side step.

> *Speaker notes:* Contrast the two OAuth grants explicitly — **auth-code+PKCE = a user is present and consents; JWT bearer = trusted system, no user.** That distinction is two separate 10% objectives. For PayPal, the architect's real question is **identity mapping** — how a PayPal-authenticated session becomes a trusted Salesforce identity without leaking the payment context; answer: Auth Provider + registration handler maps the federation Id to the user, payment authZ rides the same session. Walk the PKCE diagram left-to-right and land on step 8 (`SHA256(verifier) == challenge`) — that's the anti-interception proof the judge wants to hear.

---

## SLIDE 7 — Identity Lifecycle (provisioning · sync · deprovisioning) *(15%)*

- **Provision:** Joiner in HR/IdP → **SCIM 2.0** creates the Salesforce user with correct profile/perm-sets/role; **SAML JIT** as create-on-first-login fallback.
- **Sync:** attribute/role changes propagate via SCIM (or JIT update on next login); single source of truth = the corporate IdP.
- **Deprovision:** Leaver → IdP disables → **SCIM deactivates** the Salesforce user → **active sessions + OAuth/refresh tokens revoked** → no manual admin step.
- **Lost device:** revoke the user's **OAuth tokens / connected-app access** + remove the registered MFA method → mobile sessions die immediately.

> *Speaker notes:* The headline for the 15% objective: **"lifecycle is event-driven from the IdP, not manual."** SCIM is push (real-time, supports deprovision); JIT is pull (login-time, create/update only — *cannot* deprovision). That's why we pair them. Tie "no admin action" (R2) and "lost device" (R10) together — both are token/session revocation.

---

## SLIDE 8 — Additional Security & Capture-on-Login *(5% + 5%)*

- **MyDomain login policy** — lock login to MyDomain, **disable Salesforce password reset** (R5); IdP owns recovery.
- **Login IP ranges / network policy** — internal access only via intranet (R3).
- **Login Flow (capture-on-login):** one-time **ToS consent** (R12); the **credit-check gate** before customer provisioning (R7) — friendly error on fail, provision only on success.
- **High-assurance sessions** for sensitive systems; **MFA** for mobile (R4).
- **Trust & encryption (R11):** TLS 1.2+, **signed SAML assertions / signed JWT**, **PKCE**, mTLS for server-to-server.

> *Speaker notes:* "Capture information upon login + enforce additional security" is its own 5% — **Login Flows** are the answer to both (ToS consent + credit-check gate). Pair with MyDomain policy (kills the password-reset gap) and signed-token integrity for the encryption requirement.

---

## SLIDE 9 — Requirement / Solution Matrix

| # | Requirement | Solution | Considerations / Trade-offs |
|---|-------------|----------|------------------------------|
| R1 | One Bedrock SSO across many on-prem/cloud ADs | **Federation hub** → one **SAML 2.0** trust; **MyDomain** = SP | **Hub** = clean single trust but new infra; **alt:** per-AD SAML + Login Discovery (no hub, but N trusts to operate) |
| R2 | Auto access on join/leave | **SCIM** provision/deprovision; **JIT** fallback | SCIM needs IdP support; JIT can't deprovision → pair them |
| R3 | Internal via intranet only | SP-initiated SAML + **Login IP ranges** | IP ranges need maintenance; VPN/egress IPs must be known |
| R4 | Branded mobile, SMS OTP, anti-phishing | **Connected App** + **Auth-Code+PKCE** + **MFA SMS OTP** | SMS OTP weaker than authenticator/passkey — acceptable per requirement; offer TOTP as upgrade |
| R5 | Suppress internal reset, central recovery | **MyDomain login policy**, disable forgot-password | Must ensure IdP self-service recovery exists |
| R6 | Social login | **Auth Providers (OIDC)** + Registration Handler | Map social attributes; account-linking for returning users |
| R7 | Real-time credit check before provisioning | **Login Flow** → credit API via **Named Credential**; friendly error | Synchronous dependency — handle timeout/bureau-down gracefully |
| R8 | Welcome email + guide | Registration Handler → email/journey | Marketing Cloud journey vs. simple email — scope choice |
| R9 | DMS, no stored creds / system user | **Salesforce as IdP** (SAML/OIDC) to DMS | DMS must support federation; else short-lived token broker |
| R10 | Lost device → revoke sessions | **Token/session revocation** + remove MFA method | Need a self-service / helpdesk revoke path |
| R11 | Industry-standard encryption & validation | TLS 1.2+, **signed assertions / JWT**, PKCE, mTLS | Cert lifecycle / rotation governance |
| R12 | One-time ToS consent on first login | **Login Flow** gated on first login; store consent | Versioning ToS → re-prompt on change |
| R13 | Partner: each org's own IdP | **Experience Cloud** + **per-partner SAML** + **Login Discovery** | Onboarding each IdP (metadata exchange) is per-partner effort |
| R14 | PayPal authN + payment authZ, one session | **Auth Provider (OIDC)** + **identity mapping**; secure handoff | Keep payment context isolated; map federation Id → user |
| R15 | Passwordless, fully branded portal | **Headless Identity APIs**; SF = authoritative IdP | More dev effort (custom UI owns UX + error handling) |
| R16 | Server-to-server | **OAuth JWT Bearer**; Named Credentials | Cert security; no user context = scope carefully |

> *Speaker notes:* Don't read every row — point at the matrix and say **"every requirement maps to a native Salesforce Identity capability; the trade-off column is where I made judgment calls."** Then volunteer the two biggest trade-offs: **federation hub vs. per-AD** (R1) and **SCIM vs. JIT** (R2). Invite the judge to drill into any row — the Defense Brief has the answers.

---

## SLIDE 10 — Summary / Key Decisions

- **Salesforce = central identity hub**; MyDomain is the anchor (SP, login policy, Login Discovery).
- **Federate, don't rebuild:** one SAML trust via a federation hub fronts the existing ADs → true "One Bedrock" SSO; AD untouched.
- **Right protocol per relationship:** SAML (employees/partners/DMS), OIDC (social/PayPal), OAuth Auth-Code+PKCE (mobile), JWT Bearer (server-to-server), SCIM (lifecycle), Headless (passwordless).
- **Security by default:** MFA, high-assurance sessions, signed/validated tokens, no stored credentials, instant revocation.
- **Capture & govern at login:** Login Flows for ToS consent + credit-check gate.

> *Speaker notes:* Close on the three things the rubric weights most: **the authentication flow (browser/MFA/MyDomain), the lifecycle (SCIM+JIT), and the three authorization flows.** One sentence to land: **"We unify identity without touching the directories, store no credentials we don't own, and govern every login centrally."**
