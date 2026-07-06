# Bedrock Deployment Demo

A minimal Salesforce app used to demonstrate an end-to-end DevSecOps workflow:
**org → version control → automated quality gate → auto-deploy → modular 2GP packaging.**

## What's in the module (`demo-app/`)

| Component | Name | Purpose |
|---|---|---|
| Custom Object | `Deployment_Demo__c` | Demo record (Status, Notes, Amount, Processed) |
| Apex | `DeploymentDemoService` | Invocable, bulk-safe "mark processed" logic + unit tests |
| Flow | `Bedrock_Deployment_Demo_Process` | Record-triggered; calls the Apex |
| Permission Set | `Bedrock_Deployment_Demo` | Grants object/field/tab/Apex access |

Everything is in **SFDX source format** and packaged as an **Unlocked Package (2GP)**:
`Bedrock Deployment Demo` (see `sfdx-project.json`).

## CI/CD (`.github/workflows/`)

| Workflow | Trigger | Does |
|---|---|---|
| `pr-validate.yml` | PR → `main` | Code Analyzer scan + check-only deploy running Apex tests |
| `deploy.yml` | push → `main` | JWT auth + deploy `demo-app` + run Apex tests |

Setup (Connected App + JWT + GitHub secrets): see [`.github/CICD-SETUP.md`](.github/CICD-SETUP.md).

## Quick start

```bash
# Deploy to a scratch org / sandbox
sf project deploy start --source-dir demo-app
sf org assign permset --name Bedrock_Deployment_Demo
sf apex run test --class-names DeploymentDemoServiceTest --result-format human

# Build a package version (requires a Dev Hub)
sf package version create --package "Bedrock Deployment Demo" \
  --installation-key-bypass --code-coverage --wait 30
```
