#!/usr/bin/env bash
# 发布一个新版本：同步版本号 -> 提交 -> 打 tag -> 推送 -> （可选）建 GitHub Release。
#
#   ./scripts/release.sh 0.2.0
#   ./scripts/release.sh 0.2.0 --dry-run     只改文件，不提交/不推送
#   ./scripts/release.sh 0.2.0 --notes "修复 xxx"
#
# 用户侧的所有安装方式都直接从本仓库默认分支拉取，因此推送 main 即完成发布；
# tag 与 Release 用于留下可读的变更记录和可回滚的版本点。
set -euo pipefail

cd "$(dirname "$0")/.."

BRANCH="main"
NEW_VERSION=""
NOTES=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --notes)   NOTES="${2:-}"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*)
      echo "error: 未知参数: $1" >&2; exit 1 ;;
    *)
      if [[ -n "$NEW_VERSION" ]]; then
        echo "error: 多余的参数: $1" >&2; exit 1
      fi
      NEW_VERSION="$1"; shift ;;
  esac
done

if [[ -z "$NEW_VERSION" ]]; then
  echo "用法: ./scripts/release.sh <版本号> [--notes <说明>] [--dry-run]" >&2
  exit 1
fi

TAG="v${NEW_VERSION}"

# --- 前置检查 --------------------------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: 工作区不干净，请先提交或暂存改动。" >&2
  git status --short >&2
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  echo "error: 当前在 '$CURRENT_BRANCH' 分支，发布需在 '$BRANCH' 上进行。" >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "error: tag ${TAG} 已存在。" >&2
  exit 1
fi

CURRENT_VERSION="$(cat VERSION)"
echo "当前版本: ${CURRENT_VERSION}  ->  新版本: ${NEW_VERSION}"
echo

# --- 同步版本号 ------------------------------------------------------------

python3 scripts/version.py set "$NEW_VERSION"
echo
./scripts/check-version.sh
echo

if [[ $DRY_RUN -eq 1 ]]; then
  echo "--dry-run: 文件已改好，未提交。用 'git diff' 查看，'git checkout -- .' 回滚。"
  exit 0
fi

# --- 提交 / 打 tag / 推送 ---------------------------------------------------

git add -A
git commit -m "chore(release): ${TAG}"
git tag -a "$TAG" -m "$TAG"

git push origin "$BRANCH"
git push origin "$TAG"

echo
echo "已推送 ${BRANCH} 与 ${TAG}。"

# --- GitHub Release（可选，需要 gh）----------------------------------------

if command -v gh >/dev/null 2>&1; then
  if [[ -n "$NOTES" ]]; then
    gh release create "$TAG" --title "$TAG" --notes "$NOTES"
  else
    gh release create "$TAG" --title "$TAG" --generate-notes
  fi
  echo "已创建 GitHub Release ${TAG}。"
else
  echo "未检测到 gh CLI，跳过 GitHub Release；可稍后手动执行："
  echo "  gh release create ${TAG} --title ${TAG} --generate-notes"
fi

echo
echo "发布完成。用户侧更新方式："
echo "  Claude Code : /plugin marketplace update jiaoquaner"
echo "  Gemini CLI  : gemini extensions update jiaoquaner"
echo "  opencode / Pi / Kimi: 重新执行各自的 install 命令"
