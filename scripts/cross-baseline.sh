#!/usr/bin/env bash
# 交叉编译基线版本：在 rvv-cross 容器里把 baseline（上游原样）编成 riscv64，
# 探针用 qemu-user 跑，输出与 native 基线逐字段比对。
#
#   ./scripts/cross-baseline.sh                # 默认 -march=rv64gc（无向量，纯基线）
#   MARCH=rv64gcv ./scripts/cross-baseline.sh  # 上游若自带 RVV 代码，用它看向量路径
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${IMAGE:-rvv-cross:1}
MARCH=${MARCH:-rv64gc}
OUT=build/riscv64-b

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}
cmake -S baseline -B ${OUT}/bld \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/prefix \
  -DBUILD_SHARED_LIBS=OFF -DZLIB_COMPAT=ON -DZLIB_ENABLE_TESTS=OFF \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' > /tmp/cfg.log 2>&1 || { tail -30 /tmp/cfg.log; exit 1; }
cmake --build ${OUT}/bld -j > /tmp/bld.log 2>&1 || { tail -20 /tmp/bld.log; exit 1; }
cmake --install ${OUT}/bld > /dev/null

cmake -S . -B ${OUT}/harness -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' \
  -DPKG_PREFIX=/work/${OUT}/prefix > /tmp/h.log 2>&1 || { tail -30 /tmp/h.log; exit 1; }
cmake --build ${OUT}/harness -j > /tmp/hb.log 2>&1 || { tail -20 /tmp/hb.log; exit 1; }

mkdir -p ${OUT}/out
qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/harness/zlib_harness ${OUT}/out/comp.bin > ${OUT}/out/hash.txt
echo \"--- riscv64（${MARCH}）---\"
cat ${OUT}/out/hash.txt
echo \"--- native 基线 ---\"
cat build/ab-data/out/01_zlib_roundtrip/a/hash.txt
"
