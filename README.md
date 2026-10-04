# Cloud Portfolio Platform

[![Live: jhuntersr.com](https://img.shields.io/badge/Live-jhuntersr.com-0B1120)](https://jhuntersr.com)
![Cloud: AWS](https://img.shields.io/badge/Cloud-AWS-FF9900)
![IaC: Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC)
![CI/CD: GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF)
![Auth: OIDC](https://img.shields.io/badge/Auth-OIDC-2EA44F)
![CDN: CloudFront](https://img.shields.io/badge/CDN-CloudFront-FF9900)
![Security: Gitleaks, Checkov, Trivy, SonarQube](https://img.shields.io/badge/Security-Gitleaks%20%C2%B7%20Checkov%20%C2%B7%20Trivy%20%C2%B7%20SonarQube-D73A49)

## Overview

A production-style personal portfolio site for Jerome Hunter, Senior DevSecOps Cloud Engineer. The site itself is the project: a static HTML page served from AWS S3 and CloudFront, built and deployed through a security-gated GitHub Actions pipeline across three isolated environments. Every engineering decision—OIDC trust, scanner pinning, CSP headers, least-privilege roles—is deliberate and documented in the commit history.

## Architecture

The infrastructure is split into three Terraform stacks:

- **Bootstrap** — an encrypted, versioned S3 bucket that holds remote Terraform state.
- **Identity** — a shared stack that provisions the GitHub OIDC provider, per-environment deploy roles, a read-only PR plan role, and the IAM permissions each role needs (ACM, Route 53, scoped to its own environment's resource names). No role carries IAM permissions.
- **Site** — an environment-aware stack that provisions an S3 origin bucket, a CloudFront distribution with Origin Access Control (OAC), a custom static cache policy, a response-headers policy with a strict Content Security Policy, an ACM certificate with DNS validation, and Route 53 alias records.

Each environment has its own S3 backend configuration, its own Terraform variable file, and its own named resources.

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/deploy.yml` and a reusable `apply-env.yml` workflow.

**On every push and pull request:**

1. **Security checkpoint** (runs first, blocks everything downstream):
   - **Gitleaks** scans the full commit history for leaked secrets.
   - **Checkov** scans all Terraform for misconfigurations (`soft_fail` so findings are visible without blocking).
   - **Trivy** scans for vulnerabilities, secrets, and misconfigurations at HIGH and CRITICAL severity. Pinned to a full commit SHA because version tags for this action were hijacked in a March 2026 supply-chain attack.
   - **SonarQube** runs as an ephemeral service container pinned by image digest. The pipeline waits for the server to reach `UP`, immediately rotates the default admin password to a random value, creates a one-time analysis token, runs the scanner (also pinned by digest), then prints the quality gate status, issues, and security hotspots.

**On pull requests** (after the security checkpoint passes):

- A matrix plan job runs `terraform plan` for all three environments simultaneously using the read-only plan role. The plan role cannot acquire a state lock.

**On merges to main:**

- `dev` deploys automatically.
- `test` deploys after `dev` succeeds.
- `prod` deploys after `test` succeeds and requires manual approval.

All deploy jobs assume their environment's OIDC role. The default workflow permission is `contents: read`; `id-token: write` is granted only to jobs that need it.

## Security Design

| Control | Implementation |
|---|---|
| Short-lived credentials | GitHub OIDC; no long-lived access keys anywhere |
| Repojacking protection | OIDC trust policy matches GitHub's immutable owner and repo ID fields in the `sub` claim |
| Least privilege | Per-environment roles scoped to their own S3 buckets and domain names; no role has IAM permissions |
| Read-only PR role | Separate plan role with explicit denies on mutating actions; cannot lock state |
| Secret scanning | Gitleaks on full history at every run |
| IaC scanning | Checkov on every run |
| Dependency and filesystem scanning | Trivy pinned by commit SHA |
| Static analysis | Ephemeral SonarQube pinned by image digest; admin password rotated before use; one-time token |
| Origin protection | CloudFront OAC; S3 bucket not publicly accessible |
| Transport security | TLS 1.2 minimum (`TLSv1.2_2021` policy) on all environments |
| Response headers | Custom CloudFront headers policy with strict CSP; origin-identifying headers stripped |
| State security | Remote state in an encrypted, versioned S3 bucket |
| Supply-chain hygiene | Scanner actions pinned by SHA or digest after observed tag-hijack incident |

The CSP allows `img-src 'self'` only, which is why certification badge images are self-hosted rather than loaded from Credly's CDN.

## Environments and Domains

| Environment | Domain(s) | Purpose |
|---|---|---|
| dev | `dev.jhuntersr.com` | Automatic deploy on every merge to main |
| test | `test.jhuntersr.com` | Promotes automatically after dev succeeds |
| prod | `jhuntersr.com`, `www.jhuntersr.com` | Promotes after test; requires manual approval |

Each environment has its own ACM certificate with DNS validation and Route 53 A/AAAA alias records.

## Certifications

- **AWS Certified Solutions Architect – Associate** (Amazon Web Services) — verified on Credly
- **HashiCorp Certified: Terraform Associate (003)** (HashiCorp) — verified on Credly

## Key Engineering Decisions

**OIDC over access keys.** All pipeline credentials are short-lived tokens assumed via GitHub OIDC. The trust policy matches immutable owner and repository ID fields, not mutable names, to prevent repojacking from granting a new owner access to the role.

**Three Terraform stacks.** Bootstrap, identity, and site are separated so that state infrastructure and IAM trust are never destroyed by a routine site change. The identity stack can be applied once and shared across all environment deploys.

**Scanner pinning by SHA/digest.** After observing that `trivy-action` version tags were hijacked in March 2026, all third-party scanner steps are pinned to immutable references (commit SHAs for GitHub Actions, image digests for Docker images).

**Ephemeral SonarQube.** Running SonarQube as a throwaway service container avoids maintaining a persistent server while still producing quality gate results and a hotspot report on every change. The default password is rotated immediately and a one-time token is used for the scan.

**`create_before_destroy` for prod bucket cutover.** The prod S3 bucket uses a `create_before_destroy` lifecycle rule so that a rename or replacement does not cause downtime by deleting the origin before its replacement exists.

**Self-hosted badge images.** The strict `img-src 'self'` CSP would block externally hosted badge images. Badge PNGs are committed to the repository and served from the same origin.

## Timeline

| Date | Milestone |
|---|---|
| 2026-10-01 | Initial portfolio page; moved into `site/` directory; `.gitignore` for state and secrets |
| 2026-10-02 | Terraform bootstrap (encrypted state bucket); S3 + CloudFront infrastructure with OAC and security headers |
| 2026-10-03 | GitHub OIDC trust and deploy role; CI/CD pipeline with Gitleaks, Checkov, and OIDC deploy (PR #1); OIDC trust hardened to immutable IDs (PR #2); Checkov hardening with lifecycle rules and custom CloudFront policies (PR #4); identity split into its own stack; dev/test/prod promotion pipeline with per-environment roles and read-only plan role (PR #5); old shared deploy role retired (PR #6) |
| 2026-10-04 | Trivy scan added, pinned by commit SHA (PR #7); ephemeral SonarQube scan added (PR #8); custom domains with ACM, DNS validation, and Route 53 aliases for all three environments (PR #9); Cloud Portfolio Platform project card added (PR #10); AWS SAA and Terraform Associate Credly badges added as self-hosted images (PR #11); Contact section linked directly to this repository (PR #12) |
