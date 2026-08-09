#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../config/tool-versions.env
source "${REPO_ROOT}/config/tool-versions.env"

install_dir="${REPO_ROOT}/.tools/bin"
mkdir -p "${install_dir}"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/meridian-architecture-tools.XXXXXX")"
cleanup() {
  [[ -d ${temp_dir} && ${temp_dir} == "${TMPDIR:-/tmp}/meridian-architecture-tools."* ]] || {
    printf '[error] Refusing to remove unexpected temporary path: %s\n' "${temp_dir}" >&2
    exit 1
  }
  rm -rf -- "${temp_dir}"
}
trap cleanup EXIT

verify_sha256() {
  local expected="$1"
  local file="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${file}" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "${file}" | awk '{print $1}')"
  fi
  [[ ${actual} == "${expected}" ]] || {
    printf '[error] SHA-256 mismatch for %s\n' "$(basename "${file}")" >&2
    exit 1
  }
}

download() {
  local url="$1"
  local destination="$2"
  printf '[debug] Downloading %s\n' "${url}" >&2
  curl --fail --silent --show-error --location \
    --retry 3 --retry-all-errors --retry-delay 1 \
    "${url}" --output "${destination}"
}

kernel_name="$(uname -s)"
machine_arch="$(uname -m)"
platform="${kernel_name}:${machine_arch}"
case "${platform}" in
  Darwin:arm64)
    tofu_asset="tofu_${OPENTOFU_VERSION}_darwin_arm64.zip"
    tofu_sha="dbb5a5bae9b0cabf622cd81a80ea02230eae8a3813215400df41a2cb89b47157"
    terragrunt_asset="terragrunt_darwin_arm64"
    terragrunt_sha="f3e6418181699e14ea282257e36ea6be3949ff9ebd4854eff6bd2fe51130791a"
    floci_asset="floci-darwin-arm64"
    floci_sha="6fdf3b2f25da9cb9287a10069a19134bb33b227ca4ec5d7f2e7e724e7f6f4ec8"
    d2_platform="macos-arm64"
    d2_sha="80de85f3b0ac7d9569acac0780ed65dd994ea78969b6b230c58bbb2c6113465b"
    plantuml_platform="macos-arm64"
    plantuml_sha="12222c236aada460e379a694aa6329ea594c0e3eee11aa411665b43c8562bbf2"
    ;;
  Linux:x86_64)
    tofu_asset="tofu_${OPENTOFU_VERSION}_linux_amd64.zip"
    tofu_sha="dade9650e6b74fc7a8b986bd8717497d32f9e09cf82e479afef4977fa3085536"
    terragrunt_asset="terragrunt_linux_amd64"
    terragrunt_sha="534070d5b261a0e65b3f490479f602a8f80a0ae115e399a3786802cce658aeaa"
    floci_asset="floci-linux-amd64"
    floci_sha="6a45b23f7b3a9fae9214e1028190c56398dfaf35bdfd3fe2c24c6735be841933"
    d2_platform="linux-amd64"
    d2_sha="eb172adf59f38d1e5a70ab177591356754ffaf9bebb84e0ca8b767dfb421dad7"
    plantuml_platform="linux-amd64"
    plantuml_sha="835c238634ed1b8638c3fdcfe4f94d005fc9664df3da2c88f80d0aaf4471b04b"
    ;;
  *)
    printf '[error] Unsupported platform: %s\n' "${platform}" >&2
    exit 1
    ;;
esac

tofu_zip="${temp_dir}/${tofu_asset}"
download "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/${tofu_asset}" "${tofu_zip}"
verify_sha256 "${tofu_sha}" "${tofu_zip}"
unzip -q "${tofu_zip}" -d "${temp_dir}/tofu"
install -m 0755 "${temp_dir}/tofu/tofu" "${install_dir}/tofu"

terragrunt_binary="${temp_dir}/${terragrunt_asset}"
download "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/${terragrunt_asset}" "${terragrunt_binary}"
verify_sha256 "${terragrunt_sha}" "${terragrunt_binary}"
install -m 0755 "${terragrunt_binary}" "${install_dir}/terragrunt"

floci_binary="${temp_dir}/${floci_asset}"
download "https://github.com/floci-io/floci-cli/releases/download/${FLOCI_CLI_VERSION}/${floci_asset}" "${floci_binary}"
verify_sha256 "${floci_sha}" "${floci_binary}"
install -m 0755 "${floci_binary}" "${install_dir}/floci"

d2_asset="d2-v${D2_VERSION}-${d2_platform}.tar.gz"
d2_archive="${temp_dir}/${d2_asset}"
download "https://github.com/terrastruct/d2/releases/download/v${D2_VERSION}/${d2_asset}" \
  "${d2_archive}"
verify_sha256 "${d2_sha}" "${d2_archive}"
tar -xzf "${d2_archive}" -C "${temp_dir}"
install -m 0755 "${temp_dir}/d2-v${D2_VERSION}/bin/d2" "${install_dir}/d2"

plantuml_asset="native-plantuml-${plantuml_platform}-${PLANTUML_VERSION}.zip"
plantuml_archive="${temp_dir}/${plantuml_asset}"
download "https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/${plantuml_asset}" \
  "${plantuml_archive}"
verify_sha256 "${plantuml_sha}" "${plantuml_archive}"
unzip -q "${plantuml_archive}" -d "${temp_dir}/plantuml"
install -m 0755 "${temp_dir}/plantuml/plantuml" "${install_dir}/plantuml"

if [[ ${platform} == Linux:x86_64 ]]; then
  aws_zip="${temp_dir}/awscli.zip"
  download "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" "${aws_zip}"
  verify_sha256 "545f9bf0cd58e0f30f3a9470d3c4e3387148006bf30f41fb3a4a167347be815f" "${aws_zip}"
  unzip -q "${aws_zip}" -d "${temp_dir}/aws"
  aws_install_args=(
    --install-dir "${REPO_ROOT}/.tools/aws-cli"
    --bin-dir "${install_dir}"
  )
  if [[ -d ${REPO_ROOT}/.tools/aws-cli ]]; then
    aws_install_args+=(--update)
  fi
  "${temp_dir}/aws/aws/install" "${aws_install_args[@]}"
fi

command -v go >/dev/null || {
  printf '[error] Go %s is required to build awsdac\n' "${GO_VERSION}" >&2
  exit 1
}
printf '[debug] Building awsdac at commit %s\n' "${AWSDAC_COMMIT}" >&2
GOBIN="${install_dir}" go install \
  "github.com/awslabs/diagram-as-code/cmd/awsdac@${AWSDAC_COMMIT}"

printf '[debug] Installed pinned architecture tools in %s\n' "${install_dir}" >&2
