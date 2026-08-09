#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../config/tool-versions.env
source "${REPO_ROOT}/config/tool-versions.env"

install_dir="${REPO_ROOT}/.tools/bin"
mkdir -p "${install_dir}"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/threat-modeling-tools.XXXXXX")"
trap 'rm -rf -- "${temp_dir}"' EXIT

platform_os="$(uname -s)"
platform_arch="$(uname -m)"
case "${platform_os}:${platform_arch}" in
  Darwin:arm64)
    task_asset="task_darwin_arm64.tar.gz"
    task_sha="debfa9a3bc06fcb5d5550b44725ecd22bb305499ce057bd6d7a774db5cdaa7b8"
    better_asset="betterleaks_${BETTERLEAKS_VERSION}_darwin_arm64.tar.gz"
    better_sha="068449bf665a07d17389a38ddee749be7d5484254e9262018e138e94b43f10c0"
    truffle_asset="trufflehog_${TRUFFLEHOG_VERSION}_darwin_arm64.tar.gz"
    truffle_sha="87478306b95ca2420cfb844b7582383ac60b922e262350a0088e797f328d2e62"
    zizmor_asset="zizmor-aarch64-apple-darwin.tar.gz"
    zizmor_sha="720322fade9e83a9c7953944c438f2ba942636b86b96a8f0e6b15ce94c8a6b6f"
    ;;
  Linux:x86_64)
    task_asset="task_linux_amd64.tar.gz"
    task_sha="02c679ffae53dca791804847d78b31731615894e292948397c971c87ac9e95bd"
    better_asset="betterleaks_${BETTERLEAKS_VERSION}_linux_x64.tar.gz"
    better_sha="9d2ed6fc387bc1c3f95557d5539077b1ce422f0db5ec38db5f14a141ad2947bf"
    truffle_asset="trufflehog_${TRUFFLEHOG_VERSION}_linux_amd64.tar.gz"
    truffle_sha="7105f1cd6577f058a9e39d0578f1a99c8a1e481e4d3512cd8a09acfe22a0fdc0"
    zizmor_asset="zizmor-x86_64-unknown-linux-gnu.tar.gz"
    zizmor_sha="dd96df044a6e8538d5f423790f453bdd03d49e5b2bcc38214acc41a2f1297839"
    ;;
  *)
    printf '[error] Unsupported platform: %s:%s\n' \
      "${platform_os}" "${platform_arch}" >&2
    exit 1
    ;;
esac

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

download_and_install() {
  local name="$1"
  local url="$2"
  local asset="$3"
  local expected_sha="$4"
  local binary_path="${5:-${name}}"
  local archive="${temp_dir}/${asset}"
  local extract_dir="${temp_dir}/${name}"

  printf '[debug] Downloading pinned %s asset %s\n' "${name}" "${asset}" >&2
  curl --fail --silent --show-error --location \
    --retry 3 --retry-all-errors --retry-delay 1 \
    "${url}/${asset}" --output "${archive}"
  verify_sha256 "${expected_sha}" "${archive}"
  mkdir -p "${extract_dir}"
  tar -xzf "${archive}" -C "${extract_dir}"
  install -m 0755 "${extract_dir}/${binary_path}" "${install_dir}/${name}"
}

download_and_install task \
  "https://github.com/go-task/task/releases/download/v${TASK_VERSION}" \
  "${task_asset}" "${task_sha}"
download_and_install betterleaks \
  "https://github.com/betterleaks/betterleaks/releases/download/v${BETTERLEAKS_VERSION}" \
  "${better_asset}" "${better_sha}"
download_and_install trufflehog \
  "https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}" \
  "${truffle_asset}" "${truffle_sha}"
download_and_install zizmor \
  "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}" \
  "${zizmor_asset}" "${zizmor_sha}"

trunk_launcher="${temp_dir}/trunk"
printf '[debug] Downloading checksum-pinned Trunk launcher for CLI %s\n' \
  "${TRUNK_VERSION}" >&2
curl --fail --silent --show-error --location \
  --retry 3 --retry-all-errors --retry-delay 1 \
  "https://trunk.io/releases/trunk" --output "${trunk_launcher}"
verify_sha256 \
  "89fbdd8c7b63649eeb1479415757b898903c041e73b49b78028dbd64eca3087a" \
  "${trunk_launcher}"
install -m 0755 "${trunk_launcher}" "${install_dir}/trunk"

printf '[debug] Installed pinned security tools in %s\n' "${install_dir}" >&2
