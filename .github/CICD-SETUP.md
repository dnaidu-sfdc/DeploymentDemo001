# CI/CD Setup — Bedrock DevSecOps Demo

This repo has two GitHub Actions workflows:

| Workflow | Trigger | What it does | Requirement |
|---|---|---|---|
| `pr-validate.yml` | PR → `main` | Code Analyzer scan + **check-only** deploy that runs Apex tests (nothing written to org) | R13 "basic quality checks" |
| `deploy.yml` | push/merge → `main` | Deploys `demo-app` to the target org + runs Apex tests | R13 "auto-deployed to an org from the repo" |

Both authenticate headlessly with the **JWT bearer flow** (no interactive login, no password in CI).

---

## 1. Create a Connected App (in the target org)

Setup → App Manager → **New Connected App**:

- **Enable OAuth Settings** = on
- **Callback URL**: `http://localhost:1717/OauthRedirect` (unused by JWT, but required)
- **Use digital signatures** = on → upload `server.crt` (see step 2)
- **OAuth Scopes**: `Manage user data via APIs (api)`, `Perform requests at any time (refresh_token, offline_access)`
- Save, then **Manage → Edit Policies → Permitted Users = "Admin approved users are pre-authorized"**, and assign a permission set / profile that includes the integration user.
- Copy the **Consumer Key** (this is `SF_CONSUMER_KEY`).

## 2. Generate the certificate + key (locally)

```bash
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/CN=BedrockCICD"
```

- Upload `server.crt` to the Connected App (step 1).
- `server.key` stays local — it is **gitignored** (`*.key`) and must never be committed.

## 3. Add GitHub repository secrets

Repo → Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `SF_CONSUMER_KEY` | Consumer Key from the Connected App |
| `SF_USERNAME` | Integration/deploy username (e.g. your admin or a dedicated CI user) |
| `SF_INSTANCE_URL` | `https://login.salesforce.com` (prod/dev-hub) or `https://test.salesforce.com` (sandbox) |
| `SF_JWT_KEY` | **base64** of `server.key` (see below) |

Encode the key so newlines survive as a single-line secret:

```bash
# macOS/Linux
base64 -i server.key | pbcopy
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("server.key")) | Set-Clipboard
```

Paste the result as `SF_JWT_KEY`. The workflows run `base64 --decode` to restore it.

## 4. Test locally first

```bash
sf org login jwt --client-id <CONSUMER_KEY> --jwt-key-file server.key \
  --username <SF_USERNAME> --instance-url https://login.salesforce.com
```

If that succeeds, CI will too.

---

## Notes
- The pipeline targets the `demo-app` package directory only (the isolated 2GP module).
- `--severity-threshold 2` fails the PR build on high-severity Code Analyzer findings (the security/quality gate from Slides 10–11).
- For a production target, switch `--test-level` to `RunLocalTests`.
