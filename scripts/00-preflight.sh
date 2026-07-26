#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch

printf '%-24s %s\n' \
  "OS" "$(. /etc/os-release; printf '%s %s' "${NAME}" "${VERSION_ID:-}")" \
  "uname architecture" "$(uname -m)" \
  "dpkg architecture" "$(dpkg --print-architecture)" \
  "kernel" "$(uname -r)" \
  "glibc" "$(getconf GNU_LIBC_VERSION)" \
  "Hermes base" "${HERMES_BASE}" \
  "work base" "${WORK_BASE}"

for path in "${HERMES_BASE}" "${WORK_BASE}"; do
  if [[ -e "${path}" ]]; then
    df -hT "${path}"
  else
    parent="$(dirname "${path}")"
    [[ -d "${parent}" ]] || die "parent directory does not exist: ${parent}"
    [[ -w "${parent}" ]] ||
      printf 'NOTICE: %s must be created/chowned before normal-user stages.\n' "${path}"
    df -hT "${parent}"
  fi
done

free -h

mem_kib="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
swap_kib="$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)"
if (( mem_kib < 3000000 && swap_kib < 3000000 )); then
  printf 'WARNING: less than 3 GiB swap detected; native Rust/Node builds may OOM.\n'
fi

[[ -x "${LBROWSER_BIN}" ]] &&
  printf 'LBrowser: %s\n' "${LBROWSER_BIN}" ||
  printf 'NOTICE: LBrowser not found at %s; browser stage will stop.\n' "${LBROWSER_BIN}"

printf '\nPreflight passed. This script did not modify the system.\n'
