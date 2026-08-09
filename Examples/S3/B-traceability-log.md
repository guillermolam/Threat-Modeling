[← A · Findings Register](A-findings-register.md) · [Contents](README.md) · [C · Sources →](C-sources.md)

# Appendix B · Traceability Log

> 📘 **Why this exists.** Threat models are evolutionary — today's should be better than yesterday's. A traceability log records *what was asked, what was answered, and what changed as a result*, so a future reviewer can tell the difference between "we considered this and excluded it" and "we never thought of it." It is also what regulatory frameworks increasingly want to see when they require threat modeling without defining it.

---

## Scoping Questions (across all versions)

| # | Question | Answer | Modeling impact |
|---|---|---|---|
| Q1 | Is the public exposure intentional or a misconfiguration? | **Both** — model in parallel; record all Q&A | Scenarios A and B built side by side ([04 §4.6–4.8](04-dfd-library.md)) |
| Q2 | How is the bucket accessed? | Either direct S3 URL/bucket policy **or** CloudFront | Both access-path DFDs built |
| Q3 | Data sensitivity / compliance scope? | **Mixed — assume worst case** | Controls sized to strictest regime; PII + regulated assumed |
| Q4 | Reorganize under the Four-Question Framework with Mermaid? | Yes | Full structural refactor |
| Q5 | Business wants risk minimized; H/M/L not assumable | Adopt FAIR with a dollar-denominated appetite table | [02](02-business-context.md), [09](09-risk-scoring.md) |
| Q6 | Why not more DFD levels? Why not LINDDUN? Where's the risk assessment? Invent business goals | L0–L3 added · LINDDUN added · NIST 800-30 register added · Meridian Retail Co. created | [04](04-dfd-library.md), [07](07-linddun-privacy.md), [09](09-risk-scoring.md), [02](02-business-context.md) |
| Q7 | Conversation-driven with recorded Q&A? Attack forest? Compliance mapping? IAM/Entra derivation? Deeper hardening? Missed steganography? | All added | [03](03-session-facilitation.md), [08](08-attack-trees-capec.md), [11](11-compliance-mapping.md), [12](12-identity-iam-entra.md), [13](13-hardening-deep-dive.md) |
| Q8 | Define all risk acronyms · blockquotes for theory · reader-friendly structure | Glossary, reading legend, theory/scenario/bridge convention | [00](00-glossary.md), [README](README.md) |
| Q9 | Study Tarandach & Coles and apply it | 7 corrections · sequence diagram → **F-07** · fishbone · per-asset requirements · initiator marks · Usual Suspects · severity/risk split · CVSS vectors · standard findings format · **CTM** · methodology self-grading · document classification | [05](05-other-model-types.md), [06](06-stride.md), [14](14-continuous-threat-modeling.md), [15](15-methodology-comparison.md) |
| Q10 | Keep more DFDs · learn how others do STRIDE · apply other techniques · split into a linked multi-file guide | **14 DFDs** with full annotation standards · STRIDE variants (per Element / per Interaction / component-based) · threat example library · jargon-free 7-topic requirements framework · CAPEC Explore/Experiment/Exploit · OWASP 2025 · CIS Controls · Trike actor-asset-action matrix · DREAD scales · PASTA 7 stages applied · **19-file linked guide** | This edition |
| Q11 *(v8)* | Add more actors · detect more threats · expand the DFD and attack trees · **go deep on S3 KMS cryptographic exploits** | **Actor catalog A-1…A-12** ([04 §4.5b](04-dfd-library.md)) · 4 new DFD planes (partner, compute/IMDS, KMS key-access, agent) · **STRIDE components 6–8 → 68 threats** · **Trees 5–9 + APT chain AC-1** · **ENC-1…8** crypto findings + **F-13…F-20** · LINDDUN **P-07…P-09** · 4 new sequence diagrams · **KMS exploit→control map** ([13 §13.7](13-hardening-deep-dive.md)) — closes Limitations #6 & #7, adds the SSRF/compute-tier surface (A01), and *partially* addresses #5 (A10 fail-open via ENC-5) | This edition (v8) |

---

## Session Q&A (Meridian, workshop #1)

| # | Question | Answer | Raised by | Became |
|---|---|---|---|---|
| S1 | Anything scanning avatar uploads on ingest? | **No** | Sam Lin | **F-12** |
| S2 | Avatar prefix in the privacy notice / retention policy? | **Unknown** | Amara Okafor | **P-01**, **P-02** |
| S3 | Deploy role `Resource` scoped or wildcarded? | **Unverified** | Diego Fernandez | **F-09** |
| S4 | Versioning / Object Lock enabled? | **No** | Diego Fernandez | **F-11** |
| S5 | KMS: CMK or AWS-managed? | **AWS-managed** | Diego Fernandez | **ENC-2** (blocks 4 other requirements) |
| S6 | IAM Identity Center / Entra ID federation? | **No — root only** | Sam Lin | Scopes all of [12](12-identity-iam-entra.md) |
| S7 | Who accepts a Critical-tier finding? | **CFO + CISO + Board** | Priya Shah | Escalation path confirmed |
| S8 | Does the reader validate-then-read with a gap? | **Yes — minutes** | Diego Fernandez | **F-07** |
| S9 | TLS enforced by policy or convention? | **Unverified** | Priya Shah | ENC-1 |
| S10 | CloudTrail data events or management only? | **Unverified** | Priya Shah | **LOG-1** |

---

## Session Q&A (Meridian, workshop #2 — v8, crypto & actor deep-dive)

| # | Question | Answer | Raised by | Became |
|---|---|---|---|---|
| S11 | Which SSE mode and key type? Is SSE-C allowed on the bucket? | **AWS-managed key today; SSE-C not blocked** | Priya Shah | ENC-2, ENC-5, **ENC-6** |
| S12 | Does any app feature fetch a URL server-side? | **Yes — avatar-by-URL import; webhooks** | Sam Lin | **F-13** (SSRF; A01:2025) |
| S13 | IMDSv1 or IMDSv2? Metadata hop limit? | **Unverified** | Diego Fernandez | F-13 |
| S14 | Partner role — `ExternalId` set, `Resource` prefix-scoped? | **Unverified** | Diego Fernandez | **F-14** |
| S15 | Automated leaver deprovisioning / any long-lived access keys? | **No JML automation; IAM users exist** | Amara Okafor | **F-15** |
| S16 | Scripted identity verification before a help-desk MFA reset? | **No** | Amara Okafor | **F-16** |
| S17 | Is an autonomous/LLM agent reading exports? What can its role do? | **Pilot agent live; role scope unverified** | Sam Lin | **F-18**, P-08 |
| S18 | KMS key policy — who may `Decrypt`, `CreateGrant`, delete the key? | **Never reviewed** | Priya Shah | **ENC-3, ENC-7, ENC-8** |

> 📘 **The v8 pattern is the v7 pattern.** Every row above is again either an **"Unverified"** or a **"No"** — the same two answers that generated the original register. The crypto findings in particular (S11, S18) came from a single question no document raised: *"open the key policy and read who can decrypt."* Nobody had.

---

## Open Items Carried Forward

| Item | Type | Owner | Next action |
|---|---|---|---|
| Deploy role policy JSON | **Verification** | Platform Eng | Read the policy; confirm or refute S3 |
| TLS enforcement | **Verification** | Platform Eng | Confirm the `aws:SecureTransport` deny exists (ENC-1) |
| CloudTrail data events | **Verification** | Cloud Security | Confirm enabled for this bucket |
| Privacy notice coverage | **Verification** | DPO | Confirm avatar + export processing disclosed |
| PCI scope of exports | **Verification** | DPO + Finance | Determine whether order metadata brings PCI into scope |
| **OWASP A10 pass** *(Mishandling of Exceptional Conditions)* | **Partially addressed (v8)** | Cloud Security | ENC-5 / L3-D cover the KMS **fail-open** question; scanner timeout, BPA-eval-error default, retry storms, and verbose errors ([11 §11.6](11-compliance-mapping.md)) remain open |
| **SSRF / compute-tier (A01)** | ✅ **Added (v8)** | App + Platform Eng | Compute/IMDS plane drawn ([04 §4.16b](04-dfd-library.md)); **F-13** raised — a structural blind spot, not a prior open item |
| **KMS key policy JSON** | **Verification (v8)** | Cloud Security | Read the key policy: principals, `ViaService`, `SourceAccount`; enumerate **grants** (S18 → ENC-3/7/8) |
| **IMDS version + hop limit** | **Verification (v8)** | Platform Eng | Confirm IMDSv2 required, hop limit 1 (S13 → F-13) |
| **Partner role trust + resource** | **Verification (v8)** | Cloud Security | Confirm `ExternalId` + write-only prefix scope (S14 → F-14) |
| **Agent role scope** | **Verification (v8)** | App Eng | Confirm read-only + human-in-the-loop on write/decrypt (S17 → F-18) |
| **SSE-C denial** | **Verification (v8)** | Cloud Security | Confirm the bucket policy denies SSE-C (S11 → ENC-6) |
| **Leaver deprovisioning** | **Verification (v8)** | IAM / IT | Confirm JML automation; eliminate long-lived keys (S15 → F-15) |
| Object Lock mode decision | **Design conflict** | Cloud Security + DPO | Compliance-mode WORM vs. GDPR erasure ([13 §13.3](13-hardening-deep-dive.md)) — now also collides with crypto-shred ([13 §13.7](13-hardening-deep-dive.md)) |
| CWE/CAPEC ID verification | **Accuracy** | Whoever presents this | Verify specific IDs against cwe.mitre.org / capec.mitre.org before audit use; note indirect prompt injection has **no stable CAPEC** |

---

## Known Limitations of This Model

Stating these is itself a best practice — it prevents a future reader mistaking absence of findings for absence of risk.

1. **Implementation flaws are out of scope by design** ([01 §1.7](01-foundations.md)). Routed to SAST, SCA, fuzzing, and pen testing.
2. **The business context is invented.** Meridian Retail Co. and its appetite figures are illustrative. Substitute your own before using any of this for real decisions.
3. **FAIR figures are unvalidated estimates**, not calibrated by trained estimators — and the **v8 figures (ENC-1…8, F-13…20) are freshest of all**, first-pass anchors on new attack paths. Treat every range as illustrative of the *method*, not as a finding.
4. **~Fourteen inputs remain unverified** (table above; v8 added eight). A model with open questions is only as representative as its next verification pass — and the crypto findings especially hinge on reading the actual key policy.
5. **A10:2025 (Mishandling of Exceptional Conditions) is only *partially* analyzed.** ENC-5 and the L3-D "fails open" analysis address the KMS-unavailable sub-question, but the broader A10 pass (scanner timeout, BPA-eval-error default, retry storms, verbose errors — [11 §11.6](11-compliance-mapping.md)) remains open. *(Note: SSRF — which readers of the 2021 list associate with A10 — is **A01:2025** in the current list, and it **is** now covered by F-13 via the new compute tier.)*
6. ✅ **The partner integration is now decomposed** ([04 §4.16a](04-dfd-library.md), **F-14**). *Residual:* the partner's *own* threat model still does not exist, and fourth-party (subprocessor) risk is named but unquantified.
7. ✅ **The CI/CD deploy path now has a sequence diagram** ([05 §5.2b](05-other-model-types.md), **F-17**) — and, as predicted, it hid two findings (poisoned-dependency execution and the apply-before-review window).
8. **The autonomous-agent findings assume a pilot whose scope is unverified** (S17). F-18 and P-08 describe a plausible, dangerous configuration; confirm the agent's actual role and human-in-the-loop before acting on them as fact.
9. **KMS multi-Region keys and client-side encryption were not modeled.** MRK replica-key decrypt surface, imported-material lifecycle, and CSE envelope handling are out of scope this pass and deserve their own.
10. **The APT chain (AC-1 / F-20) is one illustrative path** — the crown-jewel path for the most-capable adversary. Other chains exist; enumerating them exhaustively is deliberately not attempted ([08 §8.10](08-attack-trees-capec.md)).
11. **A11:2025 and the full OWASP LLM Top 10 were only partially applied.** Indirect prompt injection (F-18) is grounded via OWASP LLM01/LLM06, but a complete LLM-Top-10 pass on the agent is a future item.

---

## Review Cadence

| Trigger | Action |
|---|---|
| Any story with a security-notable event | `potential-tm-update` → curator queue ([14](14-continuous-threat-modeling.md)) |
| Bucket policy, CloudFront, IAM, or KMS change | Curator review |
| New data class introduced | Re-run classification and LINDDUN |
| Relevant CVE or AWS security bulletin | Curator review |
| Post-incident | Feed findings back; update the model |
| Pen test / bug bounty finding | Same — the finding is an opportunity to improve the model |
| **Quarterly minimum** | Full review including a re-run of the [03](03-session-facilitation.md) conversation format |
| Annually | Risk appetite table review by the Board Risk Committee |

> 📘 **A note on the quarterly item.** Re-run the *conversation*, not just a document review. The evidence from this exercise is that new findings come from people noticing things, and people notice different things at different times. A document review finds documentation errors; a conversation finds F-12.

---

[← A · Findings Register](A-findings-register.md) · [Contents](README.md) · [C · Sources →](C-sources.md)
