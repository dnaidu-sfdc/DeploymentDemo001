# Bedrock — Development Lifecycle & Deployment (DevSecOps)
# Presentation Slides

> Target: ~15 slides · 30 min present · audience = **CTO, program & release management**.
> Each slide has **[ON-SLIDE]** content (what appears) and **[SPEAKER NOTES]** (what you say).
> Demo (Slide: Walkthrough) uses **this org** — it already has a Custom Object + Apex + Flow.

---

## Slide 1 — Title

**[ON-SLIDE]**
- **Bedrock Enterprises — DevSecOps Strategy for the Salesforce Program**
- *Delivering 3–5 parallel projects, monthly, securely, and provably compliant*
- Presenter name · Program Architect · date

**[SPEAKER NOTES]**
- "This is a 12-month DevSecOps strategy to take Bedrock from a fragmented, multi-partner pilot to a governed delivery factory that ships monthly."
- Set expectation: ~15 slides, then a live end-to-end CI/CD demo.

---

## Slide 2 — Agenda

**[ON-SLIDE]**
1. Introduction & the case
2. Challenges & risks
3. DevSecOps phased roadmap (12 months)
4. Branching strategy & source control
5. Environment landscape (multi-org + Data 360)
6. CI/CD tools & processes (incl. security)
7. Development methodology
8. QA & testing strategy
9. Governance (program · architecture · data)
10. Live demo / walkthrough → Executive summary

**[SPEAKER NOTES]**
- "I'll spend most time on the four areas that retire the most risk: branching, environments, CI/CD, and governance."
- "Everything ties back to four outcomes: speed, no bottlenecks, compliance, scalability."

---

## Slide 3 — Who Am I (rapport / elevator pitch)

**[ON-SLIDE]**
- **Program Architect** brought in by the CIO for the flagship Salesforce program
- Focus: delivery structure, governance & automation that let **multiple partners ship safely, in parallel, at speed**
- Background: enterprise Salesforce DevSecOps across regulated (Healthcare/Financial) programs
- *"My job is to make your monthly-release promise to the board boring — predictable, repeatable, provably compliant."*

**[SPEAKER NOTES]**
- 30-second credibility: multi-org, multi-SI, regulated delivery experience.
- Signal empathy with the CTO's weekly board reporting and ROI pressure.

---

## Slide 4 — The Case (problem we're solving)

**[ON-SLIDE]**
- Bedrock is piloting Salesforce with **3 partners building 3 projects in parallel**, across a **multi-org** landscape, under **fixed regulatory deadlines**
- Today: **no program management · no aligned timeline · fragmented tooling · conflicting dev work · unclear environments · poor security hygiene · uncertainty on Data 360 & Agentforce**
- **One-liner:** *shipping a regulated, multi-partner, multi-org program with no shared delivery factory — so speed, quality & compliance are all at risk at once*
- **The prize:** monthly releases · no bottlenecks · audit-ready compliance · a model that scales to 5 projects

**[SPEAKER NOTES]**
- State the problem in the CTO's language: risk to the board commitment.
- "The root cause isn't any one partner — it's the absence of a shared factory. That's what the next 12 months build."
- Transition to challenges & risks.

---

## Slide 5 — Challenges & Risks

**[ON-SLIDE]**
- **Top project risks**
  - No program mgmt / unaligned timelines across 3 partners → **collision, missed fixed regulated dates** (High)
  - Different standards across multi-SI teams → **inconsistent quality & security** (High)
  - Average-skill offshore teams → **defects, weak coverage** (Med-High)
- **Top technical risks**
  - **Metadata conflicts/overwrites** in the shared org → lost work, broken prod (High)
  - **Deploying Data 360 & Agentforce** (non-standard metadata) → failed/manual releases (High)
  - **Secrets in metadata / broad deploy perms** → security incident, audit failure (High)
  - No test automation · environment drift → regressions, "works in one org" failures (High)
- **Two threats dominate:** *collision* and *compliance breach* — both symptoms of the missing delivery factory

**[SPEAKER NOTES]**
- Walk the risk register at a summary level; full P1–P5 / T1–T7 table is in the appendix.
- Key message: "I've sequenced the roadmap to retire the highest-impact risks first — collision and compliance."
- Each later slide explicitly says which risk it retires.

---

## Slide 6 — DevSecOps Phased Roadmap (12 months)

**[ON-SLIDE]**
- **Phase 0 — Foundation (Month 0–1):** program & governance kickoff · tool selection · org/sandbox audit · source-control baseline · define standards & DoD → *retires P1*
- **Phase 1 — Establish (Month 1–3):** Git + branching model · CI validation on PR · sandbox landscape · basic quality gates · hire key personas → *retires T1, T3*
- **Phase 2 — Automate (Month 3–6):** full CI/CD auto-deploy · test automation framework · SAST/SCA (Code Analyzer) · OmniStudio & Data 360 pipeline handling → *retires T2, T5*
- **Phase 3 — Secure & Scale (Month 6–9):** secrets vault · RBAC hardening · DAST · Agentforce deploy patterns · **shift to monthly release train** → *retires T4, T6*
- **Phase 4 — Optimise & AI (Month 9–12):** adopt AI dev tooling · DORA metrics · continuous improvement · **scale to 5 parallel projects** → *retires P5*
- Crawl → walk → run: **value from Phase 1, monthly cadence by Phase 3**

**[SPEAKER NOTES]**
- Emphasise this is **incremental** — Bedrock isn't blocked waiting 12 months; each phase ships capability.
- Tie phases to the four outcomes; note fixed regulated deadlines are protected by getting traceability + environments right early.
- Hotfix handling is designed in from Phase 1 (branching) — covered next.
- Assumption: partner onboarding to standards happens in Phase 0–1 as an engagement condition.

---

## Slide 7 — Branching Strategy & Source Control

**[ON-SLIDE]**
- **Source control:** Git (GitHub/GitLab/Azure Repos) as single source of truth; **SFDX source format**
- **Model: scaled trunk-based** — short-lived **feature branches** off a project **integration** branch → **release** branch → **main** (mirrors production)
- **Branch mapping to environments:** feature→scratch/dev sandbox · integration→partial/UAT · release→staging/full · main→production
- **Multi-org / multi-SI repo strategy:**
  - Projects **1 & 2** (shared org) → own repos, integrate to a **shared release** line
  - Project **3** (2nd org) → **separate repo/release** line
- **Branch protection:** PR required · ≥1–2 reviewers · **required CI status checks** · no direct commits to `main`
- **Hotfix/emergency flow:** branch from `main` (prod tag) → expedited pipeline → deploy → **back-merge** to integration (no regression)
- **Traceability:** branch/PR named by **work item ID** (feeds governance requirement→feature→evidence)

**[SPEAKER NOTES]**
- Why trunk-based + short-lived branches: minimises long-lived divergence = fewer painful merges = safer parallelism (retires **T1**).
- Why per-project repos: isolates partners, enables **RBAC per repo** (multi-SI security), independent cadence.
- Hotfixes never bypass CI — they take a fast lane, not an unsafe one; back-merge prevents the classic "fix lost in next release" problem.
- Naming convention is the first link in the compliance traceability chain.

**[DIAGRAM]** `bedrock-deploy-slide7-branching.drawio`

---

## Slide 8 — Modularisation & Packaging

**[ON-SLIDE]**
- **Modularise the org into packages by domain**, not one monolith:
  - **Base/shared** package (common objects, utilities) → reused across **both prod orgs**
  - **Project** packages (per partner/feature area) → independent, parallel development
  - **OmniStudio**, **Data 360**, **Agentforce** config handled as their own modules
- **Recommended: Unlocked Packages (2GP)** — versioned, dependency-managed, promotes reuse to the 2nd org
- **Trade-offs**

| Approach | Pros | Cons | Fit for BE |
|---|---|---|---|
| **Unlocked Packages (2GP)** | Modular, versioned, dependency mgmt, enables parallel ownership | Learning curve, some metadata not packageable | **Primary** — new build, multi-org reuse |
| **Org-dependent unlocked pkgs** | Works with existing complex/unpackaged metadata; no full dep resolution | Not version-locked; tied to a target org shape | Bridge for legacy/complex areas |
| **Unpackaged source + Metadata API** | Simple, familiar, flexible | No module boundaries → higher conflict risk | Non-packageable metadata & settings only |

- **Non-packageable metadata** (some Data 360/Agentforce/profiles/settings) → deployed as **unpackaged source** with explicit ordering

**[SPEAKER NOTES]**
- Modularisation is the structural fix for collision (**T1**): clear package ownership = partners rarely touch the same metadata.
- Base package = the reuse mechanism across the two production orgs (project 3 installs the versioned base).
- Be honest about limits: not everything packages cleanly — call out Data 360/Agentforce/profile handling as unpackaged with deploy ordering.
- Trade-off framing shows I know **capabilities and constraints** (a rubric area), not just a single dogmatic answer.

**[DIAGRAM]** `bedrock-deploy-slide8-packaging.drawio`

---

## Slide 9 — Environment Landscape (multi-org + Data 360)

**[ON-SLIDE]**
- **Two production orgs, each with its own sandbox chain** (Org 1 = Projects 1&2; Org 2 = Project 3)
- **Environment tiers & sandbox types**

| Tier | Environment | Purpose | Refresh |
|---|---|---|---|
| Dev | **Scratch orgs** (source-driven) | Per-feature dev + CI validation; ephemeral | Created/destroyed per branch |
| Dev | **Developer sandbox** | Individual config work (no prod data) | On demand |
| Integration | **Developer Pro / Partial Copy** | Integration + **UAT** with sampled prod data | Partial ~5 days |
| Staging | **Full Copy** | Regression, performance, training; prod-like | Full ~29 days |
| Prod | **Production** | Live release target | — |

- **Refresh checklist (post-refresh automation):** mask/seed **PII** (regulated data) · deactivate outbound integrations & email · re-point **Named Credentials/endpoints** to sandbox · reassign permission sets & sample users · re-connect CI/CD service accounts · load managed **test data**
- **Data 360 (Data Cloud) sandbox strategy:** Data Cloud is **not auto-copied** on sandbox refresh → provision Data Cloud in the sandbox, redeploy **data streams / DLOs / DMOs / mappings / segments**, re-point ingestion to **masked/subset** sources, validate identity resolution before promotion
- **Scratch orgs** carry the **shape** (features/settings) so Data 360 & Agentforce metadata validate in CI

**[SPEAKER NOTES]**
- Emphasise **each prod org owns its own path** — no cross-contamination; the shared base package is developed once and installed into both chains.
- Refresh checklist is the antidote to **environment drift (T3)** and protects regulated data (masking).
- Data 360 is the trap: teams assume a refresh copies Data Cloud — it doesn't. Call out cost control by using subsets.
- Full Copy is scarce/expensive → reserve for staging/regression, not day-to-day dev (scratch orgs absorb that load).

**[DIAGRAM]** `bedrock-deploy-slide9-environments.drawio`

---

## Slide 10 — CI/CD Tools & Processes

**[ON-SLIDE]**
- **Pipeline stages (per repo):**
  - **On PR →** static analysis + Apex/LWC unit tests + **security scan** + **validate-only deploy** to a CI scratch org → required checks must pass to merge
  - **On merge to integration →** auto-deploy to **UAT** + run integration/functional tests
  - **On release branch →** deploy to **Staging (Full)** + regression + perf
  - **On tag/main →** deploy to **Production** behind a **manual approval gate**
- **Tooling stack:** Git platform + CI runner (GitHub Actions / GitLab CI / Azure Pipelines) + **Salesforce CLI (`sf`)**; JWT-bearer auth for headless deploys
- **Native vs 3rd-party (trade-offs)**

| Option | Pros | Cons | Fit |
|---|---|---|---|
| **Custom pipeline** (sf CLI + Actions) | Full control, cheap, flexible, git-native | You build/maintain it; needs DevOps skill | **Backbone** for all repos |
| **UI cloud DevOps tool** (Copado / Gearset / DevOps Center) | Fast onboarding, admin-friendly, built-in metadata diff & backup | License cost, less flexible, tool lock-in | Aids **average-skill/offshore** & admins |
- **Component-specific handling:** core = `sf project deploy` · **OmniStudio** = IP/DataPacks with deploy ordering · **Data 360** = metadata deploy + manual provisioning steps · **Agentforce** = Bot/GenAiPlanner/GenAiPlugin metadata (+ activation)
- **AI acceleration:** Agentforce for Developers (code/test gen), AI PR summaries → serves the CTO's AI goal

**[SPEAKER NOTES]**
- Recommend a **hybrid**: custom sf-CLI pipeline as the backbone, a UI tool where it lowers the skill barrier for admins/offshore (retires P3).
- Stress that **every change type has a defined path** — Omni/Data 360/Agentforce are not afterthoughts (retires T2, T7).
- Validate-only on PR = catch failures before they hit an org; monthly cadence needs this gate.

**[DIAGRAM]** `bedrock-deploy-slide10-cicd-pipeline.drawio`

---

## Slide 11 — Security in CI/CD (DevSecOps)

**[ON-SLIDE]**
- **RBAC / least privilege**
  - Repo: branch protection + **CODEOWNERS** per package (multi-SI isolation)
  - **Only the pipeline deploys to Production** — no manual prod deploys; environment **approval gates**
  - Scoped CI **service accounts** (permission sets, not admins)
- **Secrets management**
  - **No secrets in metadata/source** — server key + creds in a **vault** (Actions secrets / Azure Key Vault / HashiCorp Vault)
  - Salesforce auth via **JWT bearer** (key in vault); runtime secrets via **Named/External Credentials**
- **Security scanning (shift-left, gated)**
  - **SAST/SCA:** **Salesforce Code Analyzer** (PMD + Graph Engine DFA → injection, CRUD/FLS) — scenario's *SCQA*
  - **Vulnerability** scanning of dependencies/config
  - **DAST** against a deployed staging org
  - Pipeline **fails on high-severity**; findings + test evidence **attached to the release** (compliance)
- Retires **T4**; directly answers the scenario's RBAC + scans + security-products requirement

**[SPEAKER NOTES]**
- Frame as **DevSecOps, not DevOps** — security is a gate in the pipeline, not a later review.
- The "only the pipeline deploys to prod" rule is the single biggest control for a regulated, multi-SI program.
- Security evidence attached to each release feeds the compliance traceability story in Governance.
- Tie to fixed regulated deadlines: automated scans keep security from becoming a last-minute blocker.

**[DIAGRAM]** `bedrock-deploy-slide10-cicd-pipeline.drawio` (security gates shown inline in red)

---

## Slide 12 — Development Methodology

**[ON-SLIDE]**
- **Recommendation: Scrum per team + light scaled alignment (release train) across partners**
  - **Scrum feature teams** — one per project/partner, **2-week sprints**, **synchronised cadence** so all partners plan/demo on the same rhythm
  - **Scrum-of-Scrums** (program sync) + lightweight **release/PI planning** to align the **monthly release train** and manage cross-project dependencies
  - **Kanban** for the **hotfix/support** lane (continuous flow, not sprint-bound)
- **Shared standards (the equaliser for multi-SI + offshore):**
  - Common **Definition of Ready / Definition of Done** (DoD includes tests written, scans pass, peer-reviewed, docs)
  - Coding standards enforced automatically (Code Analyzer in CI), templates/accelerators
  - **Discovery spikes** for new tech (Data 360, Agentforce) before committing sprint scope
- **Ceremonies:** backlog refinement · sprint planning · daily stand-up · review/demo · retro · program sync
- **Traceability tooling:** Jira / Azure Boards — work item → branch/PR → test evidence (feeds Governance)
- **Trade-offs:** Scrum (predictable cadence, best for feature delivery) vs Kanban (flow, best for support) vs full SAFe (heavy — overkill for 3–5 teams) → **blend, don't over-process**

**[SPEAKER NOTES]**
- The methodology's job here is **alignment across independent partners** without heavyweight process — synchronised sprints + a release train give the CTO the monthly cadence and predictability.
- DoD + automated standards are how we protect quality with **average-skill offshore** teams (retires P2, P3) — quality is enforced by the system, not by hoping.
- Kanban hotfix lane keeps emergencies from disrupting sprint commitments (ties to the branching hotfix flow).
- Why not full SAFe: too much ceremony for 3–5 teams; we take the useful parts (release train, program sync) and skip the overhead.

---

## Slide 13 — QA & Testing Strategy

**[ON-SLIDE]**
- **Test by change type**

| Change type | Primary tests | Automated in CI |
|---|---|---|
| Apex / back-end | Unit tests (≥75%+ meaningful) · Graph Engine (FLS/CRUD) | Yes |
| LWC / front-end | Jest unit · UI/E2E (Selenium/Playwright/Provar) | Yes |
| OmniStudio | Component + E2E flow tests (Provar) | Yes |
| Agentforce | Testing Center (utterance/eval sets) · guardrail checks | Yes |

- **Test data management:** masked/subset prod data · seeded factories in scratch orgs · no real PII in lower envs (regulated)
- **Automation:** run in the pipeline — unit on PR, integration on UAT, regression + perf on Staging
- **Enterprise tooling:** **Provar** (SF-aware regression/E2E) · **Jest** · **Selenium/Playwright** · **Agentforce Testing Center**
- **Summary:** *right test at the right stage, automated and gated — quality is enforced by the pipeline, not by people*

**[SPEAKER NOTES]**
- One line per change type keeps it scannable; the message is **coverage across all four surfaces** (core FE/BE, Omni, Agents).
- Test data management is a compliance point — masked/subset data protects regulated PII (ties to sandbox refresh).
- Provar recommended as the SF-aware enterprise regression tool; Agents get their own eval-based testing (new discipline).
- Retires **T5** (no automation) and P3 (offshore quality).

---

## Slide 14 — Governance

**[ON-SLIDE]**
- **Three governance layers**
  - **Program governance** — Steering Committee (CTO, CIO, Global SF Lead, partner leads) + PMO + **Release Management Board**; owns roadmap, RAID, budget, **weekly board status**
  - **Architecture / technical governance** — **Architecture Review Board (ARB)** chaired by the **Chief Architect**; design authority, standards, package/modularisation decisions, **design-review-before-build**
  - **Data governance** — Data Governance Board; **data model sign-off** (Chief Architect approves before project starts), Data 360 stewardship, quality & PII/compliance
- **Requirement traceability (compliance backbone):** business requirement → design approval → **work item (Jira)** → branch/PR → automated **test + scan evidence** → release notes
- **Multi-SI sandbox & branch security:**
  - **RBAC per repo** (CODEOWNERS) · per-partner **sandbox isolation** · least privilege
  - **Segregation of duties** — only the **pipeline** deploys to Production; audit trail on every promotion
- **Cadence:** sprint (2-wk) · release train (monthly) · ARB (weekly) · steering (bi-weekly) · board (weekly)

**[SPEAKER NOTES]**
- Governance is what makes a **multi-SI** program safe — clear decision rights so partners don't diverge (retires P1, P2).
- Call out the background requirement explicitly: the **Chief Architect must approve the data model before a project begins** — the ARB/Data Board enforce that gate.
- Traceability is the compliance win — every production change traces back to an approved requirement with test evidence (regulated Healthcare/Financial).
- Security of sandboxes/branches: access is role-based and audited; no one hand-deploys to prod.

**[DIAGRAM]** `bedrock-deploy-slide14-governance.drawio`

---

## Slide 15 — Personas & Roles (hiring + business value)

**[ON-SLIDE]**
- **New roles to stand up the program**

| Persona | Stage | New/Existing | Business value |
|---|---|---|---|
| **Program Architect / DevSecOps Lead** | All | **New** | Owns the strategy & standards; single point of technical accountability |
| **Release Manager** | Release | **New** | Runs the monthly release train; coordinates 3 partners; protects fixed dates |
| **DevSecOps / CI-CD Engineer** | Build→Deploy | **New** | Builds & maintains pipelines/automation; removes the "fragmented tooling" bottleneck |
| **QA Automation Engineer** | Test | **New** | Owns test framework & coverage; protects quality with average-skill teams |
| **Data Architect / Data 360 Steward** | Design→Data | **New/Shared** | Data model sign-off; Data Cloud quality & compliance |
| **Security Engineer (AppSec)** | All | **Shared services** | Scans, secrets, RBAC; leverage central Cyber Security team |

- **Existing roles (leverage):** Chief Architect (ARB chair) · partner developers (BE/FE/Omni) · admins & functional consultants · Scrum Masters · business Product Owners
- **Approach:** hire the **program-level enablers** centrally (shared across partners); keep delivery muscle with the partners

**[SPEAKER NOTES]**
- Frame hires as **enablers that unblock the whole program**, not headcount for its own sake — each has a clear ROI line.
- Reuse the background's **shared-services model**: AppSec/security comes from central Cyber Security, not per-project.
- The Release Manager + DevSecOps Engineer are the two most critical net-new hires — they directly enable monthly releases and remove tooling bottlenecks.
- Average-skill offshore risk is mitigated by the QA Automation Engineer + standards, not by hiring more seniors everywhere.

**[DIAGRAM]** *(optional)* persona-to-lifecycle-stage map — can add if useful
