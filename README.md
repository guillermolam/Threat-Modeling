# Threat Modeling

A threat-modeling study and practice workspace: methodology guides, reference material, a complete worked case with example infrastructure, and training-run scaffolding for the installed threat-modeling skill.

## Contents

| Path | What's in it |
|---|---|
| `Examples/S3/` | **The worked case.** A 16-part study guide applying every technique to one continuous scenario — a publicly exposed, customer-data S3 bucket at a fictional retailer. Includes a full DFD library, STRIDE/LINDDUN elicitation, attack trees (CAPEC/CWE/ATT&CK), risk scoring (CVSS/DREAD/FAIR), a findings register, and Terraform/Terragrunt example infrastructure. Start at [`Examples/S3/README.md`](Examples/S3/README.md). |
| `Articles/` | Research and position papers on threat modeling, including a threat-modeling-as-code paper. |
| `Books/` | Reference books and eBooks on threat modeling. |
| `Training_Runs/` | Isolated, timestamped training-run roots produced by the threat-modeling skill. |
| `.cowork/` | Workspace instructions, smoke-test specs, source audit, and guided-replay / blind-benchmark / technique-drill prompts. |

## Quick Start

1. Clone the repo.
2. Open [`Examples/S3/README.md`](Examples/S3/README.md) for the study guide and its five suggested learning paths.
3. For skill-driven training runs, follow the rules in [`.cowork/FOLDER-INSTRUCTIONS.md`](.cowork/FOLDER-INSTRUCTIONS.md).

> **⚠️ Sensitive by nature.** A completed threat model is a blueprint for attacking the system. In a real organization this belongs in a version-controlled, access-controlled repository — not an open wiki. This workspace is published for learning; do not use its example findings to attack any real system.

## Security

- No credentials, live configuration, or external scan data is included.
- Training runs are offline-only: the NVD API and all network POCs are out of scope (see `.cowork/FOLDER-INSTRUCTIONS.md`).

## License

MIT — see [LICENSE](LICENSE).
