# 18 · IriusRisk S3 Lab

[← 17 Foundations](17-iriusrisk-foundations.md) · [Contents](README.md) · [19 Content Authoring →](19-iriusrisk-content-authoring.md)

The lab is complete offline. Tenant interaction is optional and must use a protected environment.

## 18.1 Offline setup and validation

From `Examples/S3`:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r iriusrisk/requirements.txt
./iriusrisk/scripts/preflight.sh
```

Preflight parses JSON/YAML, validates both OTM files against the CLI schema, checks unique IDs and component-only flows, validates every finding cross-reference, runs Markdown-link and secret checks, and invokes `isra tests components all` through the pinned checkout when available. Tenant and Azure calls are prohibited in PR validation.

## 18.2 Optional authenticated workflow

Set `IRIUS_HOSTNAME`, `IRIUS_API_KEY`, and `IRIUSRISK_PROJECT_REF` only in the protected runner or local environment. Never write them to the repository.

1. Test the connection and **fresh-sync** the project. The sync is mandatory even if local data exists.
2. Validate every baseline trust-zone UUID and component `type` against the synchronized `trust-zones.json` and active, non-deprecated `components.json`.
3. Import [`current-state.otm`](.iriusrisk/baselines/current-state.otm), wait until processing is ready, and create version `meridian-s3-current-v1`.
4. Review project and component questionnaires. Read source questions from `groups[].questions`; submit answers in `steps[]`. Cite exact Terragrunt/OpenTofu paths. Leave unknown or Floci `GAP` answers pending.
5. Sync generated threats, weaknesses, controls, statuses, standards, and tests. Reconcile them with every manual finding in `iriusrisk/traceability.yaml`; never invent tenant UUIDs.
6. Fresh-sync again. Snapshot before structural replacement, preserve the project reference, remove obsolete monolith elements deliberately, and import [`target-state.otm`](.iriusrisk/baselines/target-state.otm).
7. Create `meridian-s3-target-v1`, then compare the two versions and generate a report into temporary storage.

The manual workflow in [`.github/workflows/iriusrisk-live.yml`](../../.github/workflows/iriusrisk-live.yml) automates the safe read/sync/compare/report skeleton and performs no destructive test.

## 18.3 Review the result

Confirm the target model shows four classified buckets, purpose-specific KMS, OAC/WAF, scoped identities, quarantine→scan→promotion, version-pinned readers, and S3 data-event detection. A version comparison proves model change—not control effectiveness. Implementation status still requires evidence from `infra/live/target-state/` and `verify-lab.sh`.

[← 17 Foundations](17-iriusrisk-foundations.md) · [Contents](README.md) · [19 Content Authoring →](19-iriusrisk-content-authoring.md)
