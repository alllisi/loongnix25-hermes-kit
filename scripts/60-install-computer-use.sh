#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
[[ -x "${HERMES_VENV}/bin/hermes" ]] || die "run 20-install-hermes-core.sh first"
for cmd in git cargo file; do need_cmd "${cmd}"; done
start_log 60-computer-use

source_dir="${HERMES_BASE}/src/computer-use-linux"
install_dir="${HERMES_BASE}/bin"
if [[ ! -d "${source_dir}/.git" ]]; then
  git clone --filter=blob:none --no-checkout \
    "${COMPUTER_USE_REPO}" "${source_dir}"
fi
ensure_clean_checkout "${source_dir}" "${COMPUTER_USE_COMMIT}"

cd "${source_dir}"
if [[ ! -f Cargo.lock ]]; then
  cargo generate-lockfile
fi
export CARGO_TARGET_DIR="${HERMES_BASE}/cache/cargo-target-computer-use"
cargo build --locked --release --jobs "${BUILD_JOBS}"

install -d -m 755 "${install_dir}"
install -m 755 \
  "${CARGO_TARGET_DIR}/release/computer-use-linux" \
  "${CARGO_TARGET_DIR}/release/computer-use-linux-cosmic" \
  "${install_dir}/"
file "${install_dir}/computer-use-linux"
ldd "${install_dir}/computer-use-linux"

# Hermes 0.19.0 MCP dependency chain needs a native rpds-py wheel on LoongArch.
export PIP_INDEX_URL=https://pypi.org/simple
"${HERMES_VENV}/bin/python" -m pip install "maturin==1.9.6"
env PATH="${HERMES_VENV}/bin:${PATH}" \
  CARGO_TARGET_DIR="${HERMES_BASE}/cache/cargo-target-rpds" \
  "${HERMES_VENV}/bin/python" -m pip install \
    --no-build-isolation "rpds-py==0.25.1"
"${HERMES_VENV}/bin/python" -m pip install \
  "mcp==1.26.0" "starlette==1.0.1"
"${HERMES_VENV}/bin/python" -m pip check

"${HERMES_VENV}/bin/hermes" mcp remove computer-use-linux >/dev/null 2>&1 || true
"${HERMES_VENV}/bin/hermes" mcp add computer-use-linux \
  --connect-timeout 30 \
  --command "${install_dir}/computer-use-linux" \
  --args mcp
"${HERMES_VENV}/bin/hermes" mcp test computer-use-linux

printf '\nMCP registration is complete. Run 61-install-ydotool.sh before claiming keyboard/mouse input works.\n'
