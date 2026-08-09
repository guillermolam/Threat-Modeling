# Meridian Threat-Modeling Formal System

## Completeness Claim and Scope

This system is operationally complete with respect to one property:

> Every reviewed atomic assertion in the declared source set can be derived as exactly one accepted fact or exactly one explicit review-queue item.

Let `S = (Σ, E, R, D, V, A)`, where `Σ` is the vocabulary, `E` the evidence rules, `R` the derivation rules, `D` the DFD obligations, `V` the OTM validity rules, and `A` the admission gate. A well-formed input cannot disappear silently. Lack of evidence derives `unknown`; it never licenses invention.

This is not a claim that the workshop, code, or lab describes every fact about the real world. The source universe is open; the accepted vocabulary and outcomes are closed. [`formal-system.json`](formal-system.json) is the executable contract.

## DFD Entity Vocabulary

| Entity type | Derivation example | Formal meaning |
|---|---|---|
| `process` | “A Lambda writes to S3.” | Running computation that transforms, routes, or acts on data. |
| `datastore` | “The data sits in the S3 bucket.” | Persistent or durable data location. |
| `external-entity` | “Anyone can call the endpoint.” | Person, organization, or system outside the modeled system. |
| `actor` | “A real logged-in customer.” | Human role intentionally interacting with the system. |
| `container` | “Keep the bucket as one box at L1.” | Logical or deployment grouping for lower-level elements. |
| `interface` | “The internal API has partly unknown clients.” | Exposed interaction surface; callers may be incomplete. |
| `security-service` | “The pipeline assumes a deploy role.” | Identity, authorization, filtering, encryption, or audit capability. |
| `block` | “WAF drops traffic before it reaches the origin.” | Control-enforcement component placed on a path. |
| `trust-boundary` | “The AWS-managed edge has a different trust level.” | Separation of trust assumptions, not a processing node. |

A `data-flow` is an edge, not an entity. Workshop participants are evidence authors, not deployed-system actors. A new node requires a reviewed alias-registry entry; an LLM cannot mint one.

## DFD Relationship Vocabulary

| Relationship | Derivation example | Representation |
|---|---|---|
| `directed-flow` | “S3 serves objects to CloudFront only.” | One source, one destination, one edge. |
| `bidirectional-flow` | “The reader downloads and writes results back.” | Two directed edges; never one ambiguous arrow. |
| `initiates` | “The reader always initiates.” | Metadata on the relevant directed interaction. |
| `contains` | “Lambda is inside the Application container.” | One immediate parent per abstraction level. |
| `crosses-trust-boundary` | “GitHub Actions is external and crosses in to deploy.” | Derived when endpoint trust zones differ. |

Every flow independently records data, protocol, authentication, certainty, and exact evidence. Predicate contracts fix direction. If selected endpoints have reversed allowed kinds, code may swap them; otherwise the fact enters review.

## Atomic Derivation Rules

1. Code removes speaker labels and segments reviewed text into atomic fragments.
2. Code resolves aliases and participant exclusions before any model call.
3. A model classifies one fragment as `relation`, `attribute`, or `uncertainty` from a closed enum.
4. For a relation only, a second model call selects subject, predicate, and object from closed enums.
5. Both calls run twice, serially, with identical pinned settings. Exact disagreement derives `unknown`.
6. Code supplies identifiers, labels, evidence, data, protocol, authentication, and certainty.
7. Evidence must be a whitespace-normalized exact transcript substring of at most 25 words and carry codepoint offsets into the scoped transcript, speaker-free surrounding context, and resolved mention IDs.
8. Missing evidence, unresolved entities, invalid references, or direction failure enter `review_queue`.

## DFD Completeness Obligations

| ID | Question the system must resolve | Passing condition |
|---|---|---|
| `IC-001` | Have all routes and interfaces, including legacy paths, been inventoried? | Inventory evidence covers every discovered interface. |
| `IC-002` | Does every route resolve to a concrete handler? | Each interface links to implementation evidence. |
| `IC-003` | Are path, query, header, and body inputs constrained? | Constraints or an explicit gap exist for every input. |
| `IC-004` | Are all enabled methods or operations known? | Each interface has an exhaustive operation set. |
| `DF-001` | Where does every input go? | Each input is traced to every known destination. |
| `DF-002` | Where and when does persistent data exit? | Retention/deletion is defined or a gap is recorded. |
| `DF-003` | What classified fields and identifiers move? | Every data element has reviewed classification. |
| `DF-004` | What transforms or sanitizes the data? | Each transformation is recorded or confirmed absent. |
| `CF-001` | What is the complete security-relevant call chain? | Entry-to-sink chain has implementation evidence. |
| `CF-002` | Where are authentication and authorization enforced? | Each protected operation links to enforcing checks. |
| `CF-003` | What happens on errors, timeouts, retries, and partial failure? | Failure behavior is modeled or a gap is recorded. |
| `CF-004` | Which direct and transitive dependencies are called? | Every known downstream dependency is represented. |
| `TB-001` | Is every untrusted entry visibly marked? | Every untrusted ingress is labeled. |
| `TB-002` | Are distinct trust assumptions bounded? | Every distinct trust zone has a boundary. |
| `TB-003` | Does every cross-zone flow show the crossing? | Endpoint-zone comparison and diagram agree. |
| `TB-004` | Is each claimed boundary protection verified? | Control claim links to implementation evidence. |
| `DS-001` | How does data enter and leave each datastore? | All known ingress and egress paths are represented. |
| `DS-002` | Is each datastore classified? | A reviewed classification is attached. |
| `DS-003` | Are encryption, versioning, backup, retention, and recovery known? | Each property is confirmed, absent, or explicitly unknown. |
| `XV-001` | Does every DFD flow have matching implementation evidence? | Every flow has a trace or explicit unknown. |
| `XV-002` | What enforces protection of sensitive data? | Every protection claim links to an enforcing control. |
| `XV-003` | Does each control cover the exact modeled path? | Scope evidence matches the flow; labels alone do not pass. |
| `QG-001` | How much of the applicable model was assessed? | 100% of blocking and at least 95% of all obligations. |

`gap`, `unknown`, and `unverified` are valid derivations but do not satisfy an obligation. `not-applicable` requires reviewed rationale. `XV-002` and `QG-001` failures block promotion.

## OTM Vocabulary and Relationships

| Exchange | Derives |
|---|---|
| “Call the effort `meridian-s3-customer-data`.” | `project.id` |
| “The external CI/CD platform has lower trust.” | `trustZone.risk.trustRating` |
| “The export reader is a scheduled batch job.” | `component.type` |
| “The policy document moves on deploy.” | `dataflow` and its asset |
| “A leak is 100; an hour unavailable is 40.” | `asset.risk` confidentiality/availability |
| “Scanners are likely to find it; call it 90.” | `threat.risk.likelihood` |
| “Scoping the deploy role removes about 75.” | `mitigation.riskReduction` |
| “The bucket remains in the account zone.” | `component.parent.trustZone` |
| “The CDN pulls from S3.” | `dataflow.source` = S3; `.destination` = CDN |
| “Images and customer ID filenames travel.” | `dataflow.assets[]` |
| “The reader passes data through.” | `component.assets.processed[]`, not `.stored[]` |
| “Public read belongs to the anonymous flow.” | Threat attached to that dataflow |
| “Block Public Access is only planned.” | Mitigation `state: required`, not `implemented` |

## OTM Well-Formedness and Admission

- Component type is deliberate and library-compatible; generic fallback requires rationale.
- Every flow source and destination resolves to exactly one component.
- Every component has at most one parent at one abstraction level.
- Stored and processed assets remain distinct.
- Required numeric risk fields are bounded and include an auditable `risk.comment`.
- Threats attach where the risky behavior occurs, not automatically to the nearest component.
- A countermeasure becomes `implemented` only after implementation evidence verifies it.
- OTM is architecture-only in this lab; generated threats and controls remain platform results.

The only terminal admission outcomes are `accepted` and `review_queue`. Automatic semantic repair and silent dropping are forbidden. Passing schema validation proves well-formedness; satisfying every applicable completeness obligation proves coverage relative to the declared sources.
