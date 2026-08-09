[← B · Traceability Log](B-traceability-log.md) · [Contents](README.md)

# Appendix C · Sources & Further Reading

---

## Books

| Source | Why read it |
|---|---|
| **Izar Tarandach & Matthew Coles**, *Threat Modeling: A Practical Guide for Development Teams* (O'Reilly, 2020) | The primary source for this guide. System modeling and DFD conventions (Ch. 1) · the generalized flow and "Usual Suspects" (Ch. 2) · the methodology survey and grading rubric (Ch. 3) · automation (Ch. 4) · **Continuous Threat Modeling** (Ch. 5) · the champion's role (Ch. 6) · a full worked example (Appendix A) |
| **Adam Shostack**, *Threat Modeling: Designing for Security* (Wiley, 2014) | The foundational text. Origin of the Four-Question Framework and STRIDE-per-Element practice |
| **Brook S.E. Schoenfield**, *Securing Systems: Applied Security Architecture and Threat Models* (CRC Press) | Deeper on architecture-level security |
| **Brook S.E. Schoenfield**, *Secrets of a Cyber Security Architect* (Auerbach) | Source of the "one requirement that improves posture is a win" framing |
| **Tony UcedaVélez & Marco Morana**, *Risk Centric Threat Modeling* (Wiley, 2015) | The PASTA reference |
| **Douglas Hubbard & Richard Seiersen**, *How to Measure Anything in Cybersecurity Risk* | Calibrated estimation — read before attempting FAIR |
| **Shamal Faily**, *Designing Usable and Secure Software with IRIS and CAIRIS* (Springer) | Usability + security together |
| **Atul Gawande**, *The Checklist Manifesto* | Background for the If-This-Then-That checklist design in [14](14-continuous-threat-modeling.md) |

---

## Foundational Papers

- **Loren Kohnfelder & Praerit Garg**, "The Threats To Our Products" (Microsoft, 1999) — the original STRIDE definition
- **Bruce Schneier**, "Attack Trees," *Dr. Dobb's Journal* (1999)
- **Mina Deng, Kim Wuyts, Riccardo Scandariato, Bart Preneel, Wouter Joosen**, "A Privacy Threat Analysis Framework" (KU Leuven, 2010/2011) — LINDDUN
- **Jackson Wynn et al.**, "Threat Assessment and Remediation Analysis (TARA)" (MITRE, 2011)
- **Sion, Yskout, Van Landuyt, Joosen**, SPARTA papers (KU Leuven)
- **Gane & Sarson**; **Yourdon & DeMarco** — structured analysis, origin of DFD notation

---

## Standards & Frameworks

| Source | Use for |
|---|---|
| **NIST SP 800-30 Rev. 1** | *Guide for Conducting Risk Assessments* — the formal process in [09](09-risk-scoring.md) |
| **NIST SP 800-53** | Control catalog |
| **NIST CSF 2.0** | Govern/Identify/Protect/Detect/Respond/Recover |
| **NIST IR 8286** | Integrating cybersecurity with enterprise risk management; references FAIR-style quantification |
| **Open FAIR** (The Open Group / FAIR Institute) | The quantitative risk model |
| **FIRST — CVSS** | Severity scoring, including Environmental metrics |
| **CIS Critical Security Controls** | Prescriptive, testable safeguards |
| **CIS AWS Foundations Benchmark** | AWS-specific configuration baseline |
| **AWS Well-Architected — Security Pillar** | AWS-native design guidance |
| **ISO/IEC 27001:2022 Annex A** | Control catalog *(note: 2022 restructured the 2013 Annex A)* |
| **ISO 31000 / COSO ERM** | Risk appetite statement structure |
| **Cloud Security Alliance** — Top Threats, Cloud Controls Matrix | Cloud-specific threat and control catalogs |

---

## Threat Intelligence Catalogs

- **MITRE CAPEC** — capec.mitre.org — attack patterns with Explore/Experiment/Exploit flows
- **MITRE CWE** — cwe.mitre.org — root-cause weakness classes
- **MITRE ATT&CK** — attack.mitre.org — observed adversary techniques (Cloud matrix especially)
- **CVE / NVD** — specific vulnerabilities
- **OWASP Top 10 (2025)** — owasp.org/Top10/2025/
- **OWASP Threat Modeling Cheat Sheet**
- **US-CERT / CISA advisories**

---

## Practitioner Resources

- **Threat-Modeling.com** (Nick Kirtley) — the STRIDE, PASTA, Trike, LINDDUN, DREAD, and CAPEC walkthroughs; the **Threat Modeling Framework** (Kirtley & Tejvir Singh) that underpins the jargon-free seven-topic model in [10](10-security-requirements.md); the CISO Security Mind Map; and the free browser-based tool
- **Adam Shostack's blog** — including the running list of threat modeling games
- **Autodesk Continuous Threat Modeling Handbook** (GitHub) — the reference CTM implementation and Secure Developer Checklist
- **LINDDUN.org** — tutorials, threat trees with per-leaf guidance, and LINDDUN GO
- **Microsoft SDL threat modeling training** — free online modules on foundational DFD elements
- **r/ThreatModeling** (Reddit) · **#threatmodeling** on OWASP Slack

---

## Tools

| Tool | Type |
|---|---|
| **pytm** | Threat modeling from code (Python DSL) |
| **Threatspec** | Threat modeling with code (annotations) |
| **Threagile** | From code (YAML) |
| **OWASP Threat Dragon** | Free diagramming + rules |
| **Microsoft Threat Modeling Tool** | STRIDE per Interaction |
| **CAIRIS** | Design + security + usability |
| **IriusRisk · SD Elements · ThreatModeler · Tutamen** | Commercial platforms |
| **Threat-Modeling.com tool** | Free, browser-based |

### IriusRisk course and toolchain

- [IriusRisk CLI](https://github.com/iriusrisk/iriusrisk-cli), pinned here to `0.6.3`; source code and `--help` take precedence over stale README examples.
- [IriusRisk Security Research Assistant](https://github.com/iriusrisk/iriusrisk-security-research-assistant), pinned to commit `4fc6436bc7c5517d43d8ce23012b9c5deefc4688` (ISRA 3.2.0).
- [Associate-course conversation](https://chatgpt.com/share/6a78701f-8d74-83eb-9b3c-f1e7ea040ea2) and local course notes; study material, not tenant evidence.
- `Training_Runs/IriusRisk/IR_ Mobile Banking Application Template.xml`, an isolated native-XML comparison fixture governed by `.cowork/FOLDER-INSTRUCTIONS.md`.

---

## Games (for teaching)

| Game | Implements |
|---|---|
| **Elevation of Privilege** (Shostack) | STRIDE |
| **Elevation of Privilege and Privacy** (Vinkovits) | STRIDE + privacy |
| **OWASP Cornucopia** | Security requirements, e-commerce oriented |
| **Security & Privacy Threat Discovery Cards** (U. Washington) | Adversary dimensions |
| **LINDDUN GO** | LINDDUN, lightweight |

---

## A Note on Verification

Several specific identifiers in this guide — particular CWE and CAPEC numbers, AWS feature availability dates, and framework control references — were drawn from a mix of primary sources and recollection. Before using any of it in an audit-facing or externally published context, verify against the authoritative source. Specifically worth re-checking: CAPEC IDs, ISO 27001:2022 Annex A control numbers, PCI-DSS v4 requirement numbering as it phases in, and current AWS documentation for Object Lock and KMS rotation behavior.

---

[← B · Traceability Log](B-traceability-log.md) · [Contents](README.md)
