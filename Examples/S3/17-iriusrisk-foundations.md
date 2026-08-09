# 17 · IriusRisk Foundations

[← 16 Tooling](16-tooling-automation.md) · [Contents](README.md) · [18 S3 Lab →](18-iriusrisk-s3-lab.md)

IriusRisk turns an architecture model into a governed security backlog. It complements the manual Meridian analysis; it does not erase it.

## 17.1 The modeling vocabulary

| Concept | Meaning in this case |
|---|---|
| Trust zone | A boundary with a trust rating: Internet, Public Cloud, or AWS Cloud |
| Component | A typed system element such as S3, a workload, edge service, or actor |
| Data flow | A component-to-component interaction; never a line to a trust zone |
| Asset | Information or capability carried by components and flows |
| Risk pattern | Reusable rules/content associated with a component type |
| Threat | A scenario generated from architecture and questionnaire context |
| Weakness | The condition that makes a threat feasible |
| Countermeasure | A control that reduces the associated risk |

The useful reasoning chain is **Threat → Weakness → Countermeasure**. Review it in both directions: a control needs a threat, and a threat needs evidence or a disposition. Risk and workflow states are different: risk can be exposed or reduced while a countermeasure is recommended, required, implemented, rejected, or not applicable. Preserve rationale and evidence whenever a state changes.

## 17.2 Architecture, rules, and evidence

The committed baselines in [`.iriusrisk/baselines/`](.iriusrisk/baselines/) contain architecture only. Importing them lets IriusRisk generate tenant-library threats and controls. Questionnaires then refine the result, but answers come only from [`infra/`](infra/) evidence. “Not found,” “unverified,” and Floci `GAP` mean **unknown/pending**, not “yes.”

The manual register remains an independent analytical lens. [`iriusrisk/traceability.yaml`](iriusrisk/traceability.yaml) records whether a finding is mapped to generated content, pending authenticated review, or deliberately manual-only.

## 17.3 Reports, versions, and interchange

Reports are derived views for review and audit; they are generated into temporary storage and never committed. Named versions make architecture and risk changes reviewable. This lab uses one project and snapshots `meridian-s3-current-v1` before the hardened import and `meridian-s3-target-v1` afterward.

OTM is portable architecture interchange, not a lossless native-project backup. Native XML can contain a fuller project, library references, generated risks, controls, and platform-specific state. Compare the isolated Mobile Banking XML fixture to understand the distinction; do not round-trip it through OTM and expect equality.

## 17.4 Review questions

1. Which facts belong in architecture, questionnaire answers, and dispositions?
2. Which generated items correspond to `F-12`, `F-14`, and `F-18`?
3. Which manual findings remain valuable when no library rule produces them?

[← 16 Tooling](16-tooling-automation.md) · [Contents](README.md) · [18 S3 Lab →](18-iriusrisk-s3-lab.md)
