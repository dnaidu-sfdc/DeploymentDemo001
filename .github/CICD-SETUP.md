# CI/CD Setup — Bedrock DevSecOps Demo

Source-based pipeline that satisfies the badge requirement: **version control →
basic quality checks → automatic deploy to a Salesforce org from the repo.**

## The flow

```
feature/* push ─► [auto-pr] opens PR + enables auto-merge
                          │
                    reviewer approves
                          │
        [pr-validate] create scratch org → Code Analyzer scan → deploy → Apex tests → delete org
                          │  (required status check)
                    auto-merge to main
                          │
        [deploy] deploy demo-app source → AFCAPQQA1 sandbox → run Apex tests
```

| Workflow | Trigger | Does |
|---|---|---|
| `auto-pr.yml` | push to `feature/**` | Opens a PR into `main`, enables auto-merge |
| `pr-validate.yml` | PR **approved** | Ephemeral scratch org: scan + deploy + Apex tests (the quality gate) |
| `deploy.yml` | push/merge to `main` | Deploys `demo-app` to the **AFCAPQQA1** sandbox + runs tests |

Both org-touching workflows authenticate headlessly with the **JWT bearer flow**.

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

- Settings → General → Pull Requests → **Allow auto-merge** = on
- Settings → Branches → **Branch protection rule** for `main`:
  - Require a pull request before merging · **Require 1 approval**
  - **Require status checks to pass** → add **`Scratch-org quality gate`** (the `pr-validate` job)

With those on: approve the PR → the gate runs in a scratch org → on green, GitHub auto-merges → `deploy.yml` ships to AFCAPQQA1.

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
# → PR opens automatically; approve it in the GitHub UI and watch the Actions tab.
```
