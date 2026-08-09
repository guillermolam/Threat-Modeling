Run an independent blind threat-model benchmark named S3-BLIND using the installed
threat-modeling skill in debug mode and English.

Create RUN_ROOT under Training_Runs/S3-BLIND_{YYYYMMDD_HHMMSS}. Before P1, copy only these
inputs into RUN_ROOT/evidence and record their source hashes in EVIDENCE-MANIFEST.md:
- Examples/S3/01-foundations.md
- Examples/S3/02-business-context.md
- Examples/S3/03-session-facilitation.md
- Examples/S3/04-dfd-library.md

Until P6 risk validation is complete, do not read Examples/S3/05 through 16,
A-findings-register.md, B-traceability-log.md, ThreatModelingAsCode.md, the PDF, or either
EPUB. These are the solution/reference set. If any prohibited file is read accidentally,
mark the run CONTAMINATED and stop benchmarking; it may continue only as a guided replay.

This is a documentation-only design assessment. Model DFD components as modules and
documented flows as entry points. Do not claim implementation verification or live AWS
state. Follow P1-P8, write YAML before reports, execute every phase gate, and pause at P5,
P6, and P7.

After I approve the P6 checkpoint, reveal Examples/S3/A-findings-register.md and write
RUN_ROOT/Risk_Assessment_Report/BENCHMARK-DELTA.md with:

| generated risk | study finding | outcome | scenario overlap | disposition comparison | evidence | note |

Outcome must be matched, partial, new, missing, or conflict. Compare semantically; do not
force one-to-one matches when one generated risk legitimately maps to multiple study
findings. Preserve new defensible findings and explain missing ones by technique/source gap.
Finish P7-P8, run complete workflow validation, and report whether the run remained blind.
