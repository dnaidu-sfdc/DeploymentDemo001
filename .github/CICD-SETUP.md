# CI/CD Setup — Bedrock DevSecOps Demo

Source-based pipeline that satisfies the badge requirement: **version control →
basic quality checks → automatic deploy to a Salesforce org from the repo.**

## The flow

```
feature/* push ─► [auto-pr] opens PR into main
                          │
        [pr-validate] Code Analyzer scan → check-only (validate) deploy + Apex tests
                          │  (required status check, runs against AFCAPQA1)
                    gate green → click "Merge" in GitHub
                          │
        [deploy] deploy demo-app source → AFCAPQA1 sandbox → run Apex tests
```

| Workflow | Trigger | Does |
|---|---|---|
| `auto-pr.yml` | push to `feature/**` | Opens a PR into `main` |
| `pr-validate.yml` | push to `feature/**` | Quality gate: Code Analyzer scan + **check-only** deploy + Apex tests against **AFCAPQA1** (nothing written to the org) |
| `deploy.yml` | push/merge to `main` | Deploys `demo-app` to the **AFCAPQA1** sandbox + runs tests |

All org-touching workflows authenticate headlessly with the **JWT bearer flow**.

> Note: the gate runs on the **push** event (not the PR event) so it fires reliably even though `auto-pr` opens the PR with the Actions token. The merge is a **manual one-click** in the GitHub UI — a token-driven auto-merge would not trigger `deploy.yml`.

---

## 1. Generate one certificate + key (reused by both connected apps)

```bash
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=BedrockCICD"
```

- `server.key` stays local — it is **gitignored** (`*.key`); never commit it.
- Upload `server.crt` to BOTH connected apps below.

## 2. Connected App in the Dev Hub (`AFCAPPRODDevHub`) — lets CI create scratch orgs

Setup → App Manager → **New Connected App**:
- Enable OAuth · Callback `http://localhost:1717/OauthRedirect`
- **Use digital signatures** → upload `server.crt`
- Scopes: `api`, `refresh_token offline_access`
- Manage → **Admin approved users are pre-authorized**; assign your user
- Copy the **Consumer Key** → secret `SF_DEVHUB_CONSUMER_KEY`

## 3. Connected App in the AFCAPQQA1 sandbox — lets CI deploy there

Same steps as above, in the **AFCAPQQA1** org. Copy its Consumer Key → `SF_SANDBOX_CONSUMER_KEY`.

## 4. GitHub repository secrets

Repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `SF_JWT_KEY` | **base64** of `server.key` (shared by both) |
| `SF_DEVHUB_CONSUMER_KEY` | Consumer Key from the Dev Hub connected app |
| `SF_DEVHUB_USERNAME` | your Dev Hub username |
| `SF_SANDBOX_CONSUMER_KEY` | Consumer Key from the AFCAPQQA1 connected app |
| `SF_SANDBOX_USERNAME` | your AFCAPQQA1 username (e.g. `...@salesforce.com.afcapqqa1`) |

Encode the key as one line:

```bash
# macOS/Linux
base64 -i server.key | pbcopy
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("server.key")) | Set-Clipboard
```

## 5. Repo settings that make auto-merge + the gate work

- Settings → Actions → General → Workflow permissions → **Allow GitHub Actions to create and approve pull requests** = on (required for `auto-pr.yml`)
- Settings → Branches → **Branch protection rule** for `main`:
  - Require a pull request before merging
  - **Require status checks to pass** → add **`Scratch-org quality gate`** (the `pr-validate` job)
  - No approval requirement (single-owner repo — GitHub blocks approving your own PR, so the automated quality gate is the merge gate)

With those on: push a `feature/*` branch → PR opens automatically → the gate runs → on green the **Merge** button unlocks → click it → `deploy.yml` ships to AFCAPQA1.

---

## 6. Test JWT locally first

```bash
sf org login jwt --client-id <DEVHUB_CONSUMER_KEY> --jwt-key-file server.key \
  --username <SF_DEVHUB_USERNAME> --instance-url https://login.salesforce.com
```

If that succeeds, CI will too.

## Demo run

```bash
git checkout -b feature/demo-change
# make a small edit in demo-app/ ...
git commit -am "demo: tweak" && git push -u origin feature/demo-change
# → PR opens automatically; the gate runs on the push (Actions tab).
# → when the "Scratch-org quality gate" check is green, click Merge in the PR.
# → the merge triggers deploy.yml, which deploys demo-app to AFCAPQA1.
```
