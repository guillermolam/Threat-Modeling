# Architecture Evidence Pipeline

This directory is the reviewed bridge between the fictional Meridian S3 lab and downstream threat-modeling tools. `model-tags.json` is the semantic contract: every Terragrunt unit has a stable component ID, owner, purpose, classification, trust zone, finding set, flow set, and dependency list. `infra/root.hcl` copies those fields into `tm:*` resource tags so plan and Floci evidence can be joined without guessing from names.

AI and tool adapters are evaluated separately in [`../threat-modeling/`](../threat-modeling/README.md). They may propose diagram or correlation drafts, but this reviewed graph remains authoritative.

## Evidence precedence

The reviewed catalog defines intended architecture and data-flow meaning. Sanitized OpenTofu plans prove configured resources; a scoped Floci inventory proves locally observed resources. Floci is not treated as AWS equivalence. Unsupported behavior remains a structured `GAP` and cannot become an implemented control.

Raw binary plans, raw plan JSON, and raw debug logs are temporary because they can contain sensitive Terraform outputs. `capture-evidence.sh` redacts sensitive masks and credential patterns before evidence leaves its private temporary directory. Generated evidence is scanned again with TruffleHog.

## Generated artifacts

Each posture contains three reviewed artifacts:

- `blueprint.json`: canonical components, trust zones, flows, findings, resources, and runtime evidence.
- `awsdac.yaml`: deterministic Diagram-as-Code input (JSON syntax is valid YAML 1.2).
- `architecture.png`: rendered review artifact from the pinned `awsdac` commit.

Run `task architecture:test` first. `task architecture:integration` creates a clean isolated Floci instance, runs dependency-aware OpenTofu validation, and fails on any error, warning, secret, or generated drift. Maintainers use `task architecture:update` only when intentionally reviewing a model change. Terragrunt 1.1.2's `hcl validate --strict --inputs` emits mock-output warnings during config-only evaluation, so it is not hidden or used as a green gate; the isolated plan/apply/validate path exercises real dependency outputs instead.

## AI boundary

AI is an optional semantic compiler after this deterministic stage. It may translate the blueprint into DFD, OTM, Threat Composer, attack-tree, or policy inputs, but must preserve stable IDs, cite evidence paths, emit the documented schema, and pass offline validation. It never receives raw plans, credentials, Terraform state, or undocumented tenant data.
