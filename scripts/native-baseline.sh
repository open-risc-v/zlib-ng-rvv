#!/usr/bin/env bash
# 本机不编译：native 基线在 Linux 容器里跑（同架构、同 glibc，可与 riscv64 侧对齐）。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${1:-${IMAGE:-rvv-cross:2}}
docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc '
  set -e
  rm -rf build/ab-a build/ab-b build/ab-data
  ./test/run_ab.sh
'
