#!/usr/bin/env bash
# zlib-ng adler32 细化：三侧对照
#   off  = baseline + WITH_RVV=OFF（纯 C 参照）
#   old  = baseline + WITH_RVV=ON （上游原内核，e8m1 / u16m2 / u32m4）
#   new  = src      + WITH_RVV=ON （加宽一档，e8m2 / u16m4 / u32m8）
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${IMAGE:-rvv-cross:2}
MARCH=${MARCH:-rv64gcv}
OUT=build/adler-re

docker run --rm -v "$PWD":/work -w /work "$IMAGE" bash -lc "
set -e
rm -rf ${OUT}; mkdir -p ${OUT}
build_one() {
  local src=\$1 side=\$2 opt=\$3
  cmake -S \$src -B ${OUT}/\$side/bld -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/\$side/prefix \
    -DBUILD_SHARED_LIBS=OFF -DZLIB_COMPAT=ON -DZLIB_ENABLE_TESTS=OFF \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH}' \$opt > ${OUT}/\$side-cfg.log 2>&1 \
      || { echo \"CFG-FAIL \$side\"; tail -15 ${OUT}/\$side-cfg.log; return 1; }
  cmake --build ${OUT}/\$side/bld -j > ${OUT}/\$side-build.log 2>&1 \
      || { echo \"BUILD-FAIL \$side\"; tail -15 ${OUT}/\$side-build.log; return 1; }
  cmake --install ${OUT}/\$side/bld > /dev/null

  cmake -S . -B ${OUT}/\$side/h -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH}' -DPKG_PREFIX=/work/${OUT}/\$side/prefix > /dev/null 2>&1
  cmake --build ${OUT}/\$side/h -j > ${OUT}/\$side-h.log 2>&1 \
      || { echo \"HARNESS-FAIL \$side\"; tail -12 ${OUT}/\$side-h.log; return 1; }
  qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/\$side/h/zlib_harness ${OUT}/\$side/c.bin > ${OUT}/\$side.hash 2>&1 \
      || { echo \"RUN-FAIL \$side\"; cat ${OUT}/\$side.hash; return 1; }

  riscv64-linux-gnu-gcc -O3 -march=${MARCH} -static -I ${OUT}/\$side/prefix/include \
    test/bench_zlib.c ${OUT}/\$side/prefix/lib/libz.a -o ${OUT}/\$side/bench
}
build_one baseline off '-DWITH_RVV=OFF'
build_one baseline on  '-DWITH_RVV=ON'
build_one src      new '-DWITH_RVV=ON'
echo '--- hash off ---'; cat ${OUT}/off.hash
echo '--- hash old ---'; cat ${OUT}/on.hash
echo '--- hash new ---'; cat ${OUT}/new.hash
cmp -s ${OUT}/off.hash ${OUT}/on.hash && echo 'off==old OK'
cmp -s ${OUT}/off.hash ${OUT}/new.hash && echo 'off==new OK'
" 2>&1 | tee ${OUT}/summary.txt | tail -8
