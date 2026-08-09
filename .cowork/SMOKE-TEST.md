# SMOKE-TEST.md — packaged threat-modeling skill

Scope: Part 1 §5 only. Run entirely inside `.cowork/smoke/project` (not PROJECT_ROOT).
No `--nvd-cve`, `--nvd-cwe`, or `--nvd-api-key` used — fully offline. No folder
instructions installed, no ZIP upload, no skill enable, no training run created.

`SKILL_ROOT = <PROJECT_ROOT>/.cowork/package/threat-modeling`

## 1. Recreate test root

```
$ rm -rf .cowork/smoke/project && mkdir -p .cowork/smoke/project
EXIT: 0
```

## 2. Runtime availability

```
$ python3 -V
Python 3.10.12
EXIT: 0

$ python3 -c 'import sqlite3; print("sqlite-ok")'
sqlite-ok
EXIT: 0
```

Assertion: Python 3 present, sqlite3 module importable. **PASS**

## 3. Local KB queries (offline only)

```
$ "$SKILL_ROOT/kb" --stride spoofing > .cowork/smoke/stride.json
EXIT: 0  (stderr empty)

$ "$SKILL_ROOT/kb" --cwe CWE-89 > .cowork/smoke/cwe-89.json
EXIT: 0  (stderr empty)
```

Parsed both files with `python3 -m json` equivalent (`json.load`):

- `stride.json`: valid JSON, top-level keys
  `category, source, code, name, description, security_property, threat_examples,
  typical_mitigations, cwes, capecs`. Serialized content contains `SPOOFING`. **PASS**
- `cwe-89.json`: valid JSON, top-level keys
  `id, name, description, abstraction, status, stride_categories, related_capec,
  parents, children, owasp_categories, source`. Serialized content contains `CWE-89`. **PASS**

No `--nvd-*` flags used at any point; both queries are served from local YAML/SQLite data
per the source audit (NVDClient is never instantiated by `--stride` or `--cwe`).

## 4. Session init/status (`phase_data.py`)

Run from `.cowork/smoke/project`:

```
$ python3 "$SKILL_ROOT/scripts/phase_data.py" --init --project SMOKE-TEST --path "$(pwd)"
EXIT: 0
{"status": "success", "action": "init_session",
 "session_id": "SMOKE-TEST_20260809_022719",
 "session_dir": ".../Risk_Assessment_Report/.phase_working/SMOKE-TEST_20260809_022719",
 "data_dir": ".../Risk_Assessment_Report/.phase_working/SMOKE-TEST_20260809_022719/data",
 "project_name": "SMOKE-TEST", "overall_status": "success"}

$ python3 "$SKILL_ROOT/scripts/phase_data.py" --status --root "$(pwd)"
EXIT: 0
{"status": "active", "session": {...}, "overall_status": "active"}
```

Assertion: `overall_status: "active"`. **PASS**

Filesystem check (`find Risk_Assessment_Report`) after init:

```
Risk_Assessment_Report/
Risk_Assessment_Report/.phase_working/
Risk_Assessment_Report/.phase_working/_session_meta.yaml
Risk_Assessment_Report/.phase_working/SMOKE-TEST_20260809_022719/
Risk_Assessment_Report/.phase_working/SMOKE-TEST_20260809_022719/_session.yaml
Risk_Assessment_Report/.phase_working/SMOKE-TEST_20260809_022719/data/
```

This exactly matches the four assumed runtime paths from the source-audit / setup-prompt
§1.5, and resolves that discrepancy definitively in favor of those paths over SKILL.md's
illustrative (and here shown to be inaccurate) directory-tree example:

- working root: `Risk_Assessment_Report/.phase_working/` — confirmed
- global index: `Risk_Assessment_Report/.phase_working/_session_meta.yaml` — confirmed, present at working-root level (not nested in the session dir)
- per-session state: `Risk_Assessment_Report/.phase_working/{SESSION_ID}/_session.yaml` — confirmed
- per-session data: `Risk_Assessment_Report/.phase_working/{SESSION_ID}/data/` — confirmed, created empty (no phase run yet)

`_session_meta.yaml` content confirms `project_name: SMOKE-TEST`, `current_session.session_id`
matching the session dir name, `status: in_progress`. `_session.yaml` confirms
`current_phase: 1`, all 8 phase extraction flags `false`, `phases_completed: []`. **PASS**

## 5. `skill_path.sh` resolution

```
$ bash "$SKILL_ROOT/skill_path.sh"
EXIT: 0
<PROJECT_ROOT>/.cowork/package/threat-modeling
```

Assertion: output equals `SKILL_ROOT` (PACKAGED_SKILL) exactly, stderr empty. **PASS**

## Summary

| Check | Result |
|---|---|
| Python 3 / sqlite3 available | PASS |
| `kb --stride spoofing` → valid JSON, contains SPOOFING | PASS |
| `kb --cwe CWE-89` → valid JSON, contains CWE-89 | PASS |
| `phase_data.py --init` / `--status` → status=active | PASS |
| Runtime state paths match assumed layout | PASS |
| `skill_path.sh` resolves PACKAGED_SKILL | PASS |
| No `--nvd-*` flags invoked | confirmed clean |

All test artifacts under `.cowork/smoke/`. Test session `SMOKE-TEST_20260809_022719`
lives only inside `.cowork/smoke/project/Risk_Assessment_Report/` — nothing was written
to PROJECT_ROOT.

SMOKE: PASS
