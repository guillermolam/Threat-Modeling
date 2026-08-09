# Threat-modeling Adapter Evaluation

The reviewed `architecture/model-tags.json` contract is the canonical graph IR. Its deterministic converters produce D2, PlantUML, and Mermaid from the same nodes and edges. AI may draft a replacement IR or suggest correlations, but it may not invent components, trust zones, flows, findings, or evidence. A draft becomes maintained code only after all three formats compile, preserve every stable ID exactly once, pass referential checks, and receive human review.

## DFD generation

Run `task threat-model:dfd:update` to regenerate both postures. The maintained sources and compiled results are under `dfd/`:

- `*.d2` and `*.d2.svg`
- `*.puml`, `*.plantuml.svg`, and `*.plantuml.png`
- `*.mmd`, `*.mermaid.svg`, and `*.mermaid.png`

`task threat-model:dfd:test` rebuilds them in temporary storage, rejects source drift, validates D2 and PlantUML syntax, compiles every renderer, and proves exact graph-ID coverage. D2 remains SVG-only because its PNG exporter downloads Playwright at runtime; the offline contract does not permit that unpinned dependency.

The maintained DFD is generated from reviewed graph IR. Local model output is limited to the closed-set inference boundary described below and remains advisory evidence.

## Formal system and conversation normalization

[`formal-system.md`](formal-system.md) defines the complete vocabulary and admission property for this adapter: DFD entity and relationship types, OTM fields, evidence rules, 23 completeness obligations, and fail-closed outcomes. `formal-system.json` is the machine-checked contract. “Complete” is relative to the declared source set: every reviewed atomic assertion must become `accepted` or an explicit `review_queue` item; it does not mean that absent architecture evidence is invented.

The LLM never receives the raw workshop transcript. `conversation-normalization.json` maps reviewed phrases and aliases to entities, atomic subject–predicate–object relations, attributes, and uncertainty states. `task threat-model:conversation:update` writes the stable `conversation/current-state.normalized.json` fixture and projects it deterministically to `conversation/current-state.graph.json`. Each relation also receives a simple `subject | predicate | object | data` string suitable for later embedding or vector comparison.

The active inference boundary is closed-set only. `classify-atomic-fact.md` makes one three-way decision; `select-relation-slots.md` selects only known entity and predicate IDs. Code copies identifiers, labels, evidence, data, protocol, authentication, and certainty. Evidence is an exact normalized transcript substring of at most 25 words, anchored by offsets into the scoped transcript and accompanied by speaker-free context. The slot registry includes sorted reviewed aliases but never answer fields. Two serial calls must agree exactly; missing evidence, participant leakage, unresolved entities, direction errors, and disagreements become `unknown` review items. No one-shot graph serializer, automatic semantic repair, or silent drop is supported.

Run `task threat-model:conversation:test` to validate the formal vocabulary, alias resolution, endpoint integrity, absence of self-loops, prefix-versus-component handling, uncertainty preservation, exact evidence, deterministic projection, and closed-set rejection behavior. The fake Ollama test covers a successful relation, missing-evidence fail-closed behavior, and a non-reproducible slot decision. The reviewed corpus remains the source of truth; model output is advisory evidence, never maintained graph code.

## Local inference lifecycle

`task llm:run -- <command>` is the normal interface. It starts an Ollama server bound to loopback only when none exists and always invokes the stop hook afterward. If Ollama was already running, the hooks record external ownership and leave it untouched. `OLLAMA_DEBUG=1` output is retained only below ignored `.tools/runtime/ollama/`.

Use `task llm:start` and `task llm:stop` only for interactive debugging. `task llm:lifecycle:test` proves owned-process cleanup, external-process preservation, and rejection of non-loopback binds.

## Adapter policy

- Generate the canonical DFD deterministically from the reviewed graph. LLM output is a candidate diff, never the graph itself.
- Prefer `source text → normalized graph IR → format converters` over direct syntax-to-syntax translation; conversion happens from semantics, not presentation quirks.
- Use specialized tools for their actual contracts: Threat Composer for model interchange, ThreatForest for attack trees, ThreatCL for DFD/OTM transforms, and IriusRisk for tenant-generated threats and countermeasures when authenticated.
- Run agents with read-only inputs, an isolated output directory, no credentials, no shell/network tools, temperature zero, and a pinned model digest.
- Reject any output that is unparsable, truncated, duplicates or omits IDs, changes endpoints, or adds unsupported security assertions. Do not repair it silently.
- Treat CWE, CVE, CAPEC, CIS, benchmark, and compliance links as proposed correlations until a deterministic resolver verifies identifier existence and a reviewer records rationale.

`tool-evaluation.json` records tested versions, evidence, and dispositions. `task threat-model:tools:test` validates that policy offline.
