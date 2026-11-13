#!/usr/bin/env bash
# A/B 位精确回归门禁。
#
# 同一套用例、同样的编译选项，分别跑在：
#   A = src/（开 RVV 内核）      B = baseline/（同一 -march，RVV_KERNELS=OFF）
# 然后逐字节比较两侧产出。A/B 只允许"内核宏"一个变量不同。
#
#   ./test/run_ab.sh                          # 本机（native 工具链）
#   CMAKE_ARGS="-DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-riscv64-linux.cmake -D_USE_RVV=ON" \
#   RUNNER="qemu-riscv64 -L /usr/riscv64-linux-gnu" ./test/run_ab.sh
#   在板子上：RVV_A=/tmp/x/a RVV_B=/tmp/x/b sh test/run_ab.sh
#
# 用例约定（test/cases/*.sh）：
#   STAGE=gen  只用 A 侧生成输入，写到 ${DATA}
#   STAGE=run  用 ${BIN} 里的程序，把产出写到 ${OUT}
# 每个用例必须自己创建 ${OUT} 下的文件；没有产出文件视为不通过（防止空跑）。
set -euo pipefail
cd "$(dirname "$0")/.."

A_DIR=${A_DIR:-src}
B_DIR=${B_DIR:-baseline}
CMAKE_ARGS=${CMAKE_ARGS:-}
RUNNER=${RUNNER:-}
DATA=${DATA:-}
OUT_ROOT=${OUT_ROOT:-}

if [ -n "${CMAKE_ARGS}" ]; then
  BUILD_A=${BUILD_A:-build/ab-x-a}
  BUILD_B=${BUILD_B:-build/ab-x-b}
  DATA=${DATA:-build/ab-x-data}
else
  BUILD_A=${BUILD_A:-build/ab-a}
  BUILD_B=${BUILD_B:-build/ab-b}
  DATA=${DATA:-build/ab-data}
fi
OUT_ROOT=${OUT_ROOT:-${DATA}/out}

# 板子上没有 cmake：RVV_A/RVV_B 直接给出已部署的二进制目录
DEVICE_MODE=0
if [ -n "${RVV_A:-}" ] && [ -n "${RVV_B:-}" ]; then
  DEVICE_MODE=1
  BUILD_A=${RVV_A}
  BUILD_B=${RVV_B}
fi

run() { ${RUNNER} "$@"; }

if [ "${DEVICE_MODE}" -eq 0 ]; then
  echo "== 构建 A（${A_DIR}）"
  cmake -S . -B "${BUILD_A}" -DCMAKE_BUILD_TYPE=Release -DSRC_DIR="${PWD}/${A_DIR}" ${CMAKE_ARGS} >/dev/null
  cmake --build "${BUILD_A}" -j >/dev/null
  echo "== 构建 B（${B_DIR}，内核关闭）"
  cmake -S . -B "${BUILD_B}" -DCMAKE_BUILD_TYPE=Release -DSRC_DIR="${PWD}/${B_DIR}" \
        -DRVV_KERNELS=OFF ${CMAKE_ARGS} >/dev/null
  cmake --build "${BUILD_B}" -j >/dev/null
fi

mkdir -p "${DATA}"
shopt -s nullglob
cases=(test/cases/*.sh)
if [ ${#cases[@]} -eq 0 ]; then
  echo "错误：test/cases/ 下没有用例" >&2
  exit 2
fi

fail=0
pass=0
for c in "${cases[@]}"; do
  name=$(basename "${c}" .sh)
  out_a=${OUT_ROOT}/${name}/a
  out_b=${OUT_ROOT}/${name}/b
  rm -rf "${out_a}" "${out_b}"
  mkdir -p "${out_a}" "${out_b}"

  STAGE=gen SIDE=A BIN="${BUILD_A}" DATA="${DATA}" OUT="${out_a}" run bash "${c}" >/dev/null 2>&1 || {
    echo "FAIL ${name}（生成输入失败，可能是上游未就位）"; fail=1; continue; }
  STAGE=run SIDE=A BIN="${BUILD_A}" DATA="${DATA}" OUT="${out_a}" run bash "${c}" || {
    echo "FAIL ${name}（A 侧运行失败）"; fail=1; continue; }
  STAGE=run SIDE=B BIN="${BUILD_B}" DATA="${DATA}" OUT="${out_b}" run bash "${c}" || {
    echo "FAIL ${name}（B 侧运行失败）"; fail=1; continue; }

  produced=$(find "${out_a}" -type f | wc -l | tr -d ' ')
  if [ "${produced}" -eq 0 ]; then
    echo "FAIL ${name}（A 侧没有产出文件）"; fail=1; continue
  fi

  if ! diff -r --brief "${out_a}" "${out_b}" >/dev/null; then
    echo "FAIL ${name}（产出不一致）："
    diff -r --brief "${out_a}" "${out_b}" | sed 's/^/    /'
    fail=1
    continue
  fi
  echo "PASS ${name}（${produced} 个文件逐字节一致）"
  pass=$((pass+1))
done

echo
if [ "${fail}" -eq 0 ]; then
  echo "== A/B: ALL PASS（${pass} 个用例，A=${A_DIR} vs B=${B_DIR}）=="
else
  echo "== A/B: FAILED（通过 ${pass} 个）==" >&2
  exit 1
fi
