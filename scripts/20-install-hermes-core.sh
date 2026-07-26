#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
for cmd in git curl python3 sha256sum; do need_cmd "${cmd}"; done
start_log 20-hermes-core

install -d -m 750 \
  "${HERMES_BASE}/cache/preload" "${CARGO_TARGET_DIR}" \
  "${RUSTUP_HOME}" "${CARGO_HOME}"

export RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup
export RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup
if [[ ! -x "${CARGO_HOME}/bin/rustup" ]]; then
  rustup_init="${HERMES_BASE}/cache/rustup-init-loongarch64"
  curl -fL --retry 5 --connect-timeout 30 \
    "${RUSTUP_UPDATE_ROOT}/dist/loongarch64-unknown-linux-gnu/rustup-init" \
    -o "${rustup_init}"
  chmod 750 "${rustup_init}"
  "${rustup_init}" -y --profile minimal --default-toolchain stable --no-modify-path
fi
rustup default stable
rustc --version --verbose

pillow_archive="${HERMES_BASE}/cache/preload/pillow-12.2.0.tar.gz"
pillow_sha=a830b1a40919539d07806aa58e1b114df53ddd43213d9c8b75847eee6c0182b5
if [[ ! -s "${pillow_archive}" ]]; then
  curl -fL --retry 5 --connect-timeout 30 \
    https://pypi.tuna.tsinghua.edu.cn/packages/8c/21/c2bcdd5906101a30244eaffc1b6e6ce71a31bd0742a01eb89e660ebfac2d/pillow-12.2.0.tar.gz \
    -o "${pillow_archive}.part"
  printf '%s  %s\n' "${pillow_sha}" "${pillow_archive}.part" | sha256sum -c -
  mv "${pillow_archive}.part" "${pillow_archive}"
fi
printf '%s  %s\n' "${pillow_sha}" "${pillow_archive}" | sha256sum -c -

if [[ ! -d "${HERMES_SOURCE}/.git" ]]; then
  git clone --filter=blob:none --no-checkout "${HERMES_REPO}" "${HERMES_SOURCE}"
fi
ensure_clean_checkout "${HERMES_SOURCE}" "${HERMES_COMMIT}"

if [[ ! -x "${HERMES_VENV}/bin/python" ]]; then
  python3 -m venv "${HERMES_VENV}"
fi

export PIP_INDEX_URL=https://pypi.org/simple
export PIP_FIND_LINKS="${HERMES_BASE}/cache/preload"
"${HERMES_VENV}/bin/python" -m pip install --upgrade pip setuptools wheel
if ! "${HERMES_VENV}/bin/python" -c \
  'import PIL; assert PIL.__version__ == "12.2.0"' 2>/dev/null; then
  "${HERMES_VENV}/bin/python" -m pip install "${pillow_archive}"
fi
"${HERMES_VENV}/bin/python" -m pip install --editable "${HERMES_SOURCE}"

wrapper="${HOME}/.local/bin/hermes"
install -d -m 755 "$(dirname "${wrapper}")"
{
  printf '#!/usr/bin/env bash\n'
  printf 'export HERMES_HOME=%q\n' "${HERMES_HOME}"
  printf 'export TMPDIR=%q\n' "${TMPDIR}"
  printf 'export CARGO_HOME=%q\n' "${CARGO_HOME}"
  printf 'export RUSTUP_HOME=%q\n' "${RUSTUP_HOME}"
  printf 'export PATH=%q/bin:%q/bin:"$PATH"\n' \
    "${HERMES_BASE}/tools/agent-browser" "${CARGO_HOME}"
  printf 'export AGENT_BROWSER_EXECUTABLE_PATH=%q\n' "${LBROWSER_BIN}"
  printf 'export AGENT_BROWSER_ARGS=%q\n' "--disable-dev-shm-usage"
  printf 'exec %q "$@"\n' "${HERMES_VENV}/bin/hermes"
} >"${wrapper}"
chmod 755 "${wrapper}"

"${wrapper}" --version
"${HERMES_VENV}/bin/python" -m pip check
printf 'Installed Hermes commit: %s\n' "$(git -C "${HERMES_SOURCE}" rev-parse HEAD)"
