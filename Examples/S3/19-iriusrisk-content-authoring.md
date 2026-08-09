# 19 · IriusRisk Content Authoring

[← 18 S3 Lab](18-iriusrisk-s3-lab.md) · [Contents](README.md) · [A Findings →](A-findings-register.md)

ISRA authors reusable security content; it is separate from modeling a particular project. This repository pins ISRA 3.2.0 at commit `4fc6436bc7c5517d43d8ce23012b9c5deefc4688`.

## 19.1 Authoring workflow

1. Define the component's reusable architectural behavior and scope. Do not clone standard S3 content.
2. Use `isra component new` to initialize work, or start from a reviewed fixture under [`iriusrisk/content/`](iriusrisk/content/).
3. Build the static risk pattern with threats and countermeasures. Stable references use `CD-`, `RP-`, `T-`, and `C-` prefixes.
4. Screen every threat for STRIDE-LM and CIA/ease-of-exploitation. Screen applicable CWE, ATT&CK, and ATLAS mappings; an explicit empty list is preferable to a speculative ID.
5. Screen each control for implementation scope, cost (`0`–`2`), a testable question, CWE impact, references, and relevant standards.
6. Run schema and integrity tests, then peer-review the security semantics and wording.
7. Export/import through the approved IriusRisk content process only after review. Azure OpenAI regeneration is optional and its output must be reviewed like any other draft.

## 19.2 Meridian fixtures

| Component | Finding | Review focus |
|---|---|---|
| UGC quarantine and promotion | `F-12` | untrusted upload, scan failure, immutable promotion decision |
| Cross-account partner ingestion | `F-14` | external ID, prefix scope, attribution, confused deputy |
| Version-pinned reader | `F-07` | TOCTOU-safe validation and exact version retrieval |
| Autonomous analytics agent | `F-18` | indirect prompt injection and excessive agency |

These are reviewed teaching fixtures, not proof that a tenant library has accepted them. `review` metadata records the human-review scope without embedding tenant identifiers.

## 19.3 Validation

```bash
./iriusrisk/scripts/preflight.sh

# In the pinned ISRA checkout, with fixtures copied into components/:
isra tests components all
```

Resolve every error; do not suppress a failed schema, duplicate reference, missing countermeasure question, invalid taxonomy, or unbalanced mitigation result. Re-run the crosswalk validator after changing any `content_component_refs` in `iriusrisk/traceability.yaml`.

[← 18 S3 Lab](18-iriusrisk-s3-lab.md) · [Contents](README.md) · [A Findings →](A-findings-register.md)
