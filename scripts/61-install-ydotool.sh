#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
for cmd in curl cmake sha256sum sudo; do need_cmd "${cmd}"; done
start_log 61-ydotool

archive_dir="${HERMES_BASE}/cache/ydotool"
archive="${archive_dir}/ydotool-v${YDO_VERSION}.tar.gz"
source_dir="${HERMES_BASE}/src/ydotool-${YDO_VERSION}"
prefix="${HERMES_BASE}/tools/ydotool"
install -d -m 750 "${archive_dir}" "${HERMES_BASE}/src"

if [[ ! -s "${archive}" ]]; then
  curl -fL --retry 4 --connect-timeout 30 \
    "https://github.com/ReimuNotMoe/ydotool/archive/refs/tags/v${YDO_VERSION}.tar.gz" \
    -o "${archive}.part"
  printf '%s  %s\n' "${YDO_ARCHIVE_SHA256}" "${archive}.part" | sha256sum -c -
  mv "${archive}.part" "${archive}"
fi
printf '%s  %s\n' "${YDO_ARCHIVE_SHA256}" "${archive}" | sha256sum -c -

if [[ ! -f "${source_dir}/CMakeLists.txt" ]]; then
  tar -xzf "${archive}" -C "${HERMES_BASE}/src"
fi
cmake -S "${source_dir}" -B "${source_dir}/build-loongarch" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${prefix}"
cmake --build "${source_dir}/build-loongarch" --parallel "${BUILD_JOBS}" \
  --target ydotool ydotoold
install -d -m 755 "${prefix}/bin"
install -m 755 \
  "${source_dir}/build-loongarch/ydotool" \
  "${source_dir}/build-loongarch/ydotoold" \
  "${prefix}/bin/"

target_user="$(id -un)"
target_uid="$(id -u)"
target_gid="$(id -g)"
unit_tmp="$(mktemp)"
trap 'rm -f "${unit_tmp}"' EXIT
cat >"${unit_tmp}" <<UNIT
[Unit]
Description=Hermes Computer Use ydotool input daemon
After=systemd-udevd.service

[Service]
Type=simple
ExecStart=${prefix}/bin/ydotoold --socket-path=/tmp/.ydotool_socket --socket-perm=0600 --socket-own=${target_uid}:${target_gid}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

sudo test -c /dev/uinput
sudo install -m 644 "${unit_tmp}" /etc/systemd/system/hermes-ydotoold.service
sudo ln -sfn "${prefix}/bin/ydotool" /usr/local/bin/ydotool
sudo ln -sfn "${prefix}/bin/ydotoold" /usr/local/sbin/ydotoold
sudo systemctl daemon-reload
sudo systemctl enable --now hermes-ydotoold.service
sleep 2

sudo systemctl --no-pager --full status hermes-ydotoold.service
[[ "$(stat -c %u /tmp/.ydotool_socket)" == "${target_uid}" ]]
[[ "$(stat -c %g /tmp/.ydotool_socket)" == "${target_gid}" ]]
YDOTOOL_SOCKET=/tmp/.ydotool_socket "${prefix}/bin/ydotool" debug

printf '\nWARNING: ydotoold can synthesize keyboard and mouse input.\n'
printf 'Its socket is mode 0600 and owned only by %s; do not loosen this permission.\n' "${target_user}"
