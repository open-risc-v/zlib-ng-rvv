#!/usr/bin/env bash
# 真实包用例：zlib-ng 的 deflate/inflate 回环 + 压缩字节哈希。
set -euo pipefail
: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"
case "$STAGE" in
  gen) ;;
  run)
    [ -x "$BIN/zlib_harness" ] || { echo "缺少 $BIN/zlib_harness" >&2; exit 1; }
    "$BIN/zlib_harness" "$OUT/comp.bin" > "$OUT/hash.txt"
    size=$(wc -c < "$OUT/comp.bin" | tr -d ' ')
    [ "$size" -gt 1000 ] || { echo "压缩产物过小：$size" >&2; exit 1; }
    ;;
  *) echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
