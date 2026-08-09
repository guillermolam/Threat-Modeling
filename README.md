# Threat Modeling

A threat-modeling study and practice workspace: methodology guides, reference material, a complete worked case with example infrastructure, and training-run scaffolding for the installed threat-modeling skill.

## Contents

| Path | What's in it |
|---|---|
| `Examples/S3/` | **The worked case.** A 19-part study guide applying every technique to one continuous scenario — a publicly exposed, customer-data S3 bucket at a fictional retailer. Includes a full DFD library, STRIDE/LINDDUN elicitation, attack trees (CAPEC/CWE/ATT&CK), risk scoring (CVSS/DREAD/FAIR), a findings register, and OpenTofu/Terragrunt example infrastructure. Start at [`Examples/S3/README.md`](Examples/S3/README.md). |
| `Articles/` | Research and position papers on threat modeling, including a threat-modeling-as-code paper. |
| `Books/` | Reference books and eBooks on threat modeling. |
| `Training_Runs/` | Isolated, timestamped training-run roots produced by the threat-modeling skill. |
| `.cowork/` | Workspace instructions, smoke-test specs, source audit, and guided-replay / blind-benchmark / technique-drill prompts. |

## Quick Start

1. Clone the repo.
2. Open [`Examples/S3/README.md`](Examples/S3/README.md) for the study guide and its five suggested learning paths.
3. For skill-driven training runs, follow the rules in [`.cowork/FOLDER-INSTRUCTIONS.md`](.cowork/FOLDER-INSTRUCTIONS.md).

## Local CI Contract

Bootstrap the checksum-pinned Task `3.52.0` binary, then run:

```bash
./scripts/ci/install-security-tools.sh  # safe when shell PATH has an older Task
task setup                 # pinned tools and Trunk-managed Git hooks
task test                  # hook-selection and scanner unit tests
task zizmor                # strict, pedantic GitHub Actions audit
task ci BASE_SHA=... HEAD_SHA=...  # the same gate used by GitHub Actions
task architecture:test     # tags, schema, sanitization, HCL, and tool contracts
task architecture:integration  # clean Floci deploy and generated-drift gate
```

Trunk manages pre-commit, pre-push, Actionlint, ShellCheck, shfmt, YAML, and action-pin checks without a Node project. Betterleaks and TruffleHog run on both hooks. Zizmor runs only when staged or outgoing changes include `.github/`. Findings and tool errors remain fatal; logs redact credential values.

The architecture workflow executes the first threat-modeling stage: it applies
all 19 Terragrunt units to an isolated Floci instance, validates the lab,
sanitizes the saved OpenTofu plans and debug logs, joins them through stable
`tm:*` tags, and rebuilds the canonical blueprints and AWS Diagram-as-Code PNGs.
Use `task architecture:update` only to accept an intentional reviewed model
change. DFD, STRIDE/LINDDUN/PASTA, attack-tree, risk, and countermeasure stages
consume these blueprints in later increments; they are not fabricated by this
workflow.

> **⚠️ Sensitive by nature.** A completed threat model is a blueprint for attacking the system. In a real organization this belongs in a version-controlled, access-controlled repository — not an open wiki. This workspace is published for learning; do not use its example findings to attack any real system.

## Security

- No credentials, live configuration, or external scan data is included.
- Training runs are offline-only: the NVD API and all network POCs are out of scope (see `.cowork/FOLDER-INSTRUCTIONS.md`).

## License

MIT — see [LICENSE](LICENSE).
