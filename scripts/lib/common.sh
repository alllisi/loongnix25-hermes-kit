#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd)"
KIT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${HERMES_KIT_ENV:-${KIT_ROOT}/config/deploy.env}"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
elif [[ -f "${KIT_ROOT}/config/deploy.env.example" ]]; then
  # Safe defaults; no credential is stored in this example file.
  # shellcheck disable=SC1091
  source "${KIT_ROOT}/config/deploy.env.example"
fi

: "${HERMES_BASE:=/data/hermes}"
: "${WORK_BASE:=/data/work}"
: "${HERMES_REPO:=https://github.com/NousResearch/hermes-agent.git}"
: "${HERMES_COMMIT:=07e97d2f5dc3d2092cfe693ef07b2527a36cd2d8}"
: "${AGENT_BROWSER_VERSION:=0.26.0}"
: "${LBROWSER_BIN:=/opt/apps/lbrowser/lbrowser}"
: "${COMPUTER_USE_REPO:=https://github.com/agent-sh/computer-use-linux.git}"
: "${COMPUTER_USE_COMMIT:=8cc1fafb78d9df047ca89a1974735c1a2bbc5060}"
: "${YDO_VERSION:=1.0.4}"
: "${YDO_ARCHIVE_SHA256:=ba075a43aa6ead51940e892ecffa4d0b8b40c241e4e2bc4bd9bd26b61fde23bd}"
: "${ELECTRON_VERSION:=31.7.7}"
: "${ELECTRON_ZIP_SHA256:=ad4ba5f41931142e2716b7dc1eb0a67330ec12a49dec0d3ed51d1e58b3da117e}"
: "${BUILD_JOBS:=1}"

HERMES_SOURCE="${HERMES_BASE}/src/hermes-agent"
HERMES_VENV="${HERMES_BASE}/venv/hermes-agent"
HERMES_HOME="${HERMES_BASE}/.hermes"
LOG_DIR="${HERMES_BASE}/deploy/logs"

export HERMES_HOME
export TMPDIR="${HERMES_BASE}/build-tmp"
export PIP_CACHE_DIR="${HERMES_BASE}/cache/pip"
export CARGO_HOME="${HERMES_BASE}/cache/cargo"
export CARGO_TARGET_DIR="${HERMES_BASE}/cache/cargo-target"
export RUSTUP_HOME="${HERMES_BASE}/toolchains/rustup"
export PATH="${HERMES_BASE}/tools/agent-browser/bin:${CARGO_HOME}/bin:${HOME}/.local/bin:${PATH}"
export CARGO_BUILD_JOBS="${BUILD_JOBS}"
export MAKEFLAGS="-j${BUILD_JOBS}"
export PIP_DISABLE_PIP_VERSION_CHECK=1

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

need_user() {
  [[ "$(id -u)" -ne 0 ]] || die "run this stage as a normal desktop user"
}

need_root() {
  [[ "$(id -u)" -eq 0 ]] || die "run this stage with sudo"
}

prepare_layout() {
  install -d -m 750 \
    "${HERMES_BASE}" "${HERMES_BASE}/src" "${HERMES_BASE}/venv" \
    "${HERMES_BASE}/cache" "${HERMES_BASE}/cache/pip" \
    "${HERMES_BASE}/cache/cargo" "${HERMES_BASE}/build-tmp" \
    "${HERMES_BASE}/deploy" "${LOG_DIR}"
  install -d -m 700 "${HERMES_HOME}"
}

start_log() {
  local name="$1"
  prepare_layout
  exec > >(tee -a "${LOG_DIR}/${name}-$(date +%Y%m%d-%H%M%S).log") 2>&1
  printf '===== %s START %s =====\n' "${name}" "$(date -Is)"
}

assert_loongarch() {
  local arch
  arch="$(uname -m)"
  [[ "${arch}" == "loongarch64" ]] ||
    die "expected uname -m=loongarch64, got ${arch}"
  if command -v dpkg >/dev/null 2>&1; then
    [[ "$(dpkg --print-architecture)" == "loong64" ]] ||
      die "expected dpkg architecture loong64"
  fi
}

ensure_clean_checkout() {
  local repo="$1" commit="$2"
  [[ -z "$(git -C "${repo}" status --porcelain)" ]] ||
    die "${repo} has local changes; refusing to switch commits"
  git -C "${repo}" fetch --depth 1 origin "${commit}"
  git -C "${repo}" checkout --detach "${commit}"
  [[ "$(git -C "${repo}" rev-parse HEAD)" == "${commit}" ]] ||
    die "source revision mismatch"
}
