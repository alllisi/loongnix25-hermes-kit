#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
assert_loongarch
for cmd in git node npm curl unzip sha256sum; do need_cmd "${cmd}"; done
start_log 70-electron31

desktop_root="${WORK_BASE}/hermes-electron31"
if [[ ! -d "${desktop_root}/.git" ]]; then
  git clone --filter=blob:none --no-checkout "${HERMES_REPO}" "${desktop_root}"
fi
if [[ "$(git -C "${desktop_root}" rev-parse HEAD 2>/dev/null || true)" != "${HERMES_COMMIT}" ]]; then
  [[ -z "$(git -C "${desktop_root}" status --porcelain 2>/dev/null || true)" ]] ||
    die "${desktop_root} has local changes; refusing to switch commits"
  git -C "${desktop_root}" fetch --depth 1 origin "${HERMES_COMMIT}"
  git -C "${desktop_root}" checkout --detach "${HERMES_COMMIT}"
fi
unexpected_changes="$(
  git -C "${desktop_root}" status --porcelain |
    grep -Ev '^( M|M |MM) (apps/desktop/package\.json|package-lock\.json)$' || true
)"
[[ -z "${unexpected_changes}" ]] ||
  die "unexpected changes in Electron worktree: ${unexpected_changes}"
cd "${desktop_root}"

# Hermes main currently requests Electron 40, for which no tested LoongArch
# runtime is available. Keep this isolated worktree pinned to Loongson 31.7.7.
sed -i \
  -e "s/\"electron\": \"40\\.10\\.2\"/\"electron\": \"${ELECTRON_VERSION}\"/" \
  -e "s/\"electronVersion\": \"40\\.10\\.2\"/\"electronVersion\": \"${ELECTRON_VERSION}\"/" \
  apps/desktop/package.json
npm install --package-lock-only --ignore-scripts \
  --workspace apps/desktop \
  --save-dev --save-exact "electron@${ELECTRON_VERSION}"
npm ci --ignore-scripts

electron_pkg="${desktop_root}/apps/desktop/node_modules/electron"
electron_zip="${HERMES_BASE}/cache/electron-v${ELECTRON_VERSION}-linux-loong64.zip"
if [[ ! -s "${electron_zip}" ]]; then
  curl -fL --retry 5 --connect-timeout 30 \
    "https://github.com/loongson/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-loong64.zip" \
    -o "${electron_zip}.part"
  printf '%s  %s\n' "${ELECTRON_ZIP_SHA256}" "${electron_zip}.part" | sha256sum -c -
  mv "${electron_zip}.part" "${electron_zip}"
fi
printf '%s  %s\n' "${ELECTRON_ZIP_SHA256}" "${electron_zip}" | sha256sum -c -
rm -rf "${electron_pkg}/dist"
install -d -m 755 "${electron_pkg}/dist"
unzip -q "${electron_zip}" -d "${electron_pkg}/dist"
printf electron >"${electron_pkg}/path.txt"

export npm_config_cache="${HERMES_BASE}/cache/npm"
inject_native() {
  local package="$1" version="$2" archive_name="$3" target="$4" proof="$5"
  local archive="${npm_config_cache}/${archive_name}"
  install -d -m 750 "${npm_config_cache}"
  if [[ ! -s "${archive}" ]]; then
    (
      cd "${npm_config_cache}"
      npm pack "${package}@${version}" --ignore-scripts \
        --registry=https://registry.loongnix.cn:5873/
    )
  fi
  install -d -m 755 "${target}"
  tar -xzf "${archive}" -C "${target}" --strip-components=1
  test -f "${target}/${proof}"
}
inject_native \
  @rolldown/binding-linux-loong64-gnu 1.1.3 \
  rolldown-binding-linux-loong64-gnu-1.1.3.tgz \
  node_modules/@rolldown/binding-linux-loong64-gnu \
  rolldown-binding.linux-loong64-gnu.node
inject_native \
  lightningcss-linux-loong64-gnu 1.32.0 \
  lightningcss-linux-loong64-gnu-1.32.0.tgz \
  node_modules/lightningcss-linux-loong64-gnu \
  lightningcss.linux-loong64-gnu.node
inject_native \
  @tailwindcss/oxide-linux-loong64-gnu 4.3.1 \
  tailwindcss-oxide-linux-loong64-gnu-4.3.1.tgz \
  node_modules/@tailwindcss/oxide-linux-loong64-gnu \
  tailwindcss-oxide.linux-loong64-gnu.node

# The mirror copy of Shiki 4.3.0 was incomplete in the tested environment.
shiki_tgz="${npm_config_cache}/shiki-4.3.1.tgz"
if [[ ! -s "${shiki_tgz}" ]]; then
  (
    cd "${npm_config_cache}"
    npm pack shiki@4.3.1 --ignore-scripts --registry=https://registry.npmjs.org/
  )
fi
rm -rf node_modules/shiki
install -d -m 755 node_modules/shiki
tar -xzf "${shiki_tgz}" -C node_modules/shiki --strip-components=1
test -s node_modules/shiki/package.json

rm -rf apps/desktop/node_modules/node-pty
ln -s ../../../node_modules/node-pty apps/desktop/node_modules/node-pty
node apps/desktop/scripts/rebuild-native.mjs loong64
test -f node_modules/node-pty/bin/linux-loong64-125/node-pty.node

(cd apps/desktop && npm run build)
"${electron_pkg}/dist/electron" --version
file "${electron_pkg}/dist/electron"
printf '\nExperimental development tree prepared at %s\n' "${desktop_root}"
printf 'Start it from the local desktop session with:\n'
printf '  cd %q/apps/desktop && npm run dev\n' "${desktop_root}"
