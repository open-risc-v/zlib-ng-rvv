#!/usr/bin/env bash
# paired 基准：同一用例 A/B 交替跑 REPS 次，取中位数。
# 分母必须是 B（同一 -march、内核关闭），不是标量 C，也不是不同 -O。
#
#   ./benchmark/pair_bench.sh                       # 本机
#   RVV_A=/tmp/x/a RVV_B=/tmp/x/b REPS=5 sh benchmark/pair_bench.sh   # 板子上
#
# 用例约定（benchmark/cases/*.sh）：
#   收到 SIDE=BIN 与 BIN，向 stdout 打印**一个数字**（毫秒）。
#   用例自己负责预热与固定输入，不打印其他内容。
set -euo pipefail
cd "$(dirname "$0")/.."

REPS=${REPS:-5}
BUILD_A=${BUILD_A:-build/riscv64}
BUILD_B=${BUILD_B:-build/riscv64-b}
if [ -n "${RVV_A:-}" ]; then BUILD_A=$RVV_A; fi
if [ -n "${RVV_B:-}" ]; then BUILD_B=$RVV_B; fi
RUNNER=${RUNNER:-}

shopt -s nullglob
cases=(benchmark/cases/*.sh)
[ ${#cases[@]} -gt 0 ] || { echo "没有 benchmark/cases/*.sh" >&2; exit 2; }

median() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{
  if (NR%2) print a[(NR+1)/2]; else printf "%.3f\n", (a[NR/2]+a[NR/2+1])/2 }'; }

printf '%-28s %10s %10s %8s\n' "case" "A(ms)" "B(ms)" "ratio"
for c in "${cases[@]}"; do
  name=$(basename "$c" .sh)
  a=(); b=()
  for i in $(seq 1 "$REPS"); do
    a+=("$(SIDE=A BIN="$BUILD_A" $RUNNER sh "$c" | tail -1)")
    b+=("$(SIDE=B BIN="$BUILD_B" $RUNNER sh "$c" | tail -1)")
  done
  ma=$(median "${a[@]}"); mb=$(median "${b[@]}")
  ratio=$(awk -v x="$mb" -v y="$ma" 'BEGIN{ if (y>0) printf "%.3f", x/y; else print "n/a" }')
  printf '%-28s %10s %10s %8s\n' "$name" "$ma" "$mb" "$ratio"
done
echo
echo "ratio>1 表示 A（RVV 内核）更快；同一用例需在同一会话、同一频率状态下测。"
