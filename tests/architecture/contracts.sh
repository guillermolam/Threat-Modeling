#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

printf '[debug] validating architecture JSON and Python contracts\n' >&2
jq empty \
  "${REPO_ROOT}/Examples/S3/architecture/model-tags.json" \
  "${REPO_ROOT}/Examples/S3/architecture/schemas/blueprint.schema.json"
python3 "${REPO_ROOT}/scripts/architecture/model_pipeline.py" validate-catalog \
  "${REPO_ROOT}/Examples/S3/architecture/model-tags.json"
python3 -m unittest discover \
  --start-directory "${REPO_ROOT}/tests/architecture" \
  --pattern 'test_*.py' --verbose

printf '[debug] rejecting error masking in the architecture execution path\n' >&2
if rg --line-number --fixed-strings '|| true' \
  "${REPO_ROOT}/scripts/architecture" \
  "${REPO_ROOT}/Examples/S3/infra/modules/logging-trail" \
  "${REPO_ROOT}/Examples/S3/infra/modules/s3-data-bucket"; then
  printf '[error] architecture execution path contains || true\n' >&2
  exit 1
fi
if rg --line-number 'continue-on-error:[[:space:]]*true' \
  "${REPO_ROOT}/.github/workflows"; then
  printf '[error] workflow contains continue-on-error: true\n' >&2
  exit 1
fi

printf '[debug] validating the checksum-pinned headless PlantUML contract\n' >&2
if rg --line-number --fixed-strings 'native-plantuml-' \
  "${REPO_ROOT}/scripts/ci/install-architecture-tools.sh"; then
  printf '[error] experimental native PlantUML artifact is not allowed\n' >&2
  exit 1
fi
rg --quiet --fixed-strings \
  'exec java -Djava.awt.headless=true -jar "${plantuml_jar}" "$@"' \
  "${REPO_ROOT}/scripts/ci/plantuml-wrapper.sh" || {
  printf '[error] PlantUML wrapper does not enforce headless JAR execution\n' >&2
  exit 1
}

printf '[debug] validating HCL formatting; module validation runs after isolated apply\n' >&2
tofu fmt -check -recursive "${REPO_ROOT}/Examples/S3/infra/modules"
printf '[debug] architecture contracts passed\n' >&2
