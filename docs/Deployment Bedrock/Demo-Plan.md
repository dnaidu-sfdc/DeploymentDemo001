# Bedrock — DevSecOps Demo Plan (planning only)

> Purpose: plan the live/recorded end-to-end CI/CD walkthrough for the badge demo.
> Maps to demo requirements **R12–R14**. Uses **this org + repo** (already has Apex + Flow + tests).

## Build status
- [x] **Phase A metadata built** (local): `Deployment_Demo__c` object + fields (Status, Notes, Amount, Processed), tab, `DeploymentDemoService` Apex + test (bulk-safe, 3 tests), record-triggered Flow `Bedrock_Deployment_Demo_Process` (calls the Apex), permission set `Bedrock_Deployment_Demo`. Apex passes lint.
- [x] **Deploy to scratch org + assign perm set + smoke test** — DONE on `test-luzuqcoxbcjg@example.com`: 10/10 components deployed (Succeeded, Deploy ID `0AfIo000006iAEaKAM`), perm set assigned, **3/3 Apex tests pass (100%)**.
- [ ] Phase B — Git repo + branches
- [ ] Phase C — 2GP package
- [ ] Phase D — GitHub Actions CI/CD
- [ ] Phase E — walkthrough rehearsal

---

## 1. What the demo must prove (from the scenario)

| Req | Requirement | How we satisfy it |
|---|---|---|
| **R12** | Simple app: ≥1 **Custom Object** + **Apex** + **Flow** + **permissions** | Add a Custom Object + Permission Set; reuse existing Apex + `Bedrock_Create_Order` Flow |
| **R13** | In **version control**, **basic quality checks**, **auto-deployed to an org from the repo** | GitHub repo + GitHub Actions (validate on PR, deploy on merge) |
| **R14** | Walk through **org → VCS**, checks chosen, **auto-deploy to another org**, show **metadata in VCS**; best-practice **SFDX source format**; 2GP packaging | Show `sf` retrieve, Actions logs, 2GP package version install into a 2nd org, repo tree |

---

## 2. Current assets vs gaps

**Have (reuse):**
- SFDX project (`sfdx-project.json`), `force-app` source format
- Apex: `ProcessLauncherController` (+ test), `IndirectAccountController` (+ test), others
- Flow: `Bedrock_Create_Order`
- Custom Metadata Type: `Process_Action__mdt`

**Gaps to fill before demo:**
1. **Custom Object** — add a simple `Deployment_Demo__c` (or similar) with 2–3 fields, so R12's "Custom Object" is unambiguous (CMDT alone is risky).
2. **Permission Set** — add `Bedrock_Deployment_Demo` granting object + Apex/tab access (R12 "permissions").
3. **GitHub repo** — create and push (currently local only; no `.github/`).
4. **2GP unlocked package** — register a package + create a version in `sfdx-project.json`.
5. **CI/CD workflows** — `.github/workflows/` for validate (PR) + deploy (merge).
6. **Auth for CI** — JWT bearer flow (server key as GitHub secret) to a dev/UAT org (+ optional 2nd org).

---

## 3. Tools

- **Salesforce CLI (`sf`)** — retrieve/deploy/package
- **Git + GitHub** — source of truth + GitHub Actions runner
- **Salesforce Code Analyzer** (`sf scanner`/`code-analyzer`) — the "basic quality check"
- **JWT bearer auth** — headless CI login (connected app + server cert, key in GH secrets)
- (Optional) a **second scratch/dev org** to demonstrate cross-org package install

---

## 4. Step-by-step plan

### Phase A — Make the app demo-ready (local)
1. Create `Deployment_Demo__c` custom object + fields (e.g., `Status__c`, `Notes__c`).
2. Create permission set `Bedrock_Deployment_Demo` (object + Apex class access).
3. Confirm Apex + Flow + object all retrievable in `force-app` source format.
4. Add/verify a meaningful Apex unit test (already have tests → ensure ≥75% and green).

### Phase B — Version control
5. `git init` (if needed), add `.gitignore` (SFDX default), commit, create GitHub repo, push `main`.
6. Create `develop`/integration + a `feature/*` branch to demonstrate the branch model.
7. Add branch protection on `main` (PR + required status check).

### Phase C — 2GP packaging
8. In `sfdx-project.json`: define an **unlocked package** (`Bedrock Demo`), set `packageDirectories`.
9. `sf package create` → `sf package version create` → note the version id.
10. (Show) install the package version into a **second org** to prove modular, versioned cross-org deploy.

### Phase D — CI/CD (GitHub Actions)
11. `.github/workflows/pr-validate.yml` — on PR: auth (JWT) → **Code Analyzer scan** → `sf project deploy start --dry-run` (validate-only) → run Apex tests.
12. `.github/workflows/deploy.yml` — on merge to `main`: auth → `sf project deploy start` to the target org (and/or `sf package version promote` + install).
13. Store secrets: `SF_JWT_KEY`, `SF_CONSUMER_KEY`, `SF_USERNAME`, `SF_INSTANCE_URL`.

### Phase E — The walkthrough narrative (what to show & say)
14. Show the **repo tree** → metadata in SFDX source format (R14 "show metadata in VCS").
15. Make a small change on a `feature/*` branch → open PR → show **Actions running checks** (scan + validate + tests) → merge.
16. Show **deploy workflow** auto-deploying to the org from the repo (R13).
17. Show the **2GP package version** installed into the **second org** (R14 multi-org).
18. Tie back to slides: branch model (7), pipeline (10), security gates (11), traceability (14).

---

## 5. Demo risks & mitigations
- **JWT/connected-app setup fiddly** → pre-configure before the session; have a recorded fallback.
- **Package version create is slow** → pre-create the version; show install live.
- **Org limits/deploy time** → keep the change small (one field or one line of Apex).
- **Secrets exposure** → use GH encrypted secrets; never echo them in logs (demonstrates R10/secrets hygiene).

---

## 6. Open decisions (confirm before building)
- Target org(s): use **this org** as the deploy target + a **scratch org** as the "second org"? Or two persistent orgs?
- CI runner: **GitHub Actions** (assumed) vs alternative.
- Keep the demo app as the **Process Launcher** feature, or a fresh minimal `Deployment_Demo__c` slice? (Recommend: add the small custom object + perm set and keep it minimal for a clean demo.)
