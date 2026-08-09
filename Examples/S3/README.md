# Threat Modeling Study Guide
## A Practical, Worked Case: The Publicly Exposed S3 Bucket

**Version 8 · Multi-file edition**

A study guide that teaches threat modeling theory and applies every technique to one continuous, realistic case — a customer-data S3 bucket at a fictional retailer. Theory generalizes; the case shows you what application actually looks like.

> **New in v8.** A full **actor catalog** (12 actors/adversaries with means/motive/opportunity, [04 §4.5b](04-dfd-library.md)); the **compute/IMDS** and **KMS key-access** planes the earlier model structurally couldn't hold ([04 §4.16a–d](04-dfd-library.md)); STRIDE **components 6–8 → 68 threats** ([06](06-stride.md)); attack **Trees 5–9 plus an APT kill-chain** ([08](08-attack-trees-capec.md)); the **ENC-1…8 cryptographic-exploit findings** and **F-13…F-20** ([A](A-findings-register.md)); LINDDUN **P-07…P-09** ([07](07-linddun-privacy.md)); four new **sequence diagrams** ([05](05-other-model-types.md)); and a **KMS exploit→control map** ([13 §13.7](13-hardening-deep-dive.md)). This closes the v7 limitations on the partner integration and the missing CI/CD sequence diagram, and adds the compute/IMDS **SSRF** surface (which is **A01:2025**, not A10). The A10:2025 gap — *Mishandling of Exceptional Conditions* — stays open, though the crypto fail-open analysis (ENC-5) now touches part of it.

> ⚠️ **Classification: SENSITIVE.** A completed threat model is a blueprint for attacking the system. In a real organization this belongs in a version-controlled, access-controlled repository shared between the product team and security — not an open wiki.

---

## How to Read This Guide

| Marker | Content type | What to do with it |
|---|---|---|
| 📘 *blockquote* | **Theory** — generalizes to any system | Study to internalize |
| *(normal text/tables/diagrams)* | **🏢 Scenario** — Meridian Retail Co. | Study for the *pattern* of application |
| 💡 *blockquote* | **Bridge** — theory → specific finding | Highest value; pause here |
| 📕 *blockquote* | **Correction** — something earlier drafts got wrong | Read first if you studied v1–v5 |

---

## Contents

### Part I — Foundations
| # | File | What's in it |
|---|---|---|
| 00 | **[00-glossary.md](00-glossary.md)** | Every acronym: FAIR/risk, frameworks, governance, regulatory, identity |
| 01 | **[01-foundations.md](01-foundations.md)** | What threat modeling is · Four-Question Framework · the six generalized steps · means/motive/opportunity · severity vs. risk · what you *can't* find · TM vs. vulnerability management |
| 02 | **[02-business-context.md](02-business-context.md)** | Meridian Retail Co. · business goals · risk appetite tiers in dollars · PASTA Stage 1 applied |

### Part II — Modeling the System (Question 1)
| # | File | What's in it |
|---|---|---|
| 03 | **[03-session-facilitation.md](03-session-facilitation.md)** | How to run the session · full workshop transcript · recorded Q&A log · facilitation anti-patterns |
| 04 | **[04-dfd-library.md](04-dfd-library.md)** | **The big one.** DFD notation & metadata standards · L0 → L3 · per-scenario and per-path diagrams · annotation tables for every element · **18 diagrams + the v8 actor catalog (means/motive/opportunity) + the compute/IMDS, partner, KMS-key-access & agent planes** |
| 05 | **[05-other-model-types.md](05-other-model-types.md)** | Sequence diagrams (and the TOCTOU finding they exposed) · process flow diagrams · fishbone root-cause · when to use which |

### Part III — Finding Threats (Question 2)
| # | File | What's in it |
|---|---|---|
| 06 | **[06-stride.md](06-stride.md)** | STRIDE · per-Element · per-Interaction · component-based · all three applied to our bucket · the Usual Suspects checklist · **v8: components 6–8 (KMS control plane, compute/IMDS, identity/human/agent) → 68 threats** |
| 07 | **[07-linddun-privacy.md](07-linddun-privacy.md)** | Privacy threat modeling · the non-repudiation inversion · misuse cases · applied |
| 08 | **[08-attack-trees-capec.md](08-attack-trees-capec.md)** | Attack trees & the attack forest · CAPEC Explore/Experiment/Exploit format · CWE→CAPEC→ATT&CK chain · **nine trees (incl. the KMS/encryption tree) + the APT attack chain AC-1** |

### Part IV — Deciding What to Do (Question 3)
| # | File | What's in it |
|---|---|---|
| 09 | **[09-risk-scoring.md](09-risk-scoring.md)** | CVSS (severity) · DREAD (risk, with its scales) · FAIR (quantified $) · NIST SP 800-30 · the Risk Register |
| 10 | **[10-security-requirements.md](10-security-requirements.md)** | The jargon-free 7-topic framework · threat→requirement tables · all applied to S3 |
| 11 | **[11-compliance-mapping.md](11-compliance-mapping.md)** | OWASP Top 10 **2025** · CIS Controls · NIST CSF · GDPR/PCI/HIPAA/SOC 2/ISO 27001 |
| 12 | **[12-identity-iam-entra.md](12-identity-iam-entra.md)** | Deriving AWS IAM roles + MS Entra ID groups from the risk register, from zero |
| 13 | **[13-hardening-deep-dive.md](13-hardening-deep-dive.md)** | S3 Versioning, Object Lock, MFA Delete, KMS rotation & key policy — the A→B→C→D control-leveling ladder · **v8: the KMS exploit→control map (§13.7)** |

### Part V — Keeping It Alive (Question 4)
| # | File | What's in it |
|---|---|---|
| 14 | **[14-continuous-threat-modeling.md](14-continuous-threat-modeling.md)** | CTM · baseline + Threat Model Every Story · curator role · ticket labels · subject list · **S3 Secure Developer Checklist** · STRIDE-in-DevOps rollout |
| 15 | **[15-methodology-comparison.md](15-methodology-comparison.md)** | STRIDE · PASTA (7 stages applied) · Trike · LINDDUN · TARA · DREAD · attack trees — compared, graded, and how to choose |
| 16 | **[16-tooling-automation.md](16-tooling-automation.md)** | Threat modeling as code · pytm/Threatspec/Threat Dragon · automation in CI/CD · what to automate and what not to |

### Appendices
| File | What's in it |
|---|---|
| **[A-findings-register.md](A-findings-register.md)** | Every finding in standard format: ID · attack scenario prose · severity · mitigation · owner · **26 findings incl. ENC-1…8 crypto + F-13…F-20 + the APT chain** |
| **[B-traceability-log.md](B-traceability-log.md)** | Full Q&A history across all versions of this model |
| **[C-sources.md](C-sources.md)** | Books, standards, articles, tools |

---

## Suggested Learning Paths

**Path 1 — "I'm new to threat modeling" (≈4 hours)**
`01` → `04` → `06` → `08` → `09` → `A`
Foundations, then draw a model, then find threats with STRIDE, then trees, then score them, then see what a finished finding looks like.

**Path 2 — "I run a DevSecOps team and need this operational" (≈3 hours)**
`02` → `03` → `10` → `14` → `16`
Business framing, how to run the session, jargon-free requirements your devs will accept, the continuous mechanism, then automation.

**Path 3 — "I need to defend this to an auditor or board" (≈2 hours)**
`02` → `09` → `11` → `A` → `B`
Risk appetite in dollars, formal risk assessment, framework mapping, the register, the audit trail.

**Path 4 — "Teach me the methodologies" (≈3 hours)**
`01` → `15` → `06` → `07` → `08`
Concepts, the comparative survey, then the three big elicitation techniques in depth.

**Path 5 — "Just the diagrams" (≈1 hour)**
`04` → `05`
Every DFD level with full annotation standards, plus the model types DFDs can't cover.

---

## The One-Paragraph Summary

Threat modeling answers four questions: *What are we building? What can go wrong? What are we going to do about it? Did we do a good enough job?* You answer the first with diagrams (mostly DFDs, sometimes sequence diagrams), the second with elicitation frameworks (STRIDE for security, LINDDUN for privacy, attack trees for attacker paths, CAPEC/CWE/ATT&CK for grounding), the third with risk scoring (CVSS for severity, FAIR for dollars) plus a control catalog, and the fourth with continuous mechanisms rather than an annual review. A threat identification method plus a risk classification method is what makes a *complete* methodology — neither alone is enough. And the measure of success is simple: **a good threat model is one that produces valid findings.**

---

*Next: [00-glossary.md](00-glossary.md) or jump to [01-foundations.md](01-foundations.md).*
