#!/usr/bin/env bash
# 框架自检用例：两个工具在 A/B 两侧都应给出同一份输出。
# 它的价值是先证明"门禁本身是通的"，再往里加真实包用例。
#
# 模板：复制本文件为 test/cases/<pkg>-<功能>.sh，改成调用上游二进制：
#   STAGE=gen  : 用 $BIN 里的工具生成输入（图片/PCM/视频/文本）
#   STAGE=run  : 用 $BIN 里的工具跑一遍，把**产物**写到 $OUT
# 输出必须是确定性的文件（不要写时间戳、随机数、绝对路径）。
set -euo pipefail

: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"

case "$STAGE" in
  gen)
    # 生成本用例的输入语料（要求确定性：固定种子/固定长度）
    if [ -x "$BIN/diff_kernels" ]; then
      "$BIN/diff_kernels" > "$DATA/kernels-$SIDE.txt"
    else
      : > "$DATA/kernels-$SIDE.txt"
    fi
    ;;
  run)
    # 实际的被测路径。示例：把内核自检的输出当"产物"，两侧应完全一致。
    if [ -x "$BIN/diff_kernels" ]; then
      "$BIN/diff_kernels" > "$OUT/kernels.txt"
    else
      echo "缺少 $BIN/diff_kernels（先跑 scripts/build.sh）" >&2
      exit 1
    fi
    if [ -x "$BIN/cpu_probe" ]; then
      # cpu_probe 含 VLEN 等环境信息，只在同机比较；这里只取向量部分
      "$BIN/cpu_probe" 2>/dev/null | grep -E '^(vlen|march|v_intrinsic)=' > "$OUT/probe.txt" || true
    fi
    ;;
  *)
    echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
