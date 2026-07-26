#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
[[ -x "${HERMES_VENV}/bin/hermes" ]] || die "run 20-install-hermes-core.sh first"

model="${DEEPSEEK_MODEL:-deepseek-v4-pro}"
key="${DEEPSEEK_API_KEY:-}"
if [[ -z "${key}" ]]; then
  read -r -s -p "DeepSeek API Key（输入不回显）: " key
  printf '\n'
fi
[[ -n "${key}" ]] || die "API Key cannot be empty"

install -d -m 700 "${HERMES_HOME}"
env_file="${HERMES_HOME}/.env"
tmp_file="${env_file}.tmp.$$"
umask 077
if [[ -f "${env_file}" ]]; then
  grep -v '^DEEPSEEK_API_KEY=' "${env_file}" >"${tmp_file}" || true
fi
printf 'DEEPSEEK_API_KEY=%s\n' "${key}" >>"${tmp_file}"
mv "${tmp_file}" "${env_file}"
chmod 600 "${env_file}"
unset key DEEPSEEK_API_KEY

"${HERMES_VENV}/bin/hermes" config set model.provider deepseek
"${HERMES_VENV}/bin/hermes" config set model.default "${model}"
chmod 600 "${HERMES_HOME}/config.yaml"

printf 'provider=%s\n' "$("${HERMES_VENV}/bin/hermes" config get model.provider)"
printf 'model=%s\n' "$("${HERMES_VENV}/bin/hermes" config get model.default)"
printf 'credential_file=%s mode=%s\n' \
  "${env_file}" "$(stat -c %a "${env_file}")"
