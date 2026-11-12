#!/usr/bin/env bash
# 模板用例：测 diff_kernels 的整体耗时（毫秒）。复制改造成真实内核/端到端用例。
# 必须只向 stdout 打印一个数字。
set -euo pipefail
: "${BIN:=build/riscv64}"
bin="$BIN/diff_kernels"
[ -x "$bin" ] || { echo "0"; exit 0; }

start=$(python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
)
"$bin" >/dev/null 2>&1 || true
end=$(python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
)
echo $((end - start))
