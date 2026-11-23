#!/usr/bin/env bash
# 真机（SpacemiT X60/X100，<distro> Linux）上的 A/B 与基准。
#
#   ./scripts/device-test.sh build     # 容器内静态交叉构建 A/B 两棵
#   ./scripts/device-test.sh deploy    # adb push 到板子
#   ./scripts/device-test.sh ab        # 板上跑 A/B 逐字节比对
#   ./scripts/device-test.sh bench     # 板上跑 paired 基准
#   ./scripts/device-test.sh           # 依次全做
#
# 环境变量：SERIAL（adb 序列号）、REMOTE（板上工作目录）、RVV_MARCH、
#           BUILDENV_IMAGE、BENCH_REPS。
# 静态链接，避免板子 glibc 版本差异把结果带偏。
set -euo pipefail
cd "$(dirname "$0")/.."

SERIAL=${SERIAL:-}
REMOTE=${REMOTE:-/tmp/zlib-ng-rvv}
BUILDENV_IMAGE=${BUILDENV_IMAGE:-zlib-ng-rvv-buildenv}
RVV_MARCH=${RVV_MARCH:-rv64gcv}
BENCH_REPS=${BENCH_REPS:-5}
BUILD_A=${BUILD_A:-build/device-a}
BUILD_B=${BUILD_B:-build/device-b}

adb_s() {
  if [ -n "${SERIAL}" ]; then adb -s "${SERIAL}" "$@"; else adb "$@"; fi
}

ensure_image() {
  docker image inspect "${BUILDENV_IMAGE}" >/dev/null 2>&1 || {
    echo "== 构建 docker buildenv（一次）"
    docker build -q -t "${BUILDENV_IMAGE}" -f scripts/Dockerfile.buildenv scripts/
  }
}

do_build() {
  # 每次清空：内核开关变化时增量构建会留下陈旧对象，测出来的数字是混合二进制
  rm -rf "${BUILD_A}" "${BUILD_B}"
  ensure_image
  docker run --rm -v "${PWD}":/work -w /work \
    -e RVV_MARCH="${RVV_MARCH}" -e BUILD_A="${BUILD_A}" -e BUILD_B="${BUILD_B}" \
    "${BUILDENV_IMAGE}" bash -euc '
    common=(-DCMAKE_BUILD_TYPE=Release
            -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-riscv64-linux.cmake
            -D_USE_RVV=ON -DRVV_MARCH=${RVV_MARCH}
            -DCMAKE_EXE_LINKER_FLAGS=-static)
    cmake -S . -B "${BUILD_A}" "${common[@]}"
    cmake --build "${BUILD_A}" -j"$(nproc)"
    cmake -S . -B "${BUILD_B}" "${common[@]}" -DSRC_DIR=/work/baseline -DRVV_KERNELS=OFF
    cmake --build "${BUILD_B}" -j"$(nproc)"
  '
}

do_deploy() {
  adb_s shell "mkdir -p ${REMOTE}/a ${REMOTE}/b ${REMOTE}/data"
  adb_s push "${BUILD_A}/cpu_probe" "${BUILD_A}/diff_kernels" "${REMOTE}/a/" >/dev/null
  adb_s push "${BUILD_B}/cpu_probe" "${REMOTE}/b/" >/dev/null
  # cases 目录整个推上去，保证脚本与数据同源
  adb_s push test "${REMOTE}/" >/dev/null
  echo "== 已部署到 ${REMOTE}"
}

do_ab() {
  adb_s shell "cd ${REMOTE} && RVV_A=${REMOTE}/a RVV_B=${REMOTE}/b sh test/run_ab.sh"
}

do_bench() {
  adb_s shell "cd ${REMOTE} && RVV_A=${REMOTE}/a RVV_B=${REMOTE}/b REPS=${BENCH_REPS} sh benchmark/pair_bench.sh"
}

case "${1:-all}" in
  build)  do_build ;;
  deploy) do_deploy ;;
  ab)     do_ab ;;
  bench)  do_bench ;;
  all)    do_build; do_deploy; do_ab; do_bench ;;
  *) echo "用法：$0 [build|deploy|ab|bench|all]" >&2; exit 2 ;;
esac
