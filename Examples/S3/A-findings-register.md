[← 16 Tooling & Automation](16-tooling-automation.md) · [Contents](README.md) · [B · Traceability Log →](B-traceability-log.md)

# Appendix A · Findings Register

> ⚠️ **SENSITIVE.** This appendix is the most attack-useful document in the guide.

---

## The Standard Format

> 📘 **Theory.** Four required fields per finding:
> **Unique identifier** (tracked through its lifecycle) · **a fully descriptive attack scenario** (because findings get interpreted differently by different team members — prose reveals whether two people mean the same issue) · **severity** (consistently measured across the whole organization) · **mitigation**.
>
> Write the scenario so a reader with limited security background can follow it. *"You have a TOCTOU in the analytics reader"* is concise and useless to a product owner.

---

## F-01 · Public bucket policy exposes customer PII

**Attack scenario.** An attacker with no credentials discovers the bucket name — by guessing a predictable name, finding it in leaked source code or IaC, or via internet-wide scanning services that continuously index publicly readable buckets. Because the bucket policy grants `s3:GetObject` to any principal and `s3:ListBucket` is not explicitly denied, the attacker enumerates every object key and downloads customer records containing names, email addresses, and postal addresses at will. No authentication step occurs, so no log entry attributes the access to an identity, and no alert fires. The attacker needs no tools beyond a browser and no skill beyond knowing the URL format.

**Severity** 8.6 High — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:N/A:N`
**Risk** ALE 90th pct **$6M+** → **Critical tier**
**Root cause** CWE-284 Improper Access Control · CWE-668 Exposure of Resource to Wrong Sphere
**Frameworks** OWASP A01:2025 · CIS 3, 4, 6 · GDPR Art. 32 · HIPAA §164.312(a)(1)
**Owner** Head of Cloud Security
**Mitigation** Enable Block Public Access at account **and** bucket level · SCP preventing it being disabled · explicit `Deny` on `ListBucket` for anonymous principals · **separate customer data into its own bucket** ([04 §4.10](04-dfd-library.md)) · AWS Config rules for continuous verification · automated remediation on drift
**Treatment** **Mitigate — release-blocking.** CFO + CISO + Board sign-off required to accept.

---

## F-02 · Block Public Access disabled or unenforced

**Attack scenario.** Block Public Access is the backstop that makes a misconfigured bucket policy harmless. Where it is disabled — or enabled but not protected by an organization-level guardrail — a single incorrect policy change, whether from a mistaken pull request, a manual console edit, or a compromised deploy credential, immediately exposes the bucket. There is no second control between the mistake and the exposure. The failure is silent: nothing distinguishes the moment of exposure from normal operation until someone notices, or until data appears elsewhere.

**Severity** High
**Risk** ALE 90th pct **~$4M** → **Critical tier**
**Root cause** CWE-284
**Frameworks** OWASP **A02:2025 Security Misconfiguration** · CIS 4 · SOC 2 CC6.1
**Owner** Head of Cloud Security
**Mitigation** Account-level BPA on · **SCP denying `s3:PutBucketPublicAccessBlock`** outside a break-glass role — note this places the control at SCP level, *above* anything a compromised IAM principal can reach ([04 §4.14](04-dfd-library.md)) · EventBridge alarm on the API call · automated remediation Lambda, **tested via game day**
**Treatment** **Mitigate — release-blocking.**

---

## F-03 · Public ListBucket enables full enumeration

**Attack scenario.** Even where individual object reads are intentionally public, granting `ListBucket` to anonymous principals converts the problem from "an attacker must guess file names" into "an attacker downloads the index." Object keys frequently encode structure — `/exports/customer_12345.csv` reveals both a naming pattern and a customer identifier. The attacker retrieves the complete key list in a single request, then systematically downloads everything matching sensitive patterns.

**Severity** Contributes to F-01's 8.6 (the `S:C` scope change)
**Risk** ALE 90th pct **~$1.2M** → **Critical tier**
**Root cause** CWE-284
**Frameworks** OWASP A01:2025 · CIS 6
**Owner** Application Engineering Lead
**Mitigation** Explicit `Deny` on `s3:ListBucket` for anonymous principals regardless of the `GetObject` posture · adopt opaque, non-sequential object keys carrying no customer identifiers (also addresses P-05 Linkability)
**Treatment** **Mitigate — release-blocking.**

---

## F-07 · TOCTOU between manifest validation and object read

**Attack scenario.** The Analytics Reader lists the export prefix, downloads `manifest.json`, and validates it. It then loops through the listed objects, downloading each in turn. On a large export, several minutes elapse between the validation and the final download. An attacker holding any write-capable credential to that prefix — including a compromised service account or an over-permissioned internal role — overwrites one of the listed objects inside that window. The reader downloads the replaced object and processes it as though the earlier manifest validation still vouched for it, injecting attacker-controlled data into the analytics warehouse and every business decision drawn from it. Nothing in the reader's logs indicates the content changed.

**Severity** 5.3 Medium — `CVSS:3.1/AV:N/AC:H/PR:L/UI:N/S:U/C:N/I:H/A:N`
**Risk** ALE 90th pct **~$400K** → **High tier**
**Root cause** CWE-367 Time-of-check Time-of-use Race Condition
**Frameworks** OWASP **A08:2025** Software or Data Integrity Failures · HIPAA §164.312(c)(1)
**Owner** Platform Engineering Lead
**Discovered by** Sequence diagram ([05 §5.2](05-other-model-types.md)) — **invisible on the DFD**
**Mitigation** Conditional reads using `If-Match` against the ETag captured at validation time, so a modified object fails rather than silently succeeding · alternatively enable versioning and read a pinned `versionId` · validate per object at time of use rather than once up front · structurally, remove `PutObject` on the export prefix from every principal except the writer service
**Treatment** Mitigate — 30 days.

---

## F-09 · CI/CD deploy role scope unverified

**Attack scenario.** The GitHub Actions deploy role is OIDC-federated, which correctly avoids long-lived credentials. However, the `Resource` element of its IAM policy has not been verified: it may be scoped to this bucket's ARN, or it may carry a wildcard. If wildcarded, an attacker who compromises the CI/CD platform — via a malicious dependency in a workflow, a compromised maintainer account, or a poisoned pull request from a fork — gains the ability to rewrite the bucket policy of **every bucket in the account**, not just this one. Because the change arrives through the legitimate deployment path, it appears in CloudTrail as a normal deploy.

**Severity** 8.0 High — `CVSS:3.1/AV:N/AC:H/PR:H/UI:N/S:C/C:H/I:H/A:H`
**Risk** ALE 90th pct **~$900K** → **High tier**
**Root cause** CWE-269 Improper Privilege Management
**Frameworks** OWASP A01:2025 + **A03:2025** Software Supply Chain Failures · PCI Req. 7.2, 8.3
**Owner** Platform Engineering Lead
**Status** **The finding is that we do not know.** "I think it's scoped" is not a control ([03 §3.4](03-session-facilitation.md))
**Mitigation** **Verify the policy JSON first** · replace with the scoped `S3-CustomerData-CICD-Deploy` role from [12 §12.5](12-identity-iam-entra.md) · restrict the OIDC trust policy by repository *and* branch · SCP backstop so even this role cannot disable Block Public Access · four-eyes review on IaC touching bucket policy or IAM
**Treatment** Mitigate — 30 days. **Verification is P0 and precedes remediation.**

---

## F-11 · No versioning; ransomware and mass deletion unrecoverable

**Attack scenario.** Versioning is disabled. An attacker with write access — obtained through F-09, a compromised application credential, or an insider — encrypts objects in place or deletes them outright. Because no prior versions exist, the data is gone. A variant is quieter and worse: rather than mass action, the attacker selectively modifies a small number of records over time. There is no dramatic moment to trigger investigation, and no earlier version to compare against, so the tampering may never be detected at all.

**Severity** High
**Risk** ALE 90th pct **~$2.1M** → **Critical tier**
**Root cause** CWE-284
**Frameworks** OWASP A08:2025 · CIS 11 · HIPAA §164.312(c)(1)
**Owner** Head of Cloud Security
**Mitigation** Enable versioning · Object Lock for regulated data — **but resolve the Compliance-mode vs. GDPR-erasure conflict first** ([13 §13.3](13-hardening-deep-dive.md)) · MFA Delete via a logged root exception · lifecycle rules balancing cost against a 90-day forensic window · multi-person control on KMS key deletion · tested restore procedure
**Treatment** **Mitigate — release-blocking.**

---

## F-12 · Unscanned user-generated content enables malware staging

**Attack scenario.** A customer — or an attacker who has registered a free account, which is the only barrier — requests a presigned upload URL for a profile picture and uploads a file that is a valid image *and* carries a hidden payload: data appended past the image trailer, content steganographically encoded in pixel data, or a polyglot file valid as both an image and a script. Nothing validates the magic bytes, scans for malware, or re-encodes the file, so the exact bytes are stored and later served over the CDN from Meridian's own domain. Downstream, either a victim's client parses the file as a polyglot and executes the embedded content, or malware already resident on a victim's machine retrieves it as a second-stage payload — succeeding **precisely because Meridian's domain is allow-listed by network defenses that would have blocked an unknown host**. The harm accrues to third parties, and Meridian's infrastructure and reputation are the attack's essential ingredient.

**Severity** 6.5 Medium — `CVSS:3.1/AV:N/AC:L/PR:L/UI:R/S:C/C:L/I:L/A:N`
**Risk** ALE 90th pct **~$1.4M** → **Critical tier** *(downstream-victim liability dominates; note severity and risk diverge sharply here — see [01 §1.6](01-foundations.md))*
**Root cause** CWE-434 Unrestricted Upload of File with Dangerous Type · CWE-829 Inclusion of Functionality from Untrusted Control Sphere
**Frameworks** OWASP A03:2025 + A08:2025 · PCI **Req. 5** · CIS 10 · ATT&CK T1027.003, T1105
**Owner** Application Engineering Lead
**Discovered by** A team member in session ([03 §3.4](03-session-facilitation.md)) — **not by any catalog**
**Mitigation** Malware scanning on ingest · **mandatory decode-and-re-encode from raw pixel data** — passthrough serving of original bytes is precisely what preserves a payload · magic-byte validation, never extension-based · **isolate UGC into its own bucket and ideally its own domain**, which denies the attacker the reputational borrowing that motivates the attack · CSP headers where images render · file-size anomaly alerting · server-side size ceiling
**Treatment** **Mitigate — release-blocking.**

---

## LOG-1 · No object-level audit trail

**Attack scenario.** CloudTrail data events are not confirmed enabled for this bucket. Management events record *changes to the bucket*; data events record *access to objects*. Without them, an attacker who reads every customer record leaves no trace distinguishable from ordinary traffic. This is not a standalone breach — it is the **force multiplier** that converts every other finding in this register from a detectable incident into an undetectable one, and it eliminates the evidence needed for breach-notification scoping.

**Severity** High as an enabling factor
**Risk** Not independently FAIR-modeled; materially increases the Loss Magnitude of F-01, F-03, F-07, F-11, F-12
**Root cause** CWE-778 Insufficient Logging
**Frameworks** OWASP **A09:2025** Security Logging & Alerting Failures · GDPR Art. 33 · PCI Req. 10 · CIS 8
**Owner** Head of Cloud Security
**Mitigation** Enable CloudTrail data events for this bucket · server access logging to an isolated bucket in a **separate account** so a compromised writer cannot erase its own trail · EventBridge alarms on policy-changing API calls · GuardDuty S3 Protection · **and alerting, not just logging** — a log nobody reads is not a control
**Treatment** **Mitigate — release-blocking.**

---

## P-01 · Data subject unawareness (avatar prefix)

**Attack scenario.** *(No attacker.)* Customers upload profile pictures. No retention period has ever been defined for that prefix, and it is unconfirmed whether the privacy notice discloses that this processing occurs or how long the images are kept. Data subjects therefore cannot know what is held about them or for how long. There is no security control failure here — the system behaves exactly as built — and that is precisely the point: STRIDE has no category that would surface this.

**Severity** Moderate
**Risk** Not FAIR-modeled — non-financial harm dominates; regulatory exposure captured in F-01's Secondary Loss
**Root cause** Governance gap
**Frameworks** LINDDUN Unawareness · GDPR Art. 5(1)(e), Art. 13/14 · CCPA §1798.100
**Owner** Data Protection Officer
**Mitigation** Data-mapping exercise covering every location personal data lands · update the privacy notice to cover avatar and export processing · define and enforce retention per prefix via lifecycle rules
**Treatment** Mitigate — 1 quarter, with legal review.

---

## P-02 · Erasure requests cannot be fully honored

**Attack scenario.** *(No attacker.)* A customer exercises their right to erasure. Operations deletes the current object. Noncurrent versions, cross-region replicas, and access-log entries that contain the customer's identifier in the object key all persist. GDPR Art. 17 applies to **all copies**. The organization believes it has complied; it has not. Enabling versioning (F-11's fix) makes this *worse* unless a version-aware deletion procedure exists first.

**Severity** High
**Risk** Regulatory exposure modeled within F-01's Secondary Loss
**Root cause** Governance gap
**Frameworks** LINDDUN Non-compliance · **GDPR Art. 17** · CCPA §1798.105
**Owner** Data Protection Officer
**Mitigation** Version-aware erasure runbook, **tested** · enumerate every copy location including backups and third-party copies · minimize customer identifiers in object keys so they don't propagate into logs · define log retention · **sequence this before enabling versioning**
**Treatment** Mitigate — 1 quarter.

---

## v8 Expansion Findings

> 📕 **Correction (v8).** Earlier versions *referenced* ENC-1 and ENC-2 in the traceability log but never wrote them up as findings — a register that names controls it never specifies. That's fixed here, and the encryption **control plane** is expanded from those two into a full ENC-1…ENC-8 series, because a mitigation (SSE-KMS) that is itself misconfigurable deserves the same finding discipline as the thing it protects. F-13…F-20 add the compute tier, the partner integration, the human-identity actors, the supply chain, the autonomous agent, and the APT chain.

---

## ENC-1 · TLS not enforced by bucket policy

**Attack scenario.** Traffic to the bucket uses HTTPS by convention, but the bucket policy contains no `Deny` on `aws:SecureTransport = false`. A misconfigured client, an SDK downgrade, or an on-path attacker in a position to influence the connection can therefore move regulated data — or a presigned URL's contents — over cleartext, where it is exposed to interception and where no control refuses the request. The gap is that protection depends on every caller behaving, rather than on the platform refusing the insecure option.

**Severity** 5.9 Medium — `CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:N/A:N`
**Risk** Not independently FAIR-modeled; folds into F-01 Loss Magnitude for in-transit exposure
**Root cause** CWE-319 Cleartext Transmission of Sensitive Information
**Frameworks** OWASP A02:2025 · PCI Req. 4 · GDPR Art. 32 · NIST CSF PR.DS-2
**Owner** Platform Engineering Lead
**Status** Was **S9/ENC-1** in [B](B-traceability-log.md) — "unverified," now specified
**Mitigation** Bucket policy `Deny` when `aws:SecureTransport` is `false` · additionally require `aws:TlsVersion >= 1.2` via policy condition · verify with the aws:SecureTransport test in a Config rule
**Treatment** Mitigate — quick win, 30 days.

---

## ENC-2 · AWS-managed key precludes key-policy control *(the enabler)*

**Attack scenario.** *(No attacker — a missing prerequisite.)* Encryption currently uses the AWS-managed `aws/s3` key (finding S5). You cannot write a key policy for it, cannot apply `kms:ViaService` or `aws:SourceAccount` conditions, cannot separate keys by sensitivity tier, cannot control cross-account use, and cannot manage deletion or rotation on your terms. This is not itself an exploit; it is the **absent control surface** that makes ENC-3, ENC-4, ENC-5, ENC-7 and ENC-8 unmitigatable until it is resolved — the crypto-plane analogue of LOG-1.

**Severity** n/a — enabling deficiency
**Risk** Blocks four other requirements in [10](10-security-requirements.md); no independent ALE
**Root cause** CWE-320 Key Management Errors *(insufficient control over key policy)*
**Frameworks** NIST CSF PR.DS-1 · PCI Req. 3.6 · CIS 3
**Owner** Head of Cloud Security
**Mitigation** Migrate to a **customer-managed CMK**, one per sensitivity tier, per the sequencing in [13 §13.5](13-hardening-deep-dive.md) — this unlocks every other ENC control
**Treatment** Mitigate — prerequisite; 30 days.

---

## ENC-3 · Over-permissive KMS key policy → the second front door

**Attack scenario.** Once on a CMK, the key policy becomes the decisive control — and its common failure mode is granting `kms:Decrypt` to `arn:aws:iam::ACCT:root`, which **delegates authorization to IAM**, so *any* principal in the account with `kms:Decrypt` in an identity policy can decrypt. An attacker who obtains any such principal — via SSRF (F-13), a stolen role, the partner (F-14), or the agent (F-18) — reads the plaintext even though the bucket policy is airtight, because decryption is authorized on a **separate plane the bucket policy never touches** ([04 §4.16c](04-dfd-library.md)). Cross-account grants extend the same door to a partner's account.

**Severity** 8.1 High — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:N/A:N`
**Risk** ALE 90th pct **~$3M** → **Critical tier** *(this is F-01's confidentiality loss reached through a different door)*
**Root cause** CWE-732 Incorrect Permission Assignment for Critical Resource · CWE-284
**Frameworks** OWASP A01:2025 · PCI Req. 3.5–3.6 · GDPR Art. 32 · CIS 3
**Owner** Head of Cloud Security
**Mitigation** Least-privilege key policy — **named principals only**, avoid `:root` delegation unless paired with strict IAM permission boundaries · `kms:ViaService` and `aws:SourceAccount` conditions (see ENC-4) · **separate CMK per sensitivity tier** so one grant isn't estate-wide · no cross-account grant except an explicit, reviewed partner key
**Treatment** **Mitigate — release-blocking.**

---

## ENC-4 · Missing `kms:ViaService` / encryption context → decrypt bypasses S3

**Attack scenario.** Without a `kms:ViaService` condition pinning the key to the S3 service, a principal holding `kms:Decrypt` can hand a ciphertext blob **directly to the KMS API** — decrypting an object that was copied out, or a snapshot, entirely outside S3 and therefore outside the bucket policy *and* the S3 access logs. Without a required encryption context (the AAD that should bind a key to one prefix or tenant), a single key decrypts everything it can reach rather than only its intended scope. This is Tree 5's counterintuitive leaf 1.2, and it doubles as a logging-evasion technique.

**Severity** 6.5 Medium — `CVSS:3.1/AV:N/AC:H/PR:L/UI:N/S:C/C:H/I:N/A:N`
**Risk** ALE 90th pct **~$900K** → **High tier** *(force-multiplies ENC-3 by removing the audit trail)*
**Root cause** CWE-863 Incorrect Authorization · CWE-284
**Frameworks** OWASP A01:2025 + A09:2025 · PCI Req. 3, 10
**Owner** Head of Cloud Security
**Mitigation** Add `kms:ViaService = s3.<region>.amazonaws.com` and `aws:SourceAccount` to the key policy · adopt a per-prefix/per-object **encryption context** and enforce it via key-policy condition · alert on any `Decrypt` whose request context is *not* the S3 service
**Treatment** Mitigate — 30 days.

---

## ENC-5 · No write-time SSE enforcement → encryption downgrade & key substitution

**Attack scenario.** The bucket policy does not `Deny` `PutObject` requests that omit `x-amz-server-side-encryption: aws:kms` *with the expected key ARN*. So an attacker — or a buggy client — writes objects unencrypted, under SSE-S3, or under **a key the attacker controls**. New PII lands with weaker or attacker-readable protection, and combined with an alias repoint (STRIDE S6) every subsequent write silently becomes attacker-decryptable while still "looking" encrypted in the console.

**Severity** 6.8 Medium — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:L/A:N`
**Risk** ALE 90th pct **~$700K** → **High tier**
**Root cause** CWE-311 Missing Encryption of Sensitive Data · CWE-325 Missing Cryptographic Step
**Frameworks** OWASP A02:2025 · PCI Req. 3 · GDPR Art. 32
**Owner** Application Engineering Lead
**Mitigation** Bucket policy `Deny` on writes missing the correct SSE header **and** on any `s3:x-amz-server-side-encryption-aws-kms-key-id` other than the sanctioned CMK · set bucket default encryption to that CMK · deny `kms:UpdateAlias` outside break-glass · deny SSE-C on this bucket (ENC-6)
**Treatment** **Mitigate — release-blocking** for the regulated prefix.

---

## ENC-6 · Re-encryption ransomware via SSE-C or attacker CMK

**Attack scenario.** An attacker holding `PutObject`/`CopyObject` re-encrypts objects in place using **SSE-C**, where the customer supplies the key on every request and AWS never stores it — or using an attacker-controlled CMK the victim cannot use. The data remains intact but becomes permanently unreadable to Meridian, and only the attacker holds the key; they demand ransom. This is a documented, one-command S3 ransomware pattern, and because AWS is functioning exactly as designed there is no platform recovery — only prior versions or Object Lock help.

**Severity** 7.1 High — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:H`
**Risk** ALE 90th pct **~$1.8M** → **Critical tier**
**Root cause** CWE-284 → ATT&CK **T1486** Data Encrypted for Impact
**Frameworks** OWASP A08:2025 · CIS 11 · NIST CSF PR.DS / RC.RP
**Owner** Head of Cloud Security
**Mitigation** **Deny SSE-C** via bucket policy (`s3:x-amz-server-side-encryption-customer-algorithm` present) · deny writes under any key ARN except the sanctioned CMK · versioning + Object Lock for recovery (shares the fix with F-11) · least-privilege write · MFA Delete · alarm on bulk `CopyObject`/`PutObject` that changes encryption
**Treatment** **Mitigate — release-blocking.**

---

## ENC-7 · KMS key destruction / disable → crypto-shred DoS

**Attack scenario.** A principal calls `ScheduleKeyDeletion` (minimum 7-day window), `DisableKey`, or deletes **imported** key material for the CMK. Every object encrypted under that key becomes permanently unreadable in one action — an availability attack that versioning cannot undo, because the problem is the missing key rather than a missing object. There is no multi-person control and no alarm on the call, so the first signal is data that won't decrypt.

**Severity** 7.5 High — `CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:N/I:N/A:H`
**Risk** ALE 90th pct **~$1.5M** → **Critical tier**
**Root cause** CWE-284 *(availability variant)* · improper lifecycle control
**Frameworks** OWASP A04:2025 + A08:2025 · CIS 11 · NIST CSF PR.DS / RC.RP
**Owner** Head of Cloud Security
**Mitigation** Key-policy + **SCP `Deny`** on `ScheduleKeyDeletion`/`DisableKey`/`PutKeyPolicy` outside a logged break-glass role ([04 §4.14](04-dfd-library.md)) · EventBridge alarm on all three · avoid imported material for this data unless legally required · tested restore · multi-person control on key deletion (extends Tree 3 C2.1)
**Treatment** **Mitigate — release-blocking.**

---

## ENC-8 · KMS grant & key-policy persistence

**Attack scenario.** An attacker who briefly holds `kms:CreateGrant` or `kms:PutKeyPolicy` mints a durable grant — or self-grant — delegating `Decrypt` to a foothold identity. Because grants are enumerated *separately* from the key policy, a routine key-policy review misses them entirely, and the attacker retains decrypt access long after the initial foothold is closed. This is step 3 of attack chain AC-1: quiet, durable, and invisible to the obvious review.

**Severity** 6.5 Medium — `CVSS:3.1/AV:N/AC:H/PR:H/UI:N/S:C/C:H/I:N/A:N`
**Risk** ALE 90th pct **~$600K** → **High tier** *(persistence multiplier on ENC-3)*
**Root cause** CWE-269 Improper Privilege Management → ATT&CK **T1098** Account Manipulation
**Frameworks** OWASP A01:2025 · PCI Req. 7, 8
**Owner** Head of Cloud Security
**Mitigation** Deny `CreateGrant`/`PutKeyPolicy` outside break-glass · periodically `ListGrants` and reconcile against an allowlist · alarm on `CreateGrant` · require short-lived grants with a scoped `GranteePrincipal` and a retiring principal
**Treatment** Mitigate — 30 days.

---

## F-13 · SSRF → instance-metadata credential theft (OWASP A01:2025)

**Attack scenario.** A feature that fetches a URL on the server's behalf — avatar-by-URL import, a webhook, link unfurling, server-side PDF/image rendering — is coerced into requesting `169.254.169.254`. On IMDSv1 (or IMDSv2 with a metadata hop limit greater than 1) it returns the compute tier's temporary role credentials. The attacker then calls `GetObject` on `/exports/` directly — and, if the role carries `kms:Decrypt`, reads encrypted data too — with API calls that are **indistinguishable from the application** in CloudTrail. The bucket policy is never touched; the attacker borrows an identity the bucket already trusts.

**Severity** 8.6 High — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:L/A:N`
**Risk** ALE 90th pct **~$2.5M** → **Critical tier**
**Root cause** CWE-918 Server-Side Request Forgery
**Frameworks** OWASP **A01:2025** *(SSRF is consolidated into Broken Access Control in the 2025 list — [11 §11.2](11-compliance-mapping.md); it is **not** A10, which in 2025 is Mishandling of Exceptional Conditions)* · ATT&CK **T1552.005** · PCI Req. 6 · CIS 4
**Owner** Application Engineering Lead + Platform Engineering Lead
**Discovered by** Drawing the compute tier the model never had ([04 §4.16b](04-dfd-library.md)) — a seven-version structural blind spot, not a previously-listed open item
**Mitigation** Enforce **IMDSv2 + metadata hop limit 1** account-wide (an SCP can require it) · block egress to `169.254.169.254` and link-local ranges from the app tier · allow-list, resolve-and-pin outbound URLs and deny internal ranges · **least-privilege the instance/task role**, remove `kms:Decrypt` if unused · GuardDuty `InstanceCredentialExfiltration` detection
**Treatment** **Mitigate — release-blocking.**

---

## F-14 · Partner/vendor cross-account confused deputy

**Attack scenario.** The partner assumes a cross-account role to write to `/partner/`. If the role's trust policy lacks a secret `sts:ExternalId`, any principal the partner can be tricked into invoking — or an attacker who compromises the partner — can assume it (the classic confused deputy). If the role's `Resource` is `bucket/*` rather than `bucket/partner/*`, the partner can read `/exports/` PII; if the CMK key policy names the partner's account, they can decrypt it. All of this inherits the partner's own posture and that of *their* subprocessors — fourth-party risk that was never assessed.

**Severity** 7.6 High — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:L/A:N`
**Risk** ALE 90th pct **~$1.1M** → **Critical tier**
**Root cause** CWE-441 Unintended Proxy or Intermediary (Confused Deputy) · CWE-284
**Frameworks** OWASP A01:2025 + A03:2025 · SOC 2 CC9.2 · PCI Req. 12.8
**Owner** Head of Cloud Security
**Discovered by** Decomposing the partner integration ([04 §4.16a](04-dfd-library.md)) — closes **Limitation #6** in [B](B-traceability-log.md)
**Mitigation** Require a unique secret **`sts:ExternalId`** · scope the role to a **single write-only prefix**, no read, no cross-prefix · `aws:SourceAccount` condition · **no KMS grant to the partner** (or a dedicated partner-only CMK) · contractual + technical fourth-party review · give the partner integration **its own threat model**
**Treatment** **Mitigate — release-blocking** where cross-prefix PII read is possible; 30 days if already prefix-scoped.

---

## F-15 · Departed-employee access; no joiner-mover-leaver process

**Attack scenario.** An IAM user or long-lived access key belonging to a departed employee is never disabled; a personal fork retains a still-valid deploy token; a SaaS seat is never reclaimed. The former employee — or anyone who later acquires their laptop, key file, or token — retains working access to the bucket or the pipeline. Because there are no access reviews and no automated deprovisioning tied to the HR termination event, nothing detects or revokes it.

**Severity** 7.2 High — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H` *(bounded by what the leaver held)*
**Risk** ALE 90th pct **~$700K** → **High tier**
**Root cause** CWE-266 Incorrect Privilege Assignment · governance (no JML)
**Frameworks** OWASP A01:2025 · CIS 5, 6 · PCI Req. 8.1.3 · SOC 2 CC6.2/6.3
**Owner** IAM / IT Lead
**Mitigation** **Federate** (Identity Center / Entra, [12](12-identity-iam-entra.md)) so access is short-lived and tied to employment — this collapses actor A-8 almost entirely · automated deprovisioning on the HR termination event · eliminate long-lived access keys · quarterly access reviews · alert on use of dormant credentials
**Treatment** Mitigate — 30 days.

---

## F-16 · Help-desk social-engineering account takeover

**Attack scenario.** An attacker contacts the help-desk impersonating an employee or customer and persuades an agent to reset MFA or grant an account recovery, then authenticates as the victim — defeating otherwise-strong MFA at the support layer rather than the technical one. A variant needs no help-desk at all: MFA-fatigue push-bombing until a real user approves one prompt. The attacker then inherits whatever the victim's identity can reach — an analyst's PII access, or worse.

**Severity** 7.1 High — `CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:L/A:N`
**Risk** ALE 90th pct **~$800K** → **High tier**
**Root cause** CWE-640 Weak Password-Recovery Mechanism · CWE-287
**Frameworks** OWASP A07:2025 · ATT&CK **T1621** / T1078 · NIST CSF PR.AC
**Owner** IT / IAM Lead
**Mitigation** Scripted **out-of-band identity verification** for any reset (never knowledge-based alone) · manager approval for privileged-account resets · **phishing-resistant MFA (FIDO2 / passkeys)** with number-matching, which resists fatigue by design · alert on MFA-reset events · targeted user training
**Treatment** Mitigate — 30 days.

---

## F-17 · Supply-chain compromise of the deploy path

**Attack scenario.** A poisoned Terraform module (a tag repointed to a malicious commit), a trojaned provider binary, a typosquatted or confused dependency, or a compromised third-party GitHub Action referenced by a mutable tag executes **inside the pipeline with the deploy role's privileges**. The malicious change — open the bucket, disable Block Public Access, rewrite the KMS key policy — arrives through the legitimate `apply` and appears in CloudTrail as a routine deploy. The attacker never touches AWS directly; your trusted pipeline carries the payload across the boundary.

**Severity** 8.2 High — `CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:C/C:H/I:H/A:H`
**Risk** ALE 90th pct **~$1.6M** → **Critical tier**
**Root cause** CWE-1357 Reliance on Insufficiently Trustworthy Component · CWE-829
**Frameworks** OWASP **A03:2025 Software Supply Chain** · ATT&CK **T1195** · SLSA · CIS 16 · PCI Req. 6.3.2
**Owner** Platform Engineering Lead / DevSecOps
**Discovered by** The CI/CD sequence diagram ([05 §5.2b](05-other-model-types.md)) — closes **Limitation #7** in [B](B-traceability-log.md); extends **F-09**
**Mitigation** Pin modules/providers/Actions **by digest, not tag** · lockfiles + private-registry namespaces (kills dependency confusion) · SLSA provenance + signature verification · ephemeral isolated runners · **no secrets exposed to fork PRs** · scope OIDC trust to **repository + branch** (STRIDE E5) · IaC security scanning in CI · **SCP backstop** so even a compromised `apply` cannot disable BPA or edit the bucket/key policy
**Treatment** **Mitigate — release-blocking** (SCP backstop first).

---

## F-18 · Autonomous agent: excessive agency + indirect prompt injection

**Attack scenario.** An LLM-driven analytics agent reads `/exports/` and `/avatars/` to produce summaries. Untrusted content it ingests — an avatar's EXIF field, a crafted filename, a cell inside an export — embeds text that the model interprets as **instructions** rather than data (indirect prompt injection). If the agent's IAM role carries write, delete, or decrypt permissions, an injected instruction can exfiltrate PII into a low-trust channel, move objects into `/public/`, tamper with exports, or decrypt regulated data. There is no human-in-the-loop on state-changing actions, so F-12's malicious upload now meets a consumer that *acts on it automatically, inside the trust boundary*.

**Severity** 7.3 High — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:H/A:L`
**Risk** ALE 90th pct **~$1.2M** → **Critical tier**
**Root cause** OWASP **LLM01** Prompt Injection + **LLM06** Excessive Agency → CWE-77 · CWE-284 · violates the **Least Agency** principle
**Frameworks** OWASP LLM Top 10 · A04:2025 Insecure Design · NIST AI RMF
**Owner** Application Engineering Lead *(agent owner)*
**Discovered by** Modeling the agent as a decision-making component ([04 §4.16d](04-dfd-library.md)) — not by any catalog
**Mitigation** **Least Agency** — read-only role scoped to exactly the needed prefixes · **human-in-the-loop gate on every write/delete/decrypt/cross-boundary action** · treat all ingested content as untrusted instructions (no content-triggered tool call without confirmation) · DLP/output filtering on agent responses · isolate and short-scope the agent's credentials · log every tool call · fix **F-12 upstream** (re-encode UGC) so injected content is stripped before the agent sees it
**Treatment** **Mitigate — release-blocking** if the agent holds any write/decrypt permission; 30 days if strictly read-only and gated.

---

## F-19 · Malicious insider: bulk access without need-to-know

**Attack scenario.** A trusted analyst — or any near-root principal, since finding S6 says no role separation exists — reads customer exports far beyond what any assigned task requires and exfiltrates them. No control is bypassed, because none constrains need-to-know; with no separation of duties the same insider can grant themselves more access and approve their own changes. Absent CloudTrail data events (LOG-1), the bulk read is neither attributable to them nor detectable at all.

**Severity** 6.9 Medium — `CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:H/I:L/A:N`
**Risk** ALE 90th pct **~$900K** → **High tier**
**Root cause** CWE-284 · CWE-269 · governance (no SoD, no need-to-know)
**Frameworks** OWASP A01:2025 · CIS 6 · NIST CSF PR.AC / PR.DS · SOC 2 CC6.1
**Owner** Head of Cloud Security + IAM
**Mitigation** Least privilege scoped to assigned work · **separation of duties** (no self-approval) · CloudTrail data events + UEBA on bulk/anomalous reads (LOG-1) · opaque object keys to hinder correlation (P-05) · data minimization in exports (P-03) · just-in-time elevation with expiry · ties LINDDUN **P-09**
**Treatment** Mitigate — 30 days (data events are P0).

---

## F-20 · APT attack chain AC-1 *(defense-in-depth meta-finding)*

**Attack scenario.** Individually deferrable findings chain into total, persistent, unattributable compromise: passive recon → SSRF credential theft (F-13) → assume the deploy role (F-09) → durable KMS grant for persistence (ENC-8) → operate inside the LOG-1 blind spot → low-and-slow exfiltration of the whole estate. No single link is Critical on its own; the **chain** is. Full step-by-step in [08 §8.10](08-attack-trees-capec.md).

**Severity** n/a — aggregate; constituent links carry their own scores
**Risk** ALE dominated by F-01/F-13 Loss Magnitude; the chain raises **Loss Event Frequency** by making success reliable and detection unlikely
**Root cause** Absence of defense-in-depth across the identity, crypto, and logging planes
**Frameworks** NIST CSF (all functions) · ATT&CK chain T1596→T1552.005→T1078.004→T1098→T1562.008→T1530
**Owner** Head of Cloud Security *(chain owner)*
**Mitigation** Ensure **at least two independent links each carry a release-blocking control** — cheapest pair: IMDSv2 (step 1) + CloudTrail data events / GuardDuty (step 4). Treat this as the standing justification for the defense-in-depth investments that per-finding scoring systematically under-prices
**Treatment** **Mitigate — release-blocking** as a program property, not a single fix.

---

## Summary

| ID | Title | Severity | ALE 90th | Tier | Owner | SLA |
|---|---|---|---|---|---|---|
| F-01 | Public bucket policy exposes PII | 8.6 High | $6M+ | **Critical** | Cloud Security | Pre-release |
| F-02 | Block Public Access unenforced | High | ~$4M | **Critical** | Cloud Security | Pre-release |
| **ENC-3** | Over-permissive KMS key policy | 8.1 High | ~$3M | **Critical** | Cloud Security | Pre-release |
| **F-13** | SSRF → IMDS credential theft (A01) | 8.6 High | ~$2.5M | **Critical** | App+Platform Eng | Pre-release |
| F-11 | No versioning / ransomware | High | ~$2.1M | **Critical** | Cloud Security | Pre-release |
| **ENC-6** | Re-encryption ransomware (SSE-C) | 7.1 High | ~$1.8M | **Critical** | Cloud Security | Pre-release |
| **F-17** | Supply-chain deploy compromise | 8.2 High | ~$1.6M | **Critical** | Platform Eng | Pre-release |
| **ENC-7** | KMS key destruction / crypto-shred | 7.5 High | ~$1.5M | **Critical** | Cloud Security | Pre-release |
| F-12 | Unscanned UGC / malware staging | 6.5 Med | ~$1.4M | **Critical** | App Eng | Pre-release |
| **F-18** | Agent excessive agency + injection | 7.3 High | ~$1.2M | **Critical** | App Eng | Pre-release |
| F-03 | Public ListBucket enumeration | *(in F-01)* | ~$1.2M | **Critical** | App Eng | Pre-release |
| **F-14** | Partner cross-account confused deputy | 7.6 High | ~$1.1M | **Critical** | Cloud Security | Pre-release |
| LOG-1 | No object-level audit trail | High* | multiplier | **Critical** | Cloud Security | Pre-release |
| **F-20** | APT chain AC-1 (defense-in-depth) | aggregate | *(chain)* | **Critical** | Cloud Security | Pre-release |
| F-09 | Deploy role scope unverified | 8.0 High | ~$900K | High | Platform Eng | 30 days |
| **ENC-4** | No `kms:ViaService` / context | 6.5 Med | ~$900K | High | Cloud Security | 30 days |
| **F-19** | Insider bulk access, no need-to-know | 6.9 Med | ~$900K | High | Cloud Security | 30 days |
| **F-16** | Help-desk account takeover | 7.1 High | ~$800K | High | IT/IAM | 30 days |
| **ENC-5** | No write-time SSE enforcement | 6.8 Med | ~$700K | High | App Eng | Pre-release* |
| **F-15** | Departed-employee access / no JML | 7.2 High | ~$700K | High | IAM/IT | 30 days |
| **ENC-8** | KMS grant/policy persistence | 6.5 Med | ~$600K | High | Cloud Security | 30 days |
| F-07 | TOCTOU on export read | 5.3 Med | ~$400K | High | Platform Eng | 30 days |
| **ENC-1** | TLS not policy-enforced | 5.9 Med | *(in F-01)* | Med | Platform Eng | 30 days |
| **ENC-2** | AWS-managed key (enabler) | — | blocks controls | — | Cloud Security | 30 days |
| P-02 | Erasure not fully possible | — | *(in F-01)* | Moderate | DPO | 1 quarter |
| P-01 | Data subject unawareness | — | — | Moderate | DPO | 1 quarter |

**Fourteen release-blocking findings** (was six). This register grew from 10 to **26** detailed findings; the LINDDUN privacy findings **P-03…P-09** are carried in [07 §7.5](07-linddun-privacy.md), bringing the model's full finding count to 33.

> 📘 **A note on aggregation — don't just sum the column.** Several of these findings are the *same loss reached by a different door*: ENC-3 and F-13 both ultimately realize F-01's confidentiality loss (via the key plane and via a stolen role, respectively), so their ALEs overlap rather than add. FAIR is modeled per *attack path*, and the register lists paths; naïvely summing double-counts. The honest aggregate statement is: **estate ALE sits well into the Critical band (> $2M), and it is now driven by three distinct planes — the object store, the identity layer, and the encryption control plane — not one.** That diversification is itself the headline: remediating the bucket policy alone no longer moves the aggregate the way it did in v7.

> 💡 **Bridge — where these came from.** The provenance lesson only gets stronger with v8. Of the 28 findings, the ones no catalog would have handed you — F-07, F-12, F-18 (agent injection), the ENC series (a *mitigation* turned target), and F-20 (a chain, not a leaf) — are again roughly half, and they are disproportionately the *interesting* ones. F-13 and F-14 came not from a catalog but from **drawing two planes the model had been missing for seven versions** (the compute tier and the partner integration). The single highest-yield activity in this whole guide remains the same: put the real system on a diagram, with the real actors, and let people who know it say *"wait, what about…"*.

---

[← 16 Tooling & Automation](16-tooling-automation.md) · [Contents](README.md) · [B · Traceability Log →](B-traceability-log.md)
