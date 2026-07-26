#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_user
desktop_dir="${WORK_BASE}/hermes-electron31/apps/desktop"
[[ -d "${desktop_dir}" ]] || die "run 70-prepare-electron31-dev.sh first"
[[ -n "${DISPLAY:-}" ]] || die "run this command inside the Loongnix graphical session"

cd "${desktop_dir}"
exec npm run dev
