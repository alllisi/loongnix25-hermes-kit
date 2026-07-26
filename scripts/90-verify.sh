#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
[[ -x "${HERMES_VENV}/bin/hermes" ]] || die "Hermes is not installed"

printf '=== Core ===\n'
"${HERMES_VENV}/bin/hermes" --version
"${HERMES_VENV}/bin/python" -m pip check
printf 'source=%s\n' "$(git -C "${HERMES_SOURCE}" rev-parse HEAD)"
printf 'config_mode=%s env_mode=%s\n' \
  "$(stat -c %a "${HERMES_HOME}/config.yaml" 2>/dev/null || printf missing)" \
  "$(stat -c %a "${HERMES_HOME}/.env" 2>/dev/null || printf missing)"

printf '\n=== Browser ===\n'
if command -v agent-browser >/dev/null 2>&1 && [[ -x "${LBROWSER_BIN}" ]]; then
  agent-browser --version
  file "$(command -v agent-browser)"
  "${LBROWSER_BIN}" --version
else
  printf 'SKIP: browser stage is not installed.\n'
fi

printf '\n=== Dashboard ===\n'
if systemctl --user is-enabled hermes-dashboard.service >/dev/null 2>&1; then
  systemctl --user --no-pager --full status hermes-dashboard.service || true
  curl -fsS http://127.0.0.1:9119/api/status
  printf '\n'
else
  printf 'SKIP: Dashboard service is not enabled.\n'
fi

printf '\n=== Computer Use ===\n'
if [[ -x "${HERMES_BASE}/bin/computer-use-linux" ]]; then
  file "${HERMES_BASE}/bin/computer-use-linux"
  "${HERMES_VENV}/bin/hermes" mcp test computer-use-linux
  "${HERMES_BASE}/bin/computer-use-linux" doctor || true
  if systemctl is-active hermes-ydotoold.service >/dev/null 2>&1; then
    ls -l /tmp/.ydotool_socket
    YDOTOOL_SOCKET=/tmp/.ydotool_socket ydotool debug
  else
    printf 'NOTICE: ydotoold is not active; do not claim click/type is ready.\n'
  fi
else
  printf 'SKIP: Computer Use is not installed.\n'
fi

printf '\nVerification finished. Model inference and GUI clicks remain explicit opt-in tests.\n'
