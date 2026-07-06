# Bedrock — Development Lifecycle & Deployment (DevSecOps) Badge

## Requirements List

> Source: `Bedrock Scenario - Development Lifecycle and Deployment - 2025.pdf` + `Bedrock Enterprises - Background (1).pdf` + `Bedrock Deployment Presentation.pdf` (template).
> This document only captures **what must be solved**. Solutioning is done separately, area by area.

---

## 0. Format & audience (constraints on the deliverable)

| Item | Detail |
|---|---|
| **Deliverable** | A **presentation** (~15 slides) + a **live/recorded end-to-end CI/CD demo** |
| **Timing** | 30 min present · 20 min Q&A · 10 min feedback |
| **Audience** | **CTO, program management, release management** |
| **Reference material** | DevSecOps material on Services Central + DevSecOps Strategy template pack |
| **Assumptions** | Where requirements are not explicit, use best judgment + Bedrock Overview (Domain Zero); **state assumptions**; no clarifying questions allowed |
| **Scoring** | **10 rubric areas, equally weighted (10% each)** — see mapping below |

---

## 1. Business & program context (the "givens" we must design around)

- **CTO-sponsored pilot**; CTO reports **weekly to the board**; must prove **no bottlenecks** and that **ROI meets expectations**.
- **Speed is key**: target **monthly production releases** and adoption of **cutting-edge AI tooling** to accelerate development.
- Deliver a **12-month DevSecOps roadmap** enabling sustainable delivery of **3 projects** now, scaling to **3–5 projects in parallel**.
- **Multiple partners (multi-SI)**: each of the 3 projects is **built and managed by a different partner**, **in parallel**.
- **Org strategy (given)**: projects **1 & 2 → shared production org**; project **3 → a second production org** (customer multi-org strategy).
- **Regulated** (Healthcare + Financial): **release timelines are fixed and cannot be moved**; parallel runs are mandatory.
- **Team composition**: mixed — onshore skilled + **average-skill offshore**; back-end devs, front-end devs, functional consultants, admins.
- **Solution surface spans**: **core Salesforce + OmniStudio + Data 360 + Agentforce** (Agentforce = internal, employee-facing agent over internal data sources).
- **Given (already advised)**: Org strategy and Data strategy (Data 360 to unify customer profile) are already decided — we build the **delivery lifecycle** around them.

### Stated challenges to explicitly address
- Projects delivered/managed by different end partners
- Lack of specific DevSecOps skills within the program
- No program management in place
- No aligned project timeline
- Fragmented or no tools and automation in use
- Conflicting development work + different standards from multiple developers
- Unclear environments with no wider strategy
- Uncertainty deploying newer tech (Data 360, Agentforce)
- Low adoption of AI tooling for dev/deploy acceleration
- Poor security practices: secrets management, deployment permissions, security scans

---

## 2. Requirements to solve

### A. Advisory / presentation requirements

| # | Requirement | Rubric area |
|---|---|---|
| **R1** | **Introduction & problem framing** — build rapport, outline the problem and the value of solving it, targeted to CTO/board. | Introduction (10%) |
| **R2** | **Business requirements & risk identification** — identify business requirements and needs; enumerate **project risks, technical risks, and their impact**. | Requirements & risks (10%) |
| **R3** | **Phased 12-month DevSecOps roadmap** — deliver the recommendations in phases with milestones. | Roadmap (10%) |
| **R4** | **Branching & modularisation strategy** — emphasise **parallelisation** across 3–5 concurrent projects; include **hotfix/emergency** handling; discuss **packaging approaches** (e.g., unlocked/2GP/unpackaged) in a **multi-org** environment. | Branching & modularisation (10%) |
| **R5** | **Environment management & deployment strategy** — multi-org environment landscape; **sandbox type recommendations**, **refresh checklist**, and a specific **Data 360 sandbox strategy**. | Environment mgmt & deployment (10%) |
| **R6** | **Tool capabilities & constraints** — recommend enterprise CI/CD tooling based on industry best practice; describe **trade-offs of native vs 3rd-party** deployment tools (custom-built pipeline vs UI-based cloud deploy tool); cover how **core + OmniStudio + Data 360 + Agentforce** flow through CI/CD. | Tools capabilities/constraints (10%) |
| **R7** | **Development methodology** — appropriate methodology for a mixed-skill, multi-partner, onshore/offshore program. | Dev methodology (10%) |
| **R8** | **QA / testing strategy** — mitigate project-specific risks; include **test data management**, test strategies **per change type** (core front-end + back-end, OmniStudio, Agents), **test automation**, and **enterprise test product** recommendations. | Testing strategy (10%) |
| **R9** | **Governance** — **program**, **technical/architecture**, and **data** governance; **requirement traceability** (business requirement → built feature → test evidence); and in a **multi-SI** setup, how **sandboxes & branches are secured, governed, and access-controlled**. | Governance (10%) |
| **R10** | **Security in CI/CD** — embed **RBAC**, **secrets management**, and **security scanning** using Salesforce security products (**Code Analyzer/SCA, vulnerability scans, DAST**). | (Woven into Tools/Governance; scenario-mandated) |
| **R11** | **Personas** — define personas required at each lifecycle stage, with **hiring recommendations** and the **business value** of each new role. | (Woven into Roadmap/Governance) |

### B. Technical demo requirement (the "implement & demonstrate" 10%)

| # | Requirement | Rubric area |
|---|---|---|
| **R12** | Build a **simple Salesforce app**: at least **one Custom Object**, **some Apex**, and a **Flow**, plus the **permissions** (permission set) to access the functionality. | Implement & demo (10%) |
| **R13** | Manage the work in **version control**, subject to **basic quality checks**, and **automatically deployed to a Salesforce org from the repository** (end-to-end CI/CD). | Implement & demo (10%) |
| **R14** | Be able to **walk through**: moving changes from an **org → version control**, **which checks** were chosen, how an **automated deployment to another org** works, and **showcase the metadata stored in version control**. Use **best-practice source format** (SFDX project, unpackaged or packaged) with any Metadata API client (SFDX CLI, VS Code SFDX extensions). | Implement & demo (10%) |

---

## 3. Recommended presentation sequence (from the scenario)

1. Introduction
2. Challenges and risks
3. DevSecOps Phased Roadmap
4. Branching Strategy and Source Control
5. Environment Landscape
6. CI/CD tools and processes
7. Development methodologies
8. QA strategy
9. Governance
10. Demo / Walkthrough

---

## 4. Diagrams the presentation must include (per template)

- Governance bodies / structure
- Governance implementation roadmap
- Sandbox landscape (multi-org)
- Source control repository / branching model
- Lifecycle flows (with key personas)
- Test automation tools
- CI mechanisms
