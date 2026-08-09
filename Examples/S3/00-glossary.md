[Contents](README.md) · [01 Foundations →](01-foundations.md)

# 00 · Glossary

Grouped by domain so you can study one cluster at a time.

---

## Quantitative Risk (FAIR)

| Acronym | Full term | Definition |
|---|---|---|
| **FAIR** | Factor Analysis of Information Risk | The quantitative risk model used in this guide (Open Group / FAIR Institute standard). See [09](09-risk-scoring.md) |
| **ALE** | Annualized Loss Expectancy | Expected dollar cost of a risk over one year. Always a **range**, never a point value |
| **LEF** | Loss Event Frequency | How often a loss actually occurs per year = TEF × Vulnerability |
| **LM** | Loss Magnitude | Dollar cost per event = Primary Loss + (Secondary Loss × SLEF) |
| **TEF** | Threat Event Frequency | How often an actor *attempts* the action per year |
| **Vuln** | Vulnerability (FAIR factor) | Probability an attempt *succeeds* given current controls |
| **PL** | Primary Loss | Direct costs: incident response, forensics, legal, notification |
| **SL** | Secondary Loss | Downstream costs: fines, churn, reputational damage, litigation. **Usually the dominant term** |
| **SLEF** | Secondary Loss Event Frequency | Probability secondary stakeholders (regulators, media, customers) actually react |
| **SLE** | Single Loss Expectancy | Classic pre-FAIR term = Asset Value × Exposure Factor |
| **ARO** | Annualized Rate of Occurrence | Classic term; SLE × ARO = ALE in the traditional formula |
| **LEC** | Loss Exceedance Curve | The Monte Carlo output: "X% chance annual loss exceeds $Y" |

## Severity & Legacy Scoring

| Acronym | Full term | Definition |
|---|---|---|
| **CVSS** | Common Vulnerability Scoring System | Standardized 0–10 **severity** (not risk) score from FIRST |
| **DREAD** | Damage, Reproducibility, Exploitability, Affected users, Discoverability | Microsoft's legacy risk model. Largely retired for subjectivity |
| **CIA** | Confidentiality, Integrity, Availability | The core security property triad |

## Threat-Modeling Frameworks

| Acronym | Full term | Definition |
|---|---|---|
| **STRIDE** | Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege | Microsoft's security threat categories (1999) |
| **LINDDUN** | Linkability, Identifiability, Non-repudiation, Detectability, Disclosure, Unawareness, Non-compliance | KU Leuven's privacy threat categories (2011) |
| **PASTA** | Process for Attack Simulation and Threat Analysis | Seven-stage risk-centric methodology |
| **TARA** | Threat Assessment and Remediation Analysis | MITRE methodology assuming the perimeter is already breached |
| **SPARTA** | Security and Privacy Architecture through Risk-driven Threat Assessment | KU Leuven continuous elicitation framework/tool |
| **CTM** | Continuous Threat Modeling | Baseline + Threat Model Every Story. See [14](14-continuous-threat-modeling.md) |
| **A-CTM** | Autodesk Continuous Threat Modeling | The published real-world CTM implementation |
| **DFD** | Data Flow Diagram | The primary system-modeling notation. See [04](04-dfd-library.md) |
| **PFD** | Process Flow Diagram | Activity-chain notation; less common in threat modeling |
| **TOCTOU** | Time Of Check To Time Of Use | Race condition where state changes between validation and use |
| **MUC** | Misuse Case | LINDDUN's narrative format for a privacy threat |
| **CRUD** | Create, Read, Update, Delete | The atomic action set in Trike's actor-asset-action matrix |

## Threat Intelligence Catalogs

| Acronym | Full term | Definition |
|---|---|---|
| **CAPEC** | Common Attack Pattern Enumeration and Classification | MITRE's catalog of attack patterns, with Explore/Experiment/Exploit flows |
| **CWE** | Common Weakness Enumeration | MITRE's catalog of root-cause weakness classes |
| **ATT&CK** | Adversarial Tactics, Techniques, and Common Knowledge | MITRE's catalog of observed adversary techniques |
| **CVE** | Common Vulnerabilities and Exposures | Specific, identified vulnerabilities in specific products |
| **NVD** | National Vulnerability Database | NIST's CVE database with additional analysis |
| **TTP** | Tactics, Techniques, and Procedures | How adversaries operate |
| **SBOM** | Software Bill of Materials | Inventory of components in a piece of software |

## Governance & Assurance

| Acronym | Full term | Definition |
|---|---|---|
| **NIST** | National Institute of Standards and Technology | Source of SP 800-30, SP 800-53, CSF |
| **SP 800-30** | Special Publication 800-30 | *Guide for Conducting Risk Assessments* |
| **SP 800-53** | Special Publication 800-53 | NIST's control catalog |
| **CSF** | Cybersecurity Framework | NIST's Govern/Identify/Protect/Detect/Respond/Recover model |
| **CIS** | Center for Internet Security | Source of the CIS Controls and CIS Benchmarks |
| **ERM** | Enterprise Risk Management | Org-wide risk governance (COSO ERM) |
| **ISO/IEC 27001** | — | International information security management standard |
| **SOC 2** | System and Organization Controls 2 | AICPA audit standard for service organizations |
| **TSC** | Trust Services Criteria | The control categories SOC 2 audits against (e.g. CC6.1) |
| **BIA / BIAR** | Business Impact Analysis / Report | PASTA Stage 1 output |
| **RACI** | Responsible, Accountable, Consulted, Informed | Role-assignment matrix used heavily in PASTA |
| **GRC** | Governance, Risk, and Compliance | — |
| **SoD** | Segregation of Duties | Splitting sensitive actions across people |
| **DTAP** | Development, Test, Acceptance, Production | Environment separation model |

## Regulatory

| Acronym | Full term | Definition |
|---|---|---|
| **GDPR** | General Data Protection Regulation | EU personal-data law |
| **CCPA / CPRA** | California Consumer Privacy Act / Privacy Rights Act | California personal-data law |
| **PCI-DSS** | Payment Card Industry Data Security Standard | Card-data security standard |
| **HIPAA** | Health Insurance Portability and Accountability Act | US health-data law |
| **NIS2 / DORA / CRA** | — | EU directives increasingly *requiring* threat modeling |
| **PII** | Personally Identifiable Information | Data identifying an individual |
| **DPO** | Data Protection Officer | Role accountable for privacy compliance |
| **PET** | Privacy-Enhancing Technology | LINDDUN's preferred mitigation class |
| **COOP** | Continuity of Operations | Recovery planning (TARA scoring factor) |

## Identity & Cloud

| Acronym | Full term | Definition |
|---|---|---|
| **IAM** | Identity and Access Management | AWS's permission system |
| **PIM** | Privileged Identity Management | Entra ID's just-in-time privileged access |
| **SSO** | Single Sign-On | One identity, many systems |
| **SAML** | Security Assertion Markup Language | Federation protocol (AWS IAM Identity Center) |
| **OIDC** | OpenID Connect | Federation protocol used for CI/CD workload identity |
| **MFA** | Multi-Factor Authentication | — |
| **RBAC** | Role-Based Access Control | Access model used in [12](12-identity-iam-entra.md) |
| **NPA** | Non-Personal Account | Service/system account |
| **OAC / OAI** | Origin Access Control / Identity | CloudFront→S3 restriction (OAC supersedes OAI) |
| **BPA** | Block Public Access | S3's account- and bucket-level public access guardrail |
| **CMK** | Customer Managed Key | A KMS key whose policy *you* control |
| **KMS** | Key Management Service | AWS encryption key service |
| **MRK** | Multi-Region Key | KMS key replicated across regions |
| **WORM** | Write Once, Read Many | Immutability model behind Object Lock Compliance mode |
| **SCP** | Service Control Policy | AWS Organizations guardrail — evaluated *above* IAM |
| **IaC** | Infrastructure as Code | Terraform, CloudFormation, etc. |
| **SSRF** | Server-Side Request Forgery | Consolidated into OWASP A01:2025 Broken Access Control |
| **UGC** | User-Generated Content | The avatar uploads in our case |
| **SCA** | Software Composition Analysis | Dependency vulnerability scanning |
| **SAST / DAST** | Static / Dynamic Application Security Testing | Code and runtime scanning |

---

[Contents](README.md) · [01 Foundations →](01-foundations.md)
