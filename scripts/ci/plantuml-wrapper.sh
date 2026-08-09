#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plantuml_jar="${SCRIPT_DIR}/../lib/plantuml.jar"

[[ -r ${plantuml_jar} ]] || {
  printf '[error] Missing PlantUML JAR: %s\n' "${plantuml_jar}" >&2
  exit 1
}
command -v java >/dev/null 2>&1 || {
  printf '[error] Java is required to run PlantUML\n' >&2
  exit 1
}

exec java -Djava.awt.headless=true -jar "${plantuml_jar}" "$@"
