# Meridian S3 local threat-model lab

This lab turns the findings in `Examples/S3` into two coexisting Floci stacks:

| Posture | Prefix | Shape | Purpose |
|---|---|---|---|
| Current | `meridian-cs-` | One mixed-classification S3 bucket, broad IAM, weak metadata and incomplete audit | Reproduce the attack surface |
| Target | `meridian-ts-` | Four purpose-bound buckets, tier-specific KMS keys, OAC/WAF, scoped IAM, data-event logging and detection | Demonstrate the mapped mitigations |

The implementation uses Terragrunt for composition, OpenTofu for state and planning, and the AWS provider pointed exclusively at `http://localhost:4566`. Both postures can exist at once, making policy and output diffs easy to inspect.

## Quick start

Prerequisites: Docker, Floci, AWS CLI v2, OpenTofu, Terragrunt, `curl`, and `jq`.

```bash
floci start
cd Examples/S3/infra
./scripts/preflight.sh
./scripts/apply-lab.sh all
./scripts/verify-lab.sh
```

Apply only one posture with `./scripts/apply-lab.sh current` or `./scripts/apply-lab.sh target`. For a single Terragrunt unit, run `terragrunt run --source-update -- apply -auto-approve` in that unit directory.

Local state is split by unit under `.tfstate/` and is ignored by Git. `terragrunt destroy` is the normal teardown path. `scripts/reset-floci.sh --state` is a recovery tool for drifted state and only targets names beginning with `meridian-`.

## What to inspect

The most useful comparisons are:

- `live/current-state/s3-monolith` versus the four `live/target-state/s3-*` units.
- `live/current-state/iam` versus `live/target-state/iam`.
- CloudTrail event selectors from `logging`: management-only in current state, S3 object data events in target state.
- Compute outputs: IMDS optional with hop limit 2 in current state, IMDSv2 required with hop limit 1 in target state.
- Each module's `posture_summary`, which names the finding IDs still open for that configuration.

`scripts/verify-lab.sh` checks the rendered controls and deliberately proves the current anonymous-list path. It reports known emulator limitations as `GAP`, never as a false pass.

## Threat Composer and ThreatForest

`../MeridianS3.tc.json` is a schema-validated Threat Composer v1 workspace derived from the findings register and the implemented controls. Import it directly into Threat Composer.

ThreatForest treats a `*.tc.json` file in the project as the authoritative threat source. The local clone can be prepared and run as follows:

```bash
cd /Users/guillermolammartin/Git/sample-agentic-attack-tree-generator/ts
npm install
npm run build:packages
npm run start -w @threatforest/cli -- config init
npm run start -w @threatforest/cli -- --tui
```

Choose `/Users/guillermolammartin/Documents/01_Security/Threat-Modeling/Examples/S3` as the project and `MeridianS3.tc.json` as the existing threat file. A non-interactive run is also available with `npm run start -w @threatforest/cli -- run --project-path <project> --threat-model <file>`. The web console alternative is `npm run dev` after preparing the repository's Python environment; open `http://127.0.0.1:3000`. Keep the default loopback binding: ThreatForest has no authentication.

ThreatForest's full pipeline invokes the configured LLM and may incur provider charges. Credentials belong in the launch directory's `.threatforest/.env`, which is ignored; generated reports belong in `Examples/S3/.threatforest/output/`.

## Emulation gaps

- Floci 1.6.0 persists S3 bucket policies but does not reliably enforce them for unsigned S3 data-plane calls. Validate target denies in AWS or a policy-aware emulator before treating them as runtime evidence.
- Floci's native CloudFront distribution response is incomplete for the AWS provider. The edge module therefore keeps a real OAC/WAF resource but uses a deterministic `terraform_data` distribution identity locally. Set `use_native_distribution_resource = true` only against a compatible endpoint or AWS.
- The lab is single-account. Production access logs and CloudTrail destinations should be isolated in a log-archive account with independent administration.
- Managed AWS Config rules and EventBridge targets can be provisioned locally, but Floci does not reproduce the complete evaluation and delivery semantics of AWS.
- Floci currently reports `HttpTokens=optional` from EC2 even when the OpenTofu resource requires IMDSv2. The verifier checks the desired state and emits a runtime `GAP` for this mismatch.
- Local state is convenient for the lab, not a production design. Production state needs encrypted remote storage, locking, restricted access, versioning, and audit.
