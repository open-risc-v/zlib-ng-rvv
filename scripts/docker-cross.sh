#!/usr/bin/env bash
# 不装本地交叉工具链也能跑完整套件：Ubuntu 容器里交叉编译 + qemu-user 执行。
# 结论只能用于功能回归，性能数字不可信（qemu 不做等时建模）。
#
#   ./scripts/docker-cross.sh
set -euo pipefail
cd "$(dirname "$0")/.."

docker run --rm -v "$PWD":/work -w /work ubuntu:24.04 bash -euc '
   export DEBIAN_FRONTEND=noninteractive
   apt-get update -qq
   apt-get install -y -qq build-essential cmake gcc-14-riscv64-linux-gnu \
       gcc-riscv64-linux-gnu libc6-dev-riscv64-cross qemu-user > /dev/null
   ln -sf /usr/bin/riscv64-linux-gnu-gcc-14 /usr/bin/riscv64-linux-gnu-gcc

   cmake -S . -B build/riscv64-docker -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-riscv64-linux.cmake \
         -D_USE_RVV=ON -DRVV_MARCH=rv64gcv
   cmake --build build/riscv64-docker -j"$(nproc)"

   qemu-riscv64 -L /usr/riscv64-linux-gnu build/riscv64-docker/cpu_probe || true
   qemu-riscv64 -L /usr/riscv64-linux-gnu build/riscv64-docker/diff_kernels
   RUNNER="qemu-riscv64 -L /usr/riscv64-linux-gnu" ./test/run_ab.sh
'
