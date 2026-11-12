#!/usr/bin/env bash
# 从 project.conf 读 URL / SHA / TAG，把上游源码拉进 baseline/（只读参照）。
#
#   ./scripts/fetch-upstream.sh          # 需要人工确认时先 --dry-run
#   ./scripts/fetch-upstream.sh --dry-run
#
# 纪律：只拉 baseline，不动 src/。src/ 的初始内容由人手动复制并提交，
# 这样"哪些文件被改过"在 git diff 里一眼可见。
set -euo pipefail
cd "$(dirname "$0")/.."

dry=0
[ "${1:-}" = "--dry-run" ] && dry=1

conf=project.conf
[ -f "$conf" ] || { echo "错误：缺少 project.conf" >&2; exit 2; }

get() { grep -m1 "^$1=" "$conf" | cut -d= -f2- || true; }
URL=$(get UPSTREAM_URL)
SHA=$(get UPSTREAM_SHA)
TAG=$(get UPSTREAM_TAG)
BASE=$(get BASELINE_DIR); BASE=${BASE:-baseline}

if [ -z "$URL" ]; then
  cat >&2 <<EOF
错误：project.conf 里 UPSTREAM_URL 为空 —— 不允许猜上游地址。

确认后填入，例如：
  UPSTREAM_URL=https://github.com/<org>/<repo>.git
  UPSTREAM_SHA=<40 位 commit sha>
EOF
  exit 3
fi

echo "包        : $(get PKG)"
echo "上游      : $URL"
echo "固定点    : ${SHA:-<未固定>} ${TAG:+($TAG)}"
echo "目标目录  : $BASE"

if [ "$dry" -eq 1 ]; then
  echo "（dry-run，不执行）"
  exit 0
fi

if [ -d "$BASE/.git" ]; then
  echo "== $BASE 已存在，仅校验 HEAD"
  git -C "$BASE" fetch --depth 1 origin "${SHA:-$TAG}" 2>/dev/null || true
else
  # blob:none + no-checkout 只取元数据；确认后再 checkout，避免无谓的大下载。
  git clone --filter=blob:none --no-checkout --depth 1 "$URL" "$BASE"
fi

if [ -n "$SHA" ]; then
  git -C "$BASE" fetch --depth 1 origin "$SHA" 2>/dev/null || true
  git -C "$BASE" checkout -q "$SHA"
else
  echo "警告：未固定 SHA，baseline 会随上游漂移；A/B 结论不可复现" >&2
  git -C "$BASE" checkout -q HEAD
fi

head_sha=$(git -C "$BASE" rev-parse HEAD)
echo "== baseline HEAD: $head_sha"
echo "== 下一步：把 $BASE 的内容复制到 src/ 并提交（一次性、可 review）"
