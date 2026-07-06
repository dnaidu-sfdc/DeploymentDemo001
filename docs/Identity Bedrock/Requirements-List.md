# Bedrock — Identity & Access Management Badge: Requirements List

> Phase 1 artifact: **requirements capture only** (no solutioning yet). Each item has an ID for later mapping to a solution + trade-offs.

---

## 1. How this scenario is graded (drives what the presentation MUST cover)

The judge scores these areas — the weightings tell us where to spend depth (authentication flows and identity lifecycle dominate):

| Weight | Evaluation area |
| --- | --- |
| 20% | **Authentication flows** — details incl. the role of the **browser, MFA, and My Domain** |
| 15% | **Identity management** — provisioning, syncing, **deprovisioning** |
| 10% | **Authorization flow with user interaction** (delegated user authz) |
| 10% | **Authorization flow for server-to-server** interaction |
| 10% | **Complex authorization with external parties**, incl. use of **connected apps** |
| 10% | Leverage platform features appropriately |
| 5% | Identify business requirements / understand needs |
| 5% | Capture information upon login + enforce additional security measures |
| 5% | Advanced auth/authz for **external users** |
| 5% | Articulate design & handle objections |
| 5% | Trade-offs, considerations, alternatives |

**Audience:** Enterprise IT Architect. **Format:** ≤10 content slides (excl. transition/agenda), 30 min present + 20 min Q&A. Must state assumptions.

---

## 2. System landscape / integration points (context, not requirements themselves)

- **LDAP/AD credential stores** — multiple AD instances across divisions; **mix of cloud + on-premise**; **no change to existing AD** allowed.
- **Internal Salesforce access** — only through a **corporate intranet portal** (secure access point, behind internal firewall).
- **Partner access** — authenticated against a **separate AD store** for third-party/B2B.
- **Customer authentication** — **self-registration**, plus planned **social login** (Google, Facebook, LinkedIn).
- **Document Management System (DMS)** — external; **no credential storage and no system/service users allowed**; holds sensitive Wealth Mgmt docs.
- **Credit check service** — external; Salesforce must call it **real-time via secure API** during customer provisioning.

---

## 3. Requirements to solve

### A. Employee / internal access
- **R1 — Internal SSO on existing AD ("One Bedrock").** Single access point for staff who work across multiple business units, using existing corporate credentials via **SSO on the current LDAP/AD** infrastructure (hybrid: cloud + on-prem, no AD changes). Access only via the corporate intranet portal.
- **R2 — Automated user lifecycle (provisioning & deprovisioning).** As employees join or leave, Salesforce access must **update automatically with no manual admin action** (joiner/mover/leaver), including **syncing** attributes and **deprovisioning** on exit.
- **R3 — Secure branded mobile app with strong MFA.** BF employees & clients rely on mobile; a **branded mobile app** must guard against unauthorized access and phishing using **mobile-appropriate second factors (SMS-based OTP)**.
- **R4 — Centralized credential governance / suppress internal resets.** Internal staff must **always authenticate via corporate tools**; **password reset & account recovery governed centrally**; Salesforce must **suppress its own internal reset features**.

### B. Customer access
- **R5 — Easy customer sign-up via social login.** Self-service registration with familiar IdPs — **Google, Facebook, LinkedIn**.
- **R6 — Real-time credit check gating provisioning.** During onboarding, call an **external credit-check API in real time**; **only provision the user if the check passes**, otherwise return a **user-friendly error** (no account created).
- **R7 — Personalized onboarding after success.** On successful onboarding, send a **personalized welcome email** and provide access to a **helpful getting-started guide**.

### C. Additional security measures
- **R8 — Secure DMS access without stored credentials.** Only **verified users** may access the external DMS; **credentials must never be exposed or stored** (DMS forbids credential storage and system users) — needs a secure, per-user, token-based access pattern.
- **R9 — Lost/stolen device response.** When a user loses their mobile device, the platform must **swiftly revoke active sessions** and **prevent unauthorized use**.
- **R10 — Digital trust via industry-standard crypto.** All user↔system interactions must use **secure, verifiable protocols** (industry-standard **encryption + signature/validation**) to prevent tampering/misuse.
- **R11 — One-time Terms of Service consent at first login.** New customers must **review & accept a ToS agreement** on their **first successful login only**, capturing **explicit consent before access** is granted.
- **R12 — Partner federation via Experience Cloud (per-partner IdP / BYOIdP).** Flexible authentication for the partner community on **Experience Cloud**, where **each partner org authenticates users with its own enterprise identity provider**.
- **R13 — PayPal authenticate + authorize in one session (checkout).** Let customers **authorize use of their PayPal account during checkout**, combining **authentication + payment authorization in a single session**; handle **identity mapping between PayPal and Salesforce** with secure handoff between auth and payment contexts.
- **R14 — Passwordless, fully branded headless login.** A seamless, fully **branded, passwordless** login inside Bedrock's **custom web portal** using **headless identity flows**, with **Salesforce as the authoritative IdP** while Bedrock keeps full control of the front-end UI/journey.

---

## 4. Cross-cutting flows the deck must explicitly demonstrate

These are called out by the grading rubric / expectations and cut across the requirements above:
- **F1 — Authentication flow narrative:** role of the **browser**, **MFA**, and **My Domain** (20% — highest weight).
- **F2 — Authorization with user interaction:** delegated-access flow where a user consents (e.g., OAuth web-server / user-agent).
- **F3 — Authorization server-to-server:** system-to-system flow with no user present (e.g., JWT bearer / client credentials).
- **F4 — Complex external-party authorization using connected apps.**
- **F5 — Directory & IdP connectivity/sync:** how Salesforce connects and synchronizes with **internal & external directories**, **identity providers**, and **external service providers (SMS gateway, credit bureau, DMS)**.

## 5. Required deliverables (presentation)
- **D1** — High-level **architecture diagram** (Salesforce + external systems).
- **D2** — **Auth/authn workflow** descriptions with transitions and system touchpoints.
- **D3** — Explanation of **connect/sync** with directories, IdPs, and external service providers.
- **D4** — **Rationale, trade-offs, and alternatives** for key architectural decisions.
- **D5** — State any **assumptions** made.
