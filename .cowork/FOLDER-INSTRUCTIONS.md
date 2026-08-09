This folder is a threat-modeling study and practice workspace. Treat completed models,
attack paths, findings, and benchmark deltas as SENSITIVE.

Sources of truth
- Examples/S3 is the v7 Meridian Retail S3 worked case and learning corpus.
- Examples/S3/A-findings-register.md is the benchmark answer key, not architecture input.
- ThreatModelingAsCode.md is a research/position paper; its claims are not evidence for S3.
- The PDF and EPUB books are reference material, not evidence about Meridian's system.
- The installed threat-modeling skill and its bundled phase contracts govern full runs.
- When skill prose conflicts with bundled phase_data.py behavior, use the script's actual
  paths and commands, document the discrepancy, and do not invent a third convention.

Training modes
1. GUIDED REPLAY may read the entire S3 corpus and explains how each technique produced
   the known findings. Do not present its result as independent discovery.
2. BLIND BENCHMARK must obey its evidence manifest. Do not read the answer key or solution
   chapters until the independent P6 risk-validation checkpoint is complete.
3. TECHNIQUE DRILL applies one named technique and does not pretend to be a complete
   methodology unless it includes both identification and risk classification.

Full skill runs
- Resolve the enabled skill at the start of every run, not from the setup package:
    SKILL_ROOT="${SKILL_PATH:-${CLAUDE_SKILL_DIR:-}}"
  Require `SKILL_ROOT/SKILL.md`, `SKILL_ROOT/scripts/phase_data.py`, and
  `SKILL_ROOT/skill_path.sh` to exist before proceeding. If resolution fails, stop and ask
  the user to invoke or re-enable the installed skill. `.cowork/package/` is setup-only and
  must never be used as a fallback for a production training run.
- Create an isolated root under Training_Runs/{PROJECT}_{YYYYMMDD_HHMMSS}/. Copy only the
  permitted evidence into its evidence/ directory and write EVIDENCE-MANIFEST.md.
- Treat DFD components as design-time modules and documented flows as entry points. State
  explicitly that no application code or live AWS configuration was supplied.
- Do not mark a risk `verified` from prose alone. Use `theoretical` or `pending` unless the
  run contains direct implementation or configuration evidence.
- Execute P1 through P8 in order. Before each phase, read the matching phases/P{N}-*.md.
- Write YAML data first, Markdown report second, then run:
    python3 "$SKILL_ROOT/scripts/phase_data.py" --phase-end --phase N --root "$RUN_ROOT"
- On a failed gate, repair data and re-run. Never bypass validators or edit validation
  scripts to make a run pass.
- Pause after P5, P6, and P7 for the skill's user checkpoints.
- Keep native outputs under RUN_ROOT/Risk_Assessment_Report/. Do not move files while the
  finite-state workflow is in progress.
- Record assumptions, unknowns, evidence references, and technique provenance for every
  finding. Never invent AWS configuration, stakeholder answers, or taxonomy IDs.
- No credentials, external scans, live exploitation, destructive actions, or network POCs.
- Never call the skill KB with `--nvd-cve`, `--nvd-cwe`, or `--nvd-api-key`; those flags
  contact the live NVD API and are outside this offline training workspace.

Benchmarking
- Reveal the answer key only after the independent P6 checkpoint.
- Benchmark by meaning and attack scenario, not ID equality or title similarity alone.
- Report matched, partial, new, missing, and conflict outcomes. A new defensible finding is
  a success; a copied answer is not.
