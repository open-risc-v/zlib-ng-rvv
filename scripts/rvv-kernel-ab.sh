#!/usr/bin/env bash
# zlib-ng G3：RVV（adler32_rvv / chunkset_rvv / compare256_rvv / slide_hash_rvv）
# 对比 A=WITH_RVV=ON 与 B=WITH_RVV=OFF，两侧同 -march=rv64gcv，唯一变量是向量实现。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${IMAGE:-rvv-cross:2}
MARCH=${MARCH:-rv64gcv}
OUT=build/rvv-k

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}; mkdir -p ${OUT}
for side in on off; do
  opt='-DWITH_RVV=ON'
  if [ \$side = off ]; then opt='-DWITH_RVV=OFF'; fi
  cmake -S baseline -B ${OUT}/\$side/bld -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/\$side/prefix \
    -DBUILD_SHARED_LIBS=OFF -DZLIB_COMPAT=ON -DZLIB_ENABLE_TESTS=OFF \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH}' \$opt > ${OUT}/\$side-cfg.log 2>&1 \
      || { tail -20 ${OUT}/\$side-cfg.log; exit 1; }
  cmake --build ${OUT}/\$side/bld -j > ${OUT}/\$side-build.log 2>&1 \
      || { tail -20 ${OUT}/\$side-build.log; exit 1; }
  cmake --install ${OUT}/\$side/bld > /dev/null

  cmake -S . -B ${OUT}/\$side/harness -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH}' -DPKG_PREFIX=/work/${OUT}/\$side/prefix > /dev/null 2>&1
  cmake --build ${OUT}/\$side/harness -j > ${OUT}/\$side-harness.log 2>&1 \
      || { tail -15 ${OUT}/\$side-harness.log; exit 1; }
  qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/\$side/harness/zlib_harness ${OUT}/\$side/comp.bin > ${OUT}/\$side/hash.txt

  riscv64-linux-gnu-gcc -O3 -march=${MARCH} -static -I ${OUT}/\$side/prefix/include \
    test/bench_zlib.c ${OUT}/\$side/prefix/lib/libz.a -o ${OUT}/\$side/bench
done

echo '--- A：WITH_RVV=ON ---'; cat ${OUT}/on/hash.txt
echo '--- B：WITH_RVV=OFF ---'; cat ${OUT}/off/hash.txt
if cmp -s ${OUT}/on/hash.txt ${OUT}/off/hash.txt; then
  echo '== 功能一致：RVV 路径与标量路径逐字节相同'
else
  echo '== 功能不一致'; exit 1
fi
"
