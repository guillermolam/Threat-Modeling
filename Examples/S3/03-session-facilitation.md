[← 02 Business Context](02-business-context.md) · [Contents](README.md) · [04 DFD Library →](04-dfd-library.md)

# 03 · Running the Session

---

## 3.1 Why the Conversation Is the Method

> 📘 **Theory.** The product team always knows its own system better than any security expert who isn't part of it. The method's job is to **elicit** that knowledge, not substitute for it. A tool-driven or checklist-driven session produces generic findings; a well-facilitated conversation produces specific ones.

> 💡 **Bridge — the evidence from our own case.** Three of this guide's most valuable findings came from a person in the room, not from any framework: the avatar-upload feature nobody had documented (→ F-12), the deploy-role scope somebody *thought* was correct (→ F-09), and the validate-then-read gap in the analytics job (→ F-07). The frameworks created the conditions for those moments. They did not generate them.

---

## 3.2 Who to Invite

| Role | Why |
|---|---|
| **Lead architect** | Knows intended design |
| **Developers / dev leads** | Know what was *actually* built, which differs |
| **QA lead** | Often the only person who knows the edge cases and failure paths |
| **DevOps / platform** | Owns deployment, IaC, and the credentials that matter most |
| **DPO / privacy** | Required if personal data is in scope ([07](07-linddun-privacy.md)) |
| **Product owner** | Owns the business-impact answer |
| **Facilitator (you)** | Runs the session and does the drawing |

**Keep the list manageable.** Attendee count and signal quality are inversely correlated past a certain point.

---

## 3.3 Facilitation Rules

> 📘 **Theory — the ones that actually matter:**
>
> - **Timing is critical.** Too early and the design isn't formed, so you get churn as designers argue. Too late and the design is fixed, making your session a documentation exercise instead of an analysis.
> - **You do the drawing.** It puts you at the center of the conversation and frees attendees to think.
> - **Establish a blame-free zone.** People are attached to systems they built. Redirect from "who did this" to "what a great thing to have found now."
> - **No surprises.** Announce the process, the expected duration, and everyone's role in advance.
> - **Be prepared.** Read the requirements, specs, and user stories beforehand. It shows the team you're up to speed and lets you ask better questions.
> - **Expect disagreement between stakeholders.** People genuinely differ on how the system was designed versus implemented. Moderate toward the truth. These clashes are where the *eureka* moments live — where design intent and implementation reality collide and the team sees a constraint that silently changed the design.
> - **Loose ends are fine; wrong information is not.** A model with question marks beats one that looks complete but is quietly inaccurate.
> - **Watch for rabbit holes and sidebars.** Both are expensive.
> - **Feed people.** Not a joke — it measurably helps teams discuss uncomfortable topics.
> - **Get leadership buy-in first.** Attendees speak more freely when they know management supports the exercise.

---

## 3.4 🏢 Session Transcript

**Attendees:** Priya Shah (Head of Cloud Security, facilitator) · Diego Fernandez (Platform Eng Lead) · Amara Okafor (Application Eng Lead) · Sam Lin (CI/CD & DevOps Lead) · Jordan Reyes (DPO)

### Segment 1 — Building the model

> **Priya:** Before anyone says the word "threat" — who or what talks to this bucket?
>
> **Diego:** Anonymous users for the public marketing assets, the app backend for customer records, and Sam's pipeline for policy deploys.
>
> **Amara:** There's also the profile-picture upload. Customers upload avatars — same bucket, different prefix.
>
> **Priya:** *(writing)* That's an external entity and a data flow that weren't in the pre-read. Sam, does anything scan those on the way in?
>
> **Sam:** No. Presigned PUT, the object sits there, gets served back through CloudFront.
>
> **Priya:** Parking-lot that — it's a content-integrity question, not an access-control one, and I don't want to solve it now. Diego, on the customer-data path: who *initiates*?
>
> **Diego:** The backend, always. Nothing pushes into it.
>
> **Priya:** Good — initiator mark on the diagram. If we ever see an inbound-initiated connection on that path, that's an anomaly worth alerting on.
>
> **Jordan:** Coming back to avatars — is that prefix covered in our privacy notice? If customers don't know we keep those indefinitely...
>
> **Amara:** I'd have to check. I don't think retention was ever defined for that prefix.
>
> **Priya:** That's a LINDDUN finding, not a STRIDE one — Unawareness, possibly Non-compliance. Logging it, moving on.

### Segment 2 — What can go wrong

> **Priya:** Diego, walk me through the deploy role.
>
> **Diego:** OIDC-federated from GitHub Actions, scoped to this bucket's ARN.
>
> **Priya:** Scoped, or wildcarded? Can it modify *any* bucket policy in the account?
>
> **Diego:** ...I'd have to look at the JSON. I *think* it's scoped, but I've seen wildcards on other buckets.
>
> **Priya:** Then it's an open question, not a control. I'm writing it down as unverified rather than as "fine."
>
> **Amara:** On the avatars — could someone hide something malicious inside an image?
>
> **Priya:** Yes. Steganographic payload staging. It didn't make our first-pass catalog because we scoped to the export path. That earns its own attack tree.
>
> **Priya:** One more. The analytics job that reads the exports — does it check integrity and then read, or check once and read later?
>
> **Diego:** It lists objects, validates the manifest, then downloads each file in a loop. On a big export that could be a few minutes between validate and read.
>
> **Priya:** *(drawing)* That's a time-of-check-to-time-of-use window. We would never have caught that on the DFD — it needs a sequence diagram.

---

## 3.5 🏢 The Recorded Q&A Log

> 📘 **Theory.** The log is what turns a meeting into a durable, auditable artifact. Every row in the risk register should trace back to a question like these, not to an assumption nobody said out loud.

| # | Question | Answer | Raised by | Modeling impact |
|---|---|---|---|---|
| S1 | Does anything scan/validate avatar uploads on ingest? | **No** | Sam | Threat T18 → Attack Tree 4 ([08](08-attack-trees-capec.md)) → F-12 |
| S2 | Is the avatar prefix in the privacy notice / retention policy? | **Unknown** | Amara | LINDDUN Unawareness + Non-compliance ([07](07-linddun-privacy.md)) |
| S3 | Is the deploy role `Resource` scoped to this bucket ARN, or wildcarded? | **Unverified — "I think so"** | Diego | P0 verification item; F-09 stays open |
| S4 | Is Versioning or Object Lock enabled? | **No — versioning off** | Diego | BAK-1; drives [13](13-hardening-deep-dive.md) |
| S5 | KMS: CMK or AWS-managed key? | **AWS-managed; no CMK** | Diego | ENC-2 — blocks four other requirements |
| S6 | Is IAM Identity Center / Entra ID federation set up? | **No — AWS root-only; Entra ID has default Global Admin only** | Sam | Scopes [12](12-identity-iam-entra.md) entirely |
| S7 | Who can accept a Critical-tier finding? | **CFO + CISO + Board — nobody present** | Priya | F-01/F-02/F-12 escalate out of the room |
| S8 | Does the analytics reader validate-then-read with a gap? | **Yes — minutes on large exports** | Diego | **F-07**, visible only on the sequence diagram ([05](05-other-model-types.md)) |
| S9 | Is TLS enforced by policy or by convention? | **Unverified** | Priya | ENC-1 |
| S10 | Are CloudTrail *data* events enabled, or only management events? | **Unverified** | Priya | LOG-1 |

---

## 3.6 Question Patterns Worth Stealing

| Pattern | Example | Why it works |
|---|---|---|
| **"Who initiates?"** | "Who starts that flow?" | Resolves diagram ambiguity and often reveals an unexpected direction |
| **"Scoped, or wildcarded?"** | "Can it modify *any* policy, or just this one?" | Converts a comfortable assumption into a verification task |
| **"Then, or later?"** | "Does it validate and *then* read, or validate once and read later?" | Surfaces TOCTOU — you will not find these any other way |
| **"Is that written down anywhere?"** | "Is the retention for that prefix defined?" | Surfaces governance gaps that no technical control fixes |
| **"What else?"** | "Beyond the obvious ones, what *else* could apply here?" | The Socratic move — see [14](14-continuous-threat-modeling.md) |
| **Repeat back the uncertainty** | "So it's unverified, not fine." | Prevents assumptions from being laundered into controls |

---

## 3.7 Anti-Patterns

| Anti-pattern | Why it hurts |
|---|---|
| **Diving into solutions immediately** | Consumes the time you need for *finding* threats. Capture countermeasures in a parking lot |
| **Security team builds the model alone** | Misses flows only engineers know about — you'd have missed the avatar upload |
| **Accepting "I think so"** | Assumptions become documented controls. Write "unverified" |
| **Boiling the ocean** | One system or feature per session |
| **"Think like a hacker"** | Comparable to telling an inexperienced cook to think like a Michelin chef. Ask domain questions instead ([14](14-continuous-threat-modeling.md)) |
| **No recorded output** | The session's value evaporates within a week |
| **Blaming** | Kills the disclosure you depend on |

---

## 3.8 Definition of Done for the Session

- [ ] All relevant diagrams are in the document
- [ ] Background information and findings recorded in the agreed format, in the team's tracking system
- [ ] A **versioned copy stored in a central, access-controlled location** shared by product and security
- [ ] Every open question logged as a question, not resolved by assumption
- [ ] Owner assigned to each verification item
- [ ] If no security expert was available: a team member designated as devil's advocate to attack the security assumptions

---

[← 02 Business Context](02-business-context.md) · [Contents](README.md) · [04 DFD Library →](04-dfd-library.md)
