#!/usr/bin/env bash
# 构建助手。
#   ./scripts/build.sh                # 本机构建（先验证代码能编）
#   ./scripts/build.sh riscv64        # 交叉构建，开 RVV
#   ./scripts/build.sh riscv64-b      # A/B 的 B 侧（baseline，不打内核宏）
# 额外参数透传给 cmake configure。
set -euo pipefail
cd "$(dirname "$0")/.."

preset=${1:-native}
if [ $# -gt 0 ]; then shift; fi

cmake --preset "$preset" "$@"
cmake --build "build/$preset" -j
