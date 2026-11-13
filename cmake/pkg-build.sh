#!/usr/bin/env bash
# zlib-ng：上游自己就是 CMake，直接用 CMake 构建并安装到 <OUT>/prefix。
set -euo pipefail
SRC=$1
OUT=$2
rm -rf "${OUT}"
cmake -S "${SRC}" -B "${OUT}/bld" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${OUT}/prefix" \
  -DBUILD_SHARED_LIBS=OFF -DZLIB_COMPAT=ON -DZLIB_ENABLE_TESTS=OFF >/dev/null
cmake --build "${OUT}/bld" -j >/dev/null
cmake --install "${OUT}/bld" >/dev/null
echo "== 上游 zlib-ng 构建完成：${OUT}/prefix"
