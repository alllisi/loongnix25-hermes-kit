#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
[[ -x "${HERMES_VENV}/bin/python" ]] || die "run 20-install-hermes-core.sh first"
for cmd in node npm tar; do need_cmd "${cmd}"; done
start_log 50-dashboard

cd "${HERMES_SOURCE}"
export npm_config_cache="${HERMES_BASE}/cache/npm"
export npm_config_registry=https://registry.npmjs.org/
export npm_config_fund=false
export npm_config_audit=false
export npm_config_progress=false
export NODE_OPTIONS=--max-old-space-size=1536
install -d -m 750 "${npm_config_cache}"

npm ci --ignore-scripts --workspace web

inject_binding() {
  local package="$1" version="$2" archive_name="$3" target="$4" proof="$5"
  local archive="${npm_config_cache}/${archive_name}"
  if [[ ! -s "${archive}" ]]; then
    (
      cd "${npm_config_cache}"
      npm pack "${package}@${version}" --ignore-scripts \
        --registry=https://registry.loongnix.cn:5873/
    )
  fi
  install -d -m 755 "${target}"
  tar -xzf "${archive}" -C "${target}" --strip-components=1
  [[ -f "${target}/${proof}" ]] || die "missing native binding: ${proof}"
}

inject_binding \
  @rolldown/binding-linux-loong64-gnu 1.1.3 \
  rolldown-binding-linux-loong64-gnu-1.1.3.tgz \
  node_modules/@rolldown/binding-linux-loong64-gnu \
  rolldown-binding.linux-loong64-gnu.node
inject_binding \
  lightningcss-linux-loong64-gnu 1.32.0 \
  lightningcss-linux-loong64-gnu-1.32.0.tgz \
  node_modules/lightningcss-linux-loong64-gnu \
  lightningcss.linux-loong64-gnu.node
inject_binding \
  @tailwindcss/oxide-linux-loong64-gnu 4.3.1 \
  tailwindcss-oxide-linux-loong64-gnu-4.3.1.tgz \
  node_modules/@tailwindcss/oxide-linux-loong64-gnu \
  tailwindcss-oxide.linux-loong64-gnu.node

npm run build -w web
test -s "${HERMES_SOURCE}/hermes_cli/web_dist/index.html"
du -sh "${HERMES_SOURCE}/hermes_cli/web_dist"

unit_dir="${HOME}/.config/systemd/user"
install -d -m 700 "${unit_dir}"
cat >"${unit_dir}/hermes-dashboard.service" <<UNIT
[Unit]
Description=Hermes Agent Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${HERMES_BASE}
ExecStart=${HOME}/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open --skip-build
Restart=on-failure
RestartSec=5
TimeoutStopSec=20

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now hermes-dashboard.service
printf 'To keep the user service alive without login, run once:\n'
printf '  sudo loginctl enable-linger %q\n' "$(id -un)"

for _ in {1..10}; do
  if curl -fsS http://127.0.0.1:9119/api/status \
    -o "${TMPDIR}/dashboard-status.json"; then
    break
  fi
  sleep 2
done
test -s "${TMPDIR}/dashboard-status.json"
cat "${TMPDIR}/dashboard-status.json"
printf '\nDashboard is listening only on http://127.0.0.1:9119/\n'
