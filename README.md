# Cloud Portfolio Platform

[![Live: jhuntersr.com](https://img.shields.io/badge/Live-jhuntersr.com-0B1120)](https://jhuntersr.com)
![Cloud: AWS](https://img.shields.io/badge/Cloud-AWS-FF9900)
![IaC: Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC)
![CI/CD: GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF)
![Auth: OIDC](https://img.shields.io/badge/Auth-OIDC-2EA44F)
![CDN: CloudFront](https://img.shields.io/badge/CDN-CloudFront-FF9900)
![Security: Gitleaks, Checkov, Trivy, SonarQube](https://img.shields.io/badge/Security-Gitleaks%20%C2%B7%20Checkov%20%C2%B7%20Trivy%20%C2%B7%20SonarQube-D73A49)

## Overview

A production-style personal portfolio site for Jerome Hunter, Senior DevSecOps Cloud Engineer. The project is notable not just as a portfolio page but as a demonstration of the platform itself: three isolated environments, a gated promotion pipeline, short-lived OIDC credentials, and four layers of security scanning on every change. The static site is served from S3 and CloudFront; all infrastructure is defined in Terraform and deployed exclusively through GitHub Actions.

## Architecture

The project is split into three Terraform stacks.

**Bootstrap** provisions the encrypted, versioned S3 bucket used to store remote Terraform state. It runs once and is not touched by the pipeline.

**Identity** manages GitHub OIDC trust and all IAM roles. It is intentionally separate from the site stack so that credential configuration is never mixed with resource configuration. The stack provisions one deploy role per environment and one read-only plan role used by pull requests. Deploy roles carry no IAM permissions and include explicit denies; they are scoped to their own environment's S3 bucket and Route 53 hosted zone. The OIDC trust condition matches GitHub's immutable owner and repository ID fields in the `sub` claim, which also protects against repository-hijacking attacks.

**Site** is environment-aware and uses partial backend configuration to select the correct state file. It provisions an S3 origin bucket, a CloudFront distribution with an Origin Access Control, a custom static cache policy, a response-headers policy with a strict Content Security Policy that also strips origin-identifying headers, an ACM certificate with DNS validation, and Route 53 alias records. TLS 1.2 is the minimum protocol version. Resources are named per environment, and the production bucket uses a create-before-destroy lifecycle rule for zero-downtime cutover.

## CI/CD Pipeline

The pipeline has two workflows. The main workflow runs on every push to `main`, every pull request targeting `main`, and on manual dispatch.

**Security checkpoint** runs first on all triggers. It executes Gitleaks with full commit history to detect leaked secrets, Checkov against the Terraform directory for infrastructure misconfigurations, Trivy for vulnerable packages, secrets, and misconfigurations (pinned to a full commit SHA because version tags for this action were hijacked in a March 2026 supply-chain attack), and an ephemeral SonarQube scan. The SonarQube job spins up a throwaway Community server as a service container pinned by image digest, waits for readiness, immediately replaces the default admin password with a randomly generated one, creates a one-time analysis token, runs the scanner, and then prints the quality gate status, issues, and security hotspots before the container is discarded.

**Pull requests** trigger a parallel read-only `terraform plan` across all three environments using the scoped plan role. The plan role cannot acquire a state lock, which prevents any accidental mutation.

**Merges to main** run a sequential promotion: dev applies first, test applies after dev succeeds, and prod waits for manual approval before applying. Each environment authenticates to AWS using its own short-lived OIDC role; no long-lived credentials exist anywhere in the pipeline.

## Security Design

- GitHub OIDC with immutable owner/repo ID matching in the trust policy; no static AWS credentials
- Per-environment deploy roles with no IAM permissions and explicit denies, scoped to named resources
- Separate read-only plan role that cannot lock or modify state
- Gitleaks on full commit history at every trigger
- Checkov for Terraform misconfiguration scanning
- Trivy pinned by commit SHA following a documented tag-hijacking incident
- Ephemeral SonarQube server with immediate password rotation and a one-time token; server is destroyed after each run
- S3 bucket accessible only through CloudFront via Origin Access Control; no public bucket policy
- Strict Content Security Policy delivered via CloudFront response-headers policy; `img-src` is limited to `'self'`, which is why certification badge images are self-hosted rather than loaded from Credly
- TLS 1.2 minimum on all CloudFront distributions
- S3 lifecycle rules on all buckets (satisfies Checkov rule CKV2_AWS_61)
- Terraform state encrypted and versioned in a dedicated bootstrap bucket

## Environments and Domains

| Environment | Domain |
|---|---|
| dev | dev.jhuntersr.com |
| test | test.jhuntersr.com |
| prod | jhuntersr.com, www.jhuntersr.com |

Each environment has its own ACM certificate, DNS validation records, CloudFront distribution, S3 bucket, OIDC deploy role, and Terraform state file.

## Certifications

- AWS Certified Solutions Architect – Associate (Amazon Web Services), verified on Credly
- HashiCorp Certified: Terraform Associate (003), verified on Credly

## Key Engineering Decisions

- **Separate identity stack**: Decouples credential infrastructure from site resources, allows the OIDC provider to be imported or removed independently, and prevents accidental destruction of IAM roles during site changes.
- **Trivy pinned by commit SHA**: Version tags for the action were hijacked in March 2026; pinning to a SHA is the only reliable supply-chain control for this dependency.
- **Ephemeral SonarQube**: Avoids maintaining a persistent server or paying for a hosted tier. The server exists only for the duration of the scan job.
- **Self-hosted badge images**: The strict `img-src 'self'` CSP blocks external image sources, including Credly's embed script, so badge images are checked into the repository.
- **Immutable ID OIDC trust**: Matching GitHub's owner and repository numeric IDs rather than names prevents a renamed or re-created repository from inheriting the trust relationship.
- **create-before-destroy on the production bucket**: Allows the bucket to be renamed or replaced without a destroy-first outage window.

## Timeline

All work was completed over four days, from initial commit on 2026-10-01 through the final merged pull request on 2026-10-04, across 13 pull requests.

## About this README

This write-up is generated by a private AI reporting agent running on Amazon Bedrock
(Anthropic Claude), then reviewed by a human before it is merged. The agent's source
code is kept private.

**Security controls**

- **Data minimization and redaction:** account IDs, ARNs, access key IDs, and email
  addresses are removed before any data leaves the machine.
- **Prompt-injection mitigations,** following the OWASP Top 10 for LLM Applications
  (LLM01: Prompt Injection): repository content is passed to the model as clearly
  delimited, untrusted data; input is screened for common injection patterns; and the
  model has no tools or permissions, so it can only return text.
- **Output validation:** the agent refuses to save output containing sensitive patterns,
  images, embedded HTML, or links outside an approved list.
- **Human review:** every version goes through a pull request and this repository's
  security scanners before publication.

As with any LLM application, prompt-injection risk can be reduced but not eliminated;
these layered controls and human review are the safeguards.
