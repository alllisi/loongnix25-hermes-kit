#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

need_root
assert_loongarch
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git file xz-utils unzip \
  build-essential pkg-config cmake \
  python3-venv python3-pip python3-dev \
  rustc cargo \
  libssl-dev libffi-dev zlib1g-dev \
  libjpeg-dev libpng-dev libfreetype6-dev \
  libudev-dev libevdev-dev \
  nodejs npm ripgrep x11-utils xdotool

python3 --version
gcc --version | sed -n '1p'
rustc --version
cargo --version
node --version
npm --version
