#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
[[ -x "${HERMES_VENV}/bin/hermes" ]] || die "run 20-install-hermes-core.sh first"
[[ -x "${LBROWSER_BIN}" ]] || die "LBrowser not found: ${LBROWSER_BIN}"
for cmd in git cargo node npm; do need_cmd "${cmd}"; done
start_log 40-browser

source_dir="${HERMES_BASE}/src/agent-browser-v${AGENT_BROWSER_VERSION}"
install_root="${HERMES_BASE}/tools/agent-browser"
if [[ ! -d "${source_dir}/.git" ]]; then
  git clone --depth 1 --branch "v${AGENT_BROWSER_VERSION}" \
    https://github.com/vercel-labs/agent-browser.git "${source_dir}"
fi
[[ -z "$(git -C "${source_dir}" status --porcelain)" ]] ||
  die "${source_dir} has local changes"
git -C "${source_dir}" fetch --depth 1 origin "refs/tags/v${AGENT_BROWSER_VERSION}"
git -C "${source_dir}" checkout --detach "v${AGENT_BROWSER_VERSION}"

export CARGO_TARGET_DIR="${HERMES_BASE}/cache/cargo-target-agent-browser"
cargo install --root "${install_root}" --path "${source_dir}/cli" \
  --locked --jobs "${BUILD_JOBS}" --force

agent-browser --version
file "${install_root}/bin/agent-browser"

export AGENT_BROWSER_EXECUTABLE_PATH="${LBROWSER_BIN}"
export AGENT_BROWSER_ARGS=--disable-dev-shm-usage
"${HERMES_VENV}/bin/hermes" config set toolsets '["hermes-cli","browser"]'
"${HERMES_VENV}/bin/hermes" config set browser.cloud_provider local --force
"${HERMES_VENV}/bin/hermes" config set browser.engine chrome
"${HERMES_VENV}/bin/hermes" config set browser.headed false

printf 'Browser configured: %s\n' "${AGENT_BROWSER_EXECUTABLE_PATH}"
printf 'Run scripts/90-verify.sh for a local browser smoke test.\n'
