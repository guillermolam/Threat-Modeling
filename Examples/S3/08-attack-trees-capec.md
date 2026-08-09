[← 07 LINDDUN](07-linddun-privacy.md) · [Contents](README.md) · [09 Risk Scoring →](09-risk-scoring.md)

# 08 · Attack Trees, the Attack Forest & CAPEC

---

## 8.1 Attack Trees

> 📘 **Theory.** Introduced by Bruce Schneier (1999); used in computer science for over two decades. The **root** is the attacker's goal — a negative outcome for you, a positive one for them. Intermediate and leaf nodes are ways to achieve the parent's goal. This is the primary model type for **attacker-centric** threat modeling.
>
> Each node should carry: difficulty of the action · cost · special knowledge or conditions required · anything else bearing on success or failure.
>
> **Construction:** identify a target/goal → identify actions to achieve it → rinse and repeat.

> 📘 **Two things a good tree needs:** complete knowledge of how something can be compromised — favoring *"what is possible"* over *"what is practical"* — and an understanding of the motivations, skills, and resources available to different attacker types.

> 📘 **Practical guidance:**
> - **Don't filter for feasibility while enumerating.** Analysis comes later. At this stage an exhaustive list of possibilities beats a partial list of feasibilities.
> - **Lopsided trees are fine.** Not all actions need equal decomposition depth.
> - **Dangling nodes are fine.** You won't identify every scenario.
> - **The tree is done when no additional substeps are needed to complete an action** — i.e., when a leaf maps to a single control.
> - **Brainstorm as a group.** This is where technical and security knowledge combine.
> - **Your risk appetite tells you when to stop.** How much time this deserves is a business question ([02](02-business-context.md)).

---

## 8.2 The Attack Forest

> 📘 **Theory.** An attack **forest** is a set of trees against one system, one per materially distinct attacker goal. The test: **if fully mitigating Goal A would leave Goal B untouched, they need separate trees.**
>
> A forest isn't inherently more rigorous — it's the right shape only when the goal count is genuinely plural. Don't build four trees for a one-goal system.

### 🏢 Our goals — four outcomes, five means *(v8)*

```mermaid
flowchart TD
    F["<b>Attack Forest</b><br/>S3 Customer Data System"]
    F --> OUT["<b>OUTCOME trees</b><br/><i>what the attacker ultimately wants</i>"]
    F --> MEANS["<b>MEANS trees</b> (v8)<br/><i>the position they need first</i>"]
    OUT --> G1["<b>Tree 1</b><br/>Exfiltrate customer data<br/><i>Confidentiality</i>"]
    OUT --> G2["<b>Tree 2</b><br/>Tamper with / destroy data<br/><i>Integrity + Availability</i>"]
    OUT --> G3["<b>Tree 3</b><br/>Deny availability / inflate cost<br/><i>Availability</i>"]
    OUT --> G4["<b>Tree 4</b><br/>Stage & distribute malware<br/><i>Third-party harm</i>"]
    OUT --> G5["<b>Tree 5</b> ★<br/>Defeat / abuse the encryption<br/><i>Confidentiality + Availability</i>"]
    MEANS --> G6["<b>Tree 6</b><br/>Steal a cloud identity (SSRF/IMDS)"]
    MEANS --> G7["<b>Tree 7</b><br/>Abuse a human identity<br/>(insider · departed · help-desk)"]
    MEANS --> G8["<b>Tree 8</b><br/>Subvert the deploy pipeline<br/>(supply chain)"]
    MEANS --> G9["<b>Tree 9</b><br/>Hijack the autonomous agent"]
    style F fill:#0d1117,color:#fff
    style G4 fill:#5c1a1a,color:#fff
    style G5 fill:#5c1a1a,color:#fff
    style MEANS fill:#1f2f4d,color:#fff
```

**The original four still pass the test:** encryption stops Tree 1 and does nothing for Tree 2; versioning stops Tree 2 and does nothing for Tree 4; scanning stops Tree 4 and does nothing for Tree 1. **Tree 5 also passes it against Tree 1** — you can fully close anonymous read (Tree 1) and still lose everything to a broad KMS key policy or a crypto-shred (Tree 5), because Tree 5's controls (key-policy scoping, `ViaService`, multi-person key deletion) are disjoint from Tree 1's (Block Public Access, `ListBucket` deny).

> 📘 **A distinction v7 didn't need: outcome vs. means.** §8.2's test — *"if fully mitigating Goal A leaves Goal B untouched, they need separate trees"* — is about **materially distinct goals**. The five new trees split into one genuine new *outcome* (Tree 5, defeating the crypto) and four **means/capability trees** (Trees 6–9): ways an attacker acquires the *position* from which the outcome trees become trivial. Are means trees legitimate members of a forest? Yes, when each maps to a **different defensive owner and control set** — which is the operational form of the same test. Tree 6 is owned by application + platform engineering (IMDSv2, egress control); Tree 7 by IAM + IT/HR (JML, help-desk verification); Tree 8 by the platform/DevSecOps team (module pinning, provenance); Tree 9 by whoever owns the agent (Least Agency). They resist being collapsed into one another exactly the way the outcome trees do. Drawing them separately is what stops "an attacker gets a credential somehow" from being a single hand-waved leaf on Tree 1 — which is precisely what it was in v7.

---

## 8.3 Tree 1 — Exfiltrate Customer Data

```mermaid
flowchart TD
    G["<b>GOAL</b><br/>Read customer data<br/>without authorization"]
    G --> A1["1 · Direct anonymous read"]
    G --> A2["2 · Bypass CloudFront"]
    G --> A3["3 · Compromise a credential"]
    G --> A4["4 · Exploit configuration drift"]

    A1 --> A11["1.1 Guess/enumerate bucket name<br/><i>cost: none · skill: none</i>"]
    A1 --> A12["1.2 Find name in leaked source/IaC/CI logs<br/><i>cost: low · skill: low</i>"]
    A1 --> A13["1.3 Find via scanner services indexing<br/>public buckets<br/><i>cost: none · skill: none · passive</i>"]
    A1 --> A14["1.4 Use public ListBucket to enumerate<br/>every key, then GET each<br/><i>cost: none · skill: none</i>"]

    A2 --> A21["2.1 Bucket policy still allows public GET<br/>despite OAC<br/><i>skill: low</i>"]
    A2 --> A22["2.2 Obtain/replay a leaked presigned URL<br/><i>skill: low · needs the leak</i>"]

    A3 --> A31["3.1 Steal IAM creds via SSRF or leaked keys<br/><i>skill: medium</i>"]
    A3 --> A32["3.2 Compromise the CI/CD deploy role<br/><i>skill: high · highest payoff</i>"]
    A3 --> A33["3.3 Insider or unrevoked departed-employee access<br/><i>skill: none · needs position</i>"]

    A4 --> A41["4.1 Manual console change bypasses IaC<br/><i>skill: none · needs access</i>"]
    A4 --> A42["4.2 Uncoordinated pipeline reverts the fix<br/><i>accidental</i>"]

    style G fill:#8b1a1a,color:#fff
    style A13 fill:#5c1a1a,color:#fff
    style A14 fill:#5c1a1a,color:#fff
```

> 💡 **Bridge.** Read the cost/skill annotations on branch 1. Leaves 1.1, 1.3, and 1.4 all say **cost: none, skill: none**. There is no attacker sophistication requirement anywhere on that branch — which is exactly why F-01's DREAD Exploitability scores 10/10 ([15 §DREAD](15-methodology-comparison.md)) and why it's release-blocking. Annotating leaves isn't bookkeeping; it's what makes the tree *argue* for a priority.

---

## 8.4 Tree 2 — Tamper With / Destroy Data

```mermaid
flowchart TD
    G2["<b>GOAL</b><br/>Modify or destroy<br/>customer data"]
    G2 --> B1["1 · Public write accidentally granted"]
    G2 --> B2["2 · Compromised write-capable credential"]
    G2 --> B3["3 · Overwrite via race condition"]
    G2 --> B4["4 · Destroy the means of decryption"]

    B1 --> B11["1.1 Policy grants s3:PutObject to *"]
    B1 --> B12["1.2 Legacy ACL grants AllUsers write"]

    B2 --> B21["2.1 Encrypt objects in place (ransomware)"]
    B2 --> B22["2.2 Mass delete — no versioning to recover"]
    B2 --> B23["2.3 Selective, quiet modification<br/><i>harder to detect than mass action</i>"]

    B3 --> B31["3.1 TOCTOU substitution during<br/>the export read window — <b>F-07</b>"]

    B4 --> B41["4.1 Schedule KMS key deletion"]
    B4 --> B42["4.2 Disable the key"]

    style G2 fill:#8b1a1a,color:#fff
    style B31 fill:#5c1a1a,color:#fff
```

Note **B2.3** — selective quiet modification is more dangerous than mass deletion and gets far less attention, because there's no dramatic moment that triggers investigation.

---

## 8.5 Tree 3 — Denial of Service / Cost Inflation

```mermaid
flowchart TD
    G3["<b>GOAL</b><br/>Deny availability<br/>or inflate cost"]
    G3 --> C1["1 · Volumetric request flood"]
    G3 --> C2["2 · Make the data undecryptable"]
    G3 --> C3["3 · Destructive deletion<br/><i>overlaps Tree 2, different intent</i>"]
    G3 --> C4["4 · Exhaust storage / quota"]

    C1 --> C11["1.1 No WAF rate limiting on the public path"]
    C1 --> C12["1.2 Requester-Pays misconfiguration<br/>shifts cost onto us"]
    C1 --> C13["1.3 Cache-busting query strings<br/>force origin hits past the CDN"]

    C2 --> C21["2.1 Key policy allows disable/delete<br/>to too broad a principal"]

    C4 --> C41["4.1 Unbounded UGC upload size or count"]
    C4 --> C42["4.2 Versioning without lifecycle rules<br/>→ unbounded growth"]

    style G3 fill:#8b1a1a,color:#fff
```

**C1.3** is worth internalizing: a CDN in front of a bucket is not automatically a rate-limit control. Cache-busting parameters can force origin hits, and if the origin is billed per request, the CDN becomes an amplifier rather than a shield.

---

## 8.6 Tree 4 — Malware Staging & Distribution

Discovered mid-session ([03 §3.4](03-session-facilitation.md)), not from any catalog.

```mermaid
flowchart TD
    G4["<b>GOAL</b><br/>Use the bucket as a malware<br/>staging & distribution point"]
    G4 --> D1["1 · Get malicious content in"]
    G4 --> D2["2 · Ensure the payload survives<br/>storage and serving"]
    G4 --> D3["3 · Get it retrieved or executed"]

    D1 --> D11["1.1 Abuse the legitimate avatar upload<br/><i>cost: a free account</i>"]
    D1 --> D12["1.2 Exploit public-write misconfiguration"]
    D1 --> D13["1.3 Compromise a partner integration<br/>that writes to a prefix"]

    D2 --> D21["2.1 No re-encode — bytes stored verbatim"]
    D2 --> D22["2.2 No malware scanning on ingest"]
    D2 --> D23["2.3 No file-size anomaly detection"]

    D3 --> D31["3.1 Victim client parses it as a polyglot<br/>and executes embedded content"]
    D3 --> D32["3.2 Resident malware fetches it as a<br/>second-stage payload — <b>our domain is<br/>allow-listed by their defenses</b>"]
    D3 --> D33["3.3 Internal tooling with a vulnerable<br/>image parser executes on open"]

    style G4 fill:#5c1a1a,color:#fff
    style D32 fill:#8b1a1a,color:#fff
```

> 💡 **Bridge.** **D3.2 is the crux, and it's counterintuitive.** The attacker's gain isn't the file — it's *your reputation*. A payload hosted on your CDN passes network defenses that would block an unknown host. This is why the mitigation must include **isolating UGC into its own bucket and domain**: it's not just blast-radius containment, it's denying the attacker the reputational borrowing that makes the attack worth doing.

**Grounding:** CWE-434 (Unrestricted Upload of File with Dangerous Type) · CWE-829 (Inclusion of Functionality from Untrusted Control Sphere) · ATT&CK **T1027.003** (Obfuscated Files or Information: Steganography) · ATT&CK **T1105** (Ingress Tool Transfer). Real-world precedent exists in malware families that retrieve second-stage components hidden inside PNG images on legitimate infrastructure.

---

## 8.6a Tree 5 — Defeat / Abuse the Encryption Layer ★ *(v8)*

The tree the guide was asked to grow. Every other tree treats encryption as a *mitigation*; this one treats the **KMS control plane as a target in its own right**. It is an outcome tree because its controls are disjoint from Tree 1's: you can perfectly close anonymous read and still lose the plaintext here. Grounded on the L3-D key-access plane ([04 §4.16c](04-dfd-library.md)).

```mermaid
flowchart TD
    G5["<b>GOAL</b><br/>Read plaintext despite SSE,<br/>or make data undecryptable"]
    G5 --> H1["1 · Obtain decrypt authority<br/><i>read the plaintext</i>"]
    G5 --> H2["2 · Redirect / downgrade encryption<br/><i>own future writes</i>"]
    G5 --> H3["3 · Destroy decryptability<br/><i>crypto-shred</i>"]
    G5 --> H4["4 · Ransomware by re-encryption"]
    G5 --> H5["5 · Persist covertly on the key"]

    H1 --> H11["1.1 Key policy grants Decrypt too broadly,<br/>or to acct :root → delegates to IAM<br/><i>skill: low · ENC-3</i>"]
    H1 --> H12["1.2 No kms:ViaService → call kms:Decrypt<br/>DIRECTLY on a ciphertext blob, bypass S3<br/><i>skill: medium · ENC-4</i>"]
    H1 --> H13["1.3 Cross-account grant → decrypt exfiltrated<br/>objects from the partner account<br/><i>skill: low · ENC-3 · F-14</i>"]
    H1 --> H14["1.4 Assume a role already on the key policy<br/><i>via Tree 6 / Tree 7</i>"]

    H2 --> H21["2.1 UpdateAlias repoints the enc alias to<br/>an attacker key → new writes readable by them<br/><i>skill: medium · ENC-5</i>"]
    H2 --> H22["2.2 Write with weak/no SSE — no write-time<br/>enforcement of aws:kms + expected key ARN<br/><i>skill: low · ENC-5</i>"]

    H3 --> H31["3.1 ScheduleKeyDeletion (min 7-day window)"]
    H3 --> H32["3.2 DisableKey — instant, reversible by owner"]
    H3 --> H33["3.3 Delete IMPORTED key material —<br/>instant, irreversible<br/><i>ENC-7</i>"]

    H4 --> H41["4.1 CopyObject w/ SSE-C attacker key →<br/>AWS holds ciphertext it CANNOT recover<br/><i>ENC-6 · ATT&CK T1486</i>"]

    H5 --> H51["5.1 CreateGrant → durable decrypt that<br/>survives a key-POLICY review<br/><i>ENC-8</i>"]
    H5 --> H52["5.2 PutKeyPolicy → grant self Decrypt<br/><i>ENC-8 · E7</i>"]

    style G5 fill:#8b1a1a,color:#fff
    style H11 fill:#5c1a1a,color:#fff
    style H12 fill:#5c1a1a,color:#fff
    style H41 fill:#5c1a1a,color:#fff
```

> 💡 **Bridge — the two counterintuitive leaves.** **1.2** is the one security teams miss: they scope the *bucket* policy and assume the data is safe, but a principal with `kms:Decrypt` and no `ViaService` restriction can hand a ciphertext blob straight to the KMS API and never touch S3 — so the object read never appears in S3 access logs at all. **4.1** is the modern S3 ransomware primitive: with SSE-C the *attacker* supplies the key on every request and AWS never stores it, so re-encrypting your objects with a key only they hold is a one-command, unrecoverable extortion — versioning and Object Lock are the only things that blunt it, which is why F-11 and this leaf share a mitigation.

---

## 8.6b Tree 6 — Steal a Cloud Identity (SSRF / IMDS) *(v8)*

A **means** tree: the position from which Trees 1, 2 and 5 become trivial. Grounded on the compute/IMDS plane ([04 §4.16b](04-dfd-library.md)); adds the SSRF surface, which is **A01:2025** in the current OWASP list (not A10 — [11 §11.2](11-compliance-mapping.md)).

```mermaid
flowchart TD
    G6["<b>GOAL</b><br/>Obtain & use the compute<br/>role's credentials"]
    G6 --> J1["1 · Reach metadata from app context"]
    G6 --> J2["2 · Defeat the metadata protection"]
    G6 --> J3["3 · Use the stolen credentials"]

    J1 --> J11["1.1 SSRF via a URL-fetch feature<br/>(avatar-by-URL, webhook, link unfurl)<br/><i>skill: low-med · F-13</i>"]
    J1 --> J12["1.2 SSRF via server-side render<br/>(PDF / SVG / image)<br/><i>skill: medium</i>"]
    J1 --> J13["1.3 RCE in a parser → direct read<br/><i>skill: high · overlaps E3</i>"]

    J2 --> J21["2.1 IMDSv1 present → one GET returns creds<br/><i>skill: low</i>"]
    J2 --> J22["2.2 IMDSv2 but hop limit >1 / open proxy<br/>allows the token PUT + GET<br/><i>skill: high</i>"]
    J2 --> J23["2.3 Container creds via 169.254.170.2<br/>or leaked env vars<br/><i>skill: low</i>"]

    J3 --> J31["3.1 GetObject on /exports/ → <b>Tree 1</b>"]
    J3 --> J32["3.2 kms:Decrypt if the role has it → <b>Tree 5</b>"]
    J3 --> J33["3.3 sts:AssumeRole / iam:PassRole to<br/>broaden → <b>Tree 8</b>"]

    style G6 fill:#8b1a1a,color:#fff
    style J11 fill:#5c1a1a,color:#fff
    style J21 fill:#5c1a1a,color:#fff
```

**The control is one line:** IMDSv2 required + metadata hop limit = 1 defeats branch 2 almost entirely — a single leaf-to-control mapping, which §8.1 says is the signal a branch is done.

---

## 8.6c Tree 7 — Abuse a Human Identity (insider · departed · help-desk) *(v8)*

A **means** tree owned by IAM + IT/HR, not by the platform team. Note how many leaves carry *skill: none* — the defining feature of human-identity abuse is that the means and opportunity already exist; only motive changes.

```mermaid
flowchart TD
    G7["<b>GOAL</b><br/>Act with legitimate<br/>human privilege"]
    G7 --> K1["1 · Standing insider access"]
    G7 --> K2["2 · Residual / recovered access"]
    G7 --> K3["3 · Social-engineer the identity"]
    G7 --> K4["4 · Out-of-band change"]

    K1 --> K11["1.1 Analyst bulk-reads beyond need-to-know<br/><i>skill: none · F-19 · P-09</i>"]
    K1 --> K12["1.2 Insider grants self more (no SoD)<br/><i>skill: none · E10</i>"]

    K2 --> K21["2.1 Departed employee's unrevoked access key<br/><i>skill: none · F-15</i>"]
    K2 --> K22["2.2 Personal fork w/ still-valid deploy token<br/><i>skill: none · F-15 · F-17</i>"]

    K3 --> K31["3.1 Help-desk MFA reset / account recovery<br/><i>skill: low-med · F-16 · ATT&CK T1621</i>"]
    K3 --> K32["3.2 MFA-fatigue push-bombing<br/><i>skill: low</i>"]
    K3 --> K33["3.3 SIM-swap on SMS 2FA<br/><i>skill: medium</i>"]

    K4 --> K41["4.1 Console change in prod, bypassing the<br/>pipeline — weak attribution<br/><i>skill: none · R6</i>"]

    style G7 fill:#8b1a1a,color:#fff
    style K21 fill:#5c1a1a,color:#fff
    style K31 fill:#5c1a1a,color:#fff
```

> 💡 **Bridge.** Branch 2 collapses to nearly zero the moment IAM users and long-lived keys are replaced with federated, short-lived credentials (finding S6's fix, [12](12-identity-iam-entra.md)) — the *departed employee* has nothing to keep. Branch 3 is why the help-desk needs a scripted identity-verification procedure: the strongest MFA in the world is worthless if a support agent will reset it for a confident caller.

---

## 8.6d Tree 8 — Subvert the Deploy Pipeline (supply chain) *(v8)*

A **means** tree that ends where F-09 begins: the deploy role. The attacker never touches AWS directly — they get *your* trusted pipeline to carry the payload across the boundary with a legitimate CloudTrail signature.

```mermaid
flowchart TD
    G8["<b>GOAL</b><br/>Apply a malicious change<br/>via the trusted pipeline"]
    G8 --> L1["1 · Poison the code the pipeline runs"]
    G8 --> L2["2 · Compromise the pipeline identity"]
    G8 --> L3["3 · Use the deploy role"]

    L1 --> L11["1.1 Dependency confusion / typosquat<br/><i>skill: low-med · F-17</i>"]
    L1 --> L12["1.2 Poisoned Terraform module (repointed tag)<br/><i>skill: medium · F-17</i>"]
    L1 --> L13["1.3 Trojaned provider binary<br/><i>skill: high · F-17</i>"]
    L1 --> L14["1.4 Compromised GitHub Action @ mutable tag<br/><i>skill: medium · F-17</i>"]

    L2 --> L21["2.1 Poisoned-pipeline-execution via fork PR<br/><i>skill: medium · F-09/F-17</i>"]
    L2 --> L22["2.2 Over-broad OIDC trust (repo/branch<br/>unscoped) → assume deploy role<br/><i>skill: medium · E5</i>"]
    L2 --> L23["2.3 Compromised maintainer account<br/><i>skill: medium</i>"]

    L3 --> L31["3.1 PutBucketPolicy → open bucket → <b>Tree 1</b>"]
    L3 --> L32["3.2 Disable BPA if no SCP above it → <b>F-02</b>"]
    L3 --> L33["3.3 Rewrite KMS key policy → <b>Tree 5</b>"]

    style G8 fill:#8b1a1a,color:#fff
    style L11 fill:#5c1a1a,color:#fff
    style L22 fill:#5c1a1a,color:#fff
```

**The SCP backstop is what caps this whole tree:** an org-level `Deny` on `s3:PutBucketPublicAccessBlock` and on editing the bucket/key policy sits *above* layer 3, so even a fully compromised deploy role can't reach leaf 3.2 or 3.3 ([04 §4.14](04-dfd-library.md)).

---

## 8.6e Tree 9 — Hijack the Autonomous Agent *(v8)*

A **means** tree unique to 2020s architectures. The agent (actor A-6) is the first component in this system that *makes decisions* on content untrusted users control — so the classic "untrusted input" problem becomes "untrusted **instructions**."

```mermaid
flowchart TD
    G9["<b>GOAL</b><br/>Make the agent exfiltrate,<br/>tamper, or misuse its creds"]
    G9 --> M1["1 · Inject instructions it will read"]
    G9 --> M2["2 · Exploit excessive agency"]
    G9 --> M3["3 · Exfiltrate via its outputs"]

    M1 --> M11["1.1 Indirect prompt injection in an avatar<br/>(EXIF / filename)<br/><i>ties F-12 · F-18</i>"]
    M1 --> M12["1.2 Injection in an export cell / manifest<br/>the agent summarizes<br/><i>F-18</i>"]

    M2 --> M21["2.1 Agent role holds PutObject/Delete →<br/>tamper / destroy on instruction<br/><i>F-18 → Tree 2</i>"]
    M2 --> M22["2.2 Agent role holds kms:Decrypt →<br/>read encrypted data → <b>Tree 5</b>"]
    M2 --> M23["2.3 No human-in-the-loop on<br/>state-changing tools"]

    M3 --> M31["3.1 Agent summarizes PII into a<br/>lower-trust channel<br/><i>I15 · F-18</i>"]
    M3 --> M32["3.2 Agent writes data to /public/<br/>on instruction<br/><i>F-18</i>"]

    style G9 fill:#8b1a1a,color:#fff
    style M11 fill:#5c1a1a,color:#fff
    style M23 fill:#5c1a1a,color:#fff
```

> 💡 **Bridge — F-12 and Tree 9 are the same file, a worse reader.** F-12's polyglot avatar needs a downstream human to open it; here the agent "opens" it every run, *inside* the trust boundary, holding real credentials. The whole tree collapses under one principle — **Least Agency** (LA): read-only role scoped to exactly the needed prefixes (kills branch 2), a human gate on every state-changing tool (kills 2.3, 3.2), and treat every byte the agent reads as hostile instructions, not just hostile data (the only real answer to branch 1).

**Grounding for Trees 6–9:** CWE-918 (SSRF) · CWE-441 (Unintended Proxy/Confused Deputy) · CWE-1357 (Reliance on Insufficiently Trustworthy Component) · CWE-266/269 (Privilege management) · CWE-640 (Weak account-recovery) · CWE-77 (Command/instruction injection, the agent analogue) · ATT&CK **T1552.005** (Cloud Instance Metadata API), **T1621** (MFA Request Generation), **T1195** (Supply Chain Compromise), **T1078.004** (Valid Accounts: Cloud).

---

## 8.7 CAPEC — Grounding Trees in Documented Attacks

> 📘 **Theory.** CAPEC (Common Attack Pattern Enumeration and Classification) was released in 2007 by the US Department of Homeland Security and is actively maintained. It catalogs **common attack patterns**: the methods attackers actually use. The premise is that most attacks follow patterns, so understanding the patterns lets you build the right defenses.

### Anatomy of a CAPEC entry

| Field | What it gives you |
|---|---|
| **Description / Extended description** | What the pattern is |
| **Weakness** | The associated CWE the attack exploits |
| **Likelihood / Typical severity** | Baseline ratings |
| **Relationships** | Parent and child patterns — how it generalizes and specializes |
| **Execution flow** | **Explore → Experiment → Exploit** step-by-step |
| **Prerequisites** | What must be true for it to work |
| **Skills required** | Attacker capability level |
| **Resources required** | What the attacker needs |
| **Indicators** | What defenders would observe |
| **Consequences** | Impact mapped to C/I/A and access control |
| **Mitigations** | How to defend |
| **Example instances** | Real cases, often with CVE references |

> 📘 **The Explore/Experiment/Exploit structure is the borrowable part:**
> - **Explore** — how to find a system to attack (find the weakness)
> - **Experiment** — determine how to exploit a system that has the weakness
> - **Exploit** — conduct the actual attack

### 🏢 An execution flow for our top finding

**Pattern: Anonymous retrieval of data from a misconfigured object store**

| Phase | Steps | Techniques |
|---|---|---|
| **Explore** | Identify candidate bucket names | Query internet-wide scanner services that index public buckets · brute-force common naming conventions (`<company>-prod-backups`, `<company>-customer-data`) · search public code repos, CI logs, and IaC for bucket ARNs · read error messages from the application that leak paths |
| **Experiment** | Determine access level | Issue an unauthenticated `ListBucket` — success reveals the full key index · issue `GetObject` on a sampled key · test whether `PutObject` also succeeds (escalates to Tree 2) · compare `403` vs `404` to map existence without read access |
| **Exploit** | Retrieve at scale | Enumerate all keys · bulk-download · prioritize by filename pattern (`*customer*`, `*export*`, `*.csv`) · exfiltrate before any rate-based detection could fire — noting there is no authentication event to alert on |

**Prerequisites:** the bucket exists with a public read grant; the bucket name is discoverable.
**Skills required:** **Low** — a browser or a single CLI command.
**Resources required:** **None.**
**Indicators:** a spike in anonymous `GetObject` requests · sequential key access patterns · unusual source geography — *all of which require CloudTrail data events to be visible at all* (finding LOG-1).
**Consequences:** Confidentiality — read data at scale. Compliance — mandatory breach notification.
**Related weaknesses:** CWE-284 (Improper Access Control) · CWE-668 (Exposure of Resource to Wrong Sphere).

> 💡 **Bridge.** Writing the execution flow does something a bare finding doesn't: the **Indicators** row generates detection requirements directly, and the **Experiment** row tells your red team exactly what to test. One structure, three consumers.

---

## 8.8 The CWE → CAPEC → ATT&CK Chain

> 📘 **Theory.** Three layers of the same MITRE ecosystem, not competing alternatives.

```mermaid
flowchart LR
    CWE["<b>CWE</b><br/>Root-cause weakness<br/>CWE-284 Improper Access Control"]
    CAPEC["<b>CAPEC</b><br/>Attack pattern exploiting it<br/>+ Explore/Experiment/Exploit"]
    ATTACK["<b>ATT&CK</b><br/>Technique observed in the wild<br/>T1530 Data from Cloud Storage"]
    CWE -->|"is exploited by"| CAPEC
    CAPEC -->|"executed in the wild as"| ATTACK
    CWE -.->|"developers fix this"| Dev(("Dev"))
    CAPEC -.->|"red team tests this"| Red(("Red team"))
    ATTACK -.->|"detection engineers hunt this"| Det(("Detection"))
```

**Three audiences, three IDs, one finding.** Cite all three and each reader gets what they need: *why it's possible* (CWE), *how it'd be attacked* (CAPEC), *what to hunt for in logs* (ATT&CK).

---

## 8.9 Using a Catalog Without Becoming Its Prisoner

> 📘 **The rearview-mirror anti-pattern.** A methodology built exclusively on a threat library — especially one derived from statistical analysis of *your own* past incidents — trains the team to look only at what has already happened. Technologies change; new attack vectors appear constantly.
>
> Libraries have real value as **educational devices**, as a reference point for unforgivable issues, and as **starting points for deriving further attack vectors**. Treat a catalog entry as the root of a new branch, not as a checkbox. The value is in *how* the catalog is used.

### 🏢 CAPEC applicability review (PASTA Stage 4 style)

| CAPEC | Pattern | Applicable? | Reasoning |
|---|---|---|---|
| CAPEC-116 | Excavation | **Yes** | Public ListBucket makes systematic retrieval trivial |
| CAPEC-150 | Collect data from common resource locations | **Yes** | Predictable bucket and key naming |
| CAPEC-1 | Accessing functionality not properly constrained by ACLs | **Yes** | Legacy ACL evaluation path still active |
| CAPEC-66 | SQL injection | **No** | No SQL interpreter in this scope |
| CAPEC-549 | Local execution of code | **Partial** | Only via the UGC parsing path (Tree 4, D3.3) |
| **CAPEC-664** | Server Side Request Forgery | **Yes** *(v8)* | Any URL-fetch feature reaches IMDS → Tree 6 / F-13 |
| **CAPEC-122** | Privilege Abuse | **Yes** *(v8)* | Over-broad KMS key policy and deploy-role scope — Trees 5 & 8 |
| **CAPEC-233** | Privilege Escalation | **Yes** *(v8)* | `kms:PutKeyPolicy`/`CreateGrant` self-grant (E6/E7); `iam:PassRole` chains (E8) |
| **CAPEC-437** | Supply Chain (+ CAPEC-538 Open-Source Library Manipulation) | **Yes** *(v8)* | Poisoned module/provider/Action/dependency — Tree 8 / F-17 |
| **CAPEC-151** | Identity Spoofing | **Yes** *(v8)* | Help-desk-mediated MFA reset / recovery — Tree 7 / F-16 |
| **CAPEC-549** *(cross-account variant)* | Confused-deputy via missing `ExternalId` | **Yes** *(v8)* | Partner `AssumeRole` — CWE-441 / F-14 |
| **Indirect prompt injection** | *(no stable CAPEC yet)* | **Yes — catalog gap** *(v8)* | Grounded via **OWASP LLM Top 10** (LLM01 Prompt Injection, LLM06 Excessive Agency) — Tree 9 / F-18 |

> 💡 **Bridge.** Recording the **"No"** rows matters as much as the "Yes" rows. It documents that you considered and excluded them — which is what makes the next review able to focus on what changed rather than starting over.

> 📘 **The last row is §8.9's own thesis, live.** Indirect prompt injection has *no stable CAPEC entry* because the catalogs lag the technology — exactly the **rearview-mirror** limit this section warns about. The response isn't to skip the threat because no catalog blesses it; it's to ground it in the closest living reference (OWASP's LLM Top 10) and treat the catalog gap as a signal that this is a *deriving-a-new-branch* moment, not a checkbox moment. Roughly a third of this guide's real findings (F-07, F-12, and now F-18) never appeared in any catalog first.

---

## 8.10 Attack Chains — Threading the Forest (the APT lens) *(v8)*

> 📘 **Theory.** A tree decomposes *one* goal. A real advanced adversary — actor **A-11**, nation-state / APT — doesn't respect that partition: they **chain leaves across trees**, where each step's *output* is the next step's *precondition*. An attack chain (a.k.a. kill chain / attack path) is the artifact that shows this. It matters because **the sum is worse than any single finding**: no individual leaf here is rated Critical on its own, yet the chain achieves total, persistent, unattributable compromise. This is the "step back and look at the whole system" that §6.3's Warning 2 demands, made concrete.

### 🏢 Chain AC-1 — "Patient theft of the whole estate"

```mermaid
flowchart LR
    S0["<b>0 · Recon</b><br/>scanner services index<br/>the bucket<br/><i>Tree 1 · 1.3</i>"]
    S1["<b>1 · Initial access</b><br/>SSRF → IMDS creds<br/><i>Tree 6 · J1.1→J2.1</i>"]
    S2["<b>2 · Escalate</b><br/>role can AssumeRole to<br/>the deploy role<br/><i>Tree 6 · J3.3 → Tree 8</i>"]
    S3["<b>3 · Persist (crypto)</b><br/>CreateGrant on the CMK →<br/>durable covert decrypt<br/><i>Tree 5 · 5.1 · ENC-8</i>"]
    S4["<b>4 · Blind the defender</b><br/>confirm data events off;<br/>keep Bucket Keys on<br/><i>LOG-1 · R8</i>"]
    S5["<b>5 · Low-and-slow exfil</b><br/>pull PII under a trusted role,<br/>below rate alarms<br/><i>Tree 1 · Tree 5 · 1.2</i>"]

    S0 --> S1 --> S2 --> S3 --> S4 --> S5
    style S3 fill:#5c1a1a,color:#fff
    style S5 fill:#8b1a1a,color:#fff
```

| # | Step | ATT&CK tactic / technique | Individual severity | The control that **breaks the chain here** |
|---|---|---|---|---|
| 0 | Passive discovery | Reconnaissance · T1596 | Low | Bucket not public; opaque naming (F-03/P-05) |
| 1 | SSRF → instance credentials | Credential Access · **T1552.005** | Medium (F-13) | IMDSv2 + hop-limit 1; egress control |
| 2 | Assume the deploy role | Priv-Esc / Lateral · **T1078.004** | High (F-09) | Scoped role `Resource`; no `PassRole`/`AssumeRole` on the compute role |
| 3 | Grant durable decrypt on the CMK | Persistence · T1098 | High (ENC-8) | Deny `kms:CreateGrant`/`PutKeyPolicy` outside break-glass; alarm on both |
| 4 | Confirm no object-level audit | Defense Evasion · T1562.008 | *multiplier* (LOG-1) | CloudTrail data events + GuardDuty S3; per-object decrypt visibility |
| 5 | Slow, credentialed exfiltration | Exfiltration · **T1530** | Critical (aggregate) | Least privilege on the reader/role; anomaly detection on volume & geography |

> 💡 **Bridge — why the chain is the finding.** Read the "individual severity" column: **not one step is Critical by itself**, and step 0 is rated Low. Score them in isolation and a triage process could rationally defer every one. The chain is what turns five deferrable findings into an existential one — and it also shows that **you do not need to fix all five to win**. Breaking *any single link* collapses the whole path. The cheapest link to break is step 1 (IMDSv2 is one setting), and the highest-leverage is step 4 (LOG-1), because a defender who can *see* step 5 can respond even if steps 1–3 succeeded. This is the argument for defense-in-depth stated as arithmetic rather than as a slogan.

> 📘 **How to use chains without drowning.** Don't enumerate every path — that's combinatorially hopeless. Build a chain only for your **most-capable modeled adversary** against your **crown jewels** (here: A-11 vs. the PII exports), and only deep enough to expose the *cheapest link to break*. One or two chains per system is plenty; their job is to justify the defense-in-depth investments that per-finding scoring systematically under-prices. Chain AC-1 becomes **F-20** in the register — a meta-finding whose treatment is "ensure at least two independent links carry a release-blocking control."

---

[← 07 LINDDUN](07-linddun-privacy.md) · [Contents](README.md) · [09 Risk Scoring →](09-risk-scoring.md)
