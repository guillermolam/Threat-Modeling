# Repository Guidelines

## Project Structure & Module Organization

This is a threat-modeling study workspace, not an application with `src/` and `tests/` trees. `Examples/S3/` is the worked case. Its local lab lives in `Examples/S3/infra/`: OpenTofu modules are under `modules/`, Terragrunt units under `live/{current-state,target-state}/`, and helpers under `scripts/`. `Articles/` and `Books/` hold references. Follow `.cowork/` instructions and isolate exercises under `Training_Runs/<project>_<timestamp>/`.

## Build, Test, and Development Commands

Run infrastructure commands from `Examples/S3/infra` unless noted:

```bash
floci start                         # start the local AWS emulator
./scripts/preflight.sh              # check tools and local endpoint safety
./scripts/apply-lab.sh all          # deploy current and target postures
./scripts/verify-lab.sh             # verify modeled controls
terragrunt hcl validate             # validate Terragrunt configuration
terragrunt run --all -- validate    # validate every OpenTofu unit
tofu fmt -recursive                 # format HCL recursively
```

Use `terragrunt destroy` for normal teardown. Treat `reset-floci.sh --state` as drift recovery, not routine cleanup.

At the root, `task test` runs hook tests; `task ci BASE_SHA=<base> HEAD_SHA=<head>` reproduces GitHub Actions.

## Coding Style & Naming Conventions

Keep Markdown concise, evidence-based, and cross-reference finding IDs such as `F-01`, `ENC-5`, and `LOG-1`. Preserve the numbered chapter pattern (`06-stride.md`) and use `kebab-case` for infrastructure modules and units. Format HCL with `tofu fmt`. In shell scripts, use `set -euo pipefail` where appropriate, indent continuations by two spaces, quote expansions, and retain executable permissions.

## Testing Guidelines

Infrastructure changes must pass both Terragrunt validation and `scripts/verify-lab.sh`. Treat reported Floci `GAP` lines as documented emulator limitations; do not suppress or relabel them as passing runtime enforcement. Add verification checks when introducing a new modeled control.

## Commit & Pull Request Guidelines

History currently contains one descriptive initial commit, so use short, imperative, scoped subjects, for example `infra: enforce sanctioned KMS keys`. Pull requests should summarize intent, list affected finding IDs, link relevant issues, and include validation output. Add screenshots only when rendered documentation or diagrams change.

## Security & Agent Instructions

Never commit credentials, Terraform state, `.threatforest/.env`, live scan results, or exploit artifacts. Do not run destructive tests or network proofs of concept. Agents conducting training runs must follow `.cowork/FOLDER-INSTRUCTIONS.md`, including offline-only operation, evidence isolation, phase ordering, and restrictions on reading benchmark answer keys.

Never bypass Trunk-managed hooks or soften scanner exits. Zizmor is mandatory when selected changes touch `.github/`.
