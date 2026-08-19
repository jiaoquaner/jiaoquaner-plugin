#!/bin/sh
# 焦圈儿「降 AI 率」接口的一次性调用脚本。
#
#   POST https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate
#
# 设计目标：让 AI（或人）用一条命令完成「构造 JSON → 发请求 → 解析响应」，
# 不必自己拼 JSON、猜字段名。成功时 stdout 只有改写后的正文，可直接管道/重定向。
#
# 用法：
#   reduce_ai_rate.sh -f draft.md              # 从文件读原文
#   reduce_ai_rate.sh -t "这是一段原文"          # 直接传文本
#   cat draft.md | reduce_ai_rate.sh           # 从 stdin 读原文
#   reduce_ai_rate.sh -f draft.md -o out.md    # 同时把正文写入文件
#   reduce_ai_rate.sh -f draft.md --json       # stdout 输出完整响应 JSON
#
# 输出约定：
#   stdout  成功时 = 改写后的完整正文（--json 时为完整响应 JSON）
#   stderr  content_id / content_chat_id 等元信息，以及错误说明
#   退出码  0 成功 | 2 接口业务错误(code!=0) | 3 网络/HTTP 失败
#           4 用法错误（缺 key、空输入等） | 5 环境缺依赖（无 curl，且无 jq 与 python3）
#
# 计费：每次成功调用都真实扣除焦耳，失败不扣费。脚本**不做任何自动重试**。
set -u

API_BASE="${JIAOQUANER_API_BASE:-https://api-server.jiaoquaner.com}"
API_URL="${API_BASE%/}/api/v1/agent/reduce-ai-rate"

die() { printf 'error: %s\n' "$1" >&2; exit "${2:-4}"; }

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
}

INPUT_FILE=""
INPUT_TEXT=""
HAVE_TEXT=0
OUT_FILE=""
RAW_JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--file)   INPUT_FILE="${2:-}"; shift 2 || die "-f 需要文件路径" ;;
    -t|--text)   INPUT_TEXT="${2:-}"; HAVE_TEXT=1; shift 2 || die "-t 需要文本" ;;
    -o|--out)    OUT_FILE="${2:-}";   shift 2 || die "-o 需要输出文件路径" ;;
    --json)      RAW_JSON=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          die "未知参数: $1" ;;
    *)           # 位置参数当作原文（或文件路径）
                 if [ "$HAVE_TEXT" = 0 ] && [ -z "$INPUT_FILE" ]; then
                   if [ -f "$1" ]; then INPUT_FILE="$1"; else INPUT_TEXT="$1"; HAVE_TEXT=1; fi
                 else
                   die "多余参数: $1"
                 fi
                 shift ;;
  esac
done

command -v curl >/dev/null 2>&1 || die "环境里没有 curl，无法发请求" 5

# ---- 1. API Key ------------------------------------------------------------
API_KEY="${JIAOQUANER_API_KEY:-${jiaoquaner_api_key:-}}"
[ -n "$API_KEY" ] || die "未配置 API Key：请 export JIAOQUANER_API_KEY=sk-xxxxxx，或本次运行前置 JIAOQUANER_API_KEY=sk-xxxxxx 临时赋值"

# ---- 2. 读入原文（保留末尾换行与全部空白）-----------------------------------
# 末尾补一个哨兵 x，再在调用处剥掉：命令替换会吞掉结尾换行，靠哨兵保住它
read_all() { cat -- "$1"; printf 'x'; }

if [ -n "$INPUT_FILE" ]; then
  [ -f "$INPUT_FILE" ] || die "文件不存在: $INPUT_FILE"
  INPUT="$(read_all "$INPUT_FILE")"; INPUT="${INPUT%x}"
elif [ "$HAVE_TEXT" = 1 ]; then
  INPUT="$INPUT_TEXT"
elif [ ! -t 0 ]; then
  INPUT="$(read_all /dev/stdin)"; INPUT="${INPUT%x}"
else
  usage >&2; die "没有拿到待处理文本：用 -f 文件、-t 文本 或 stdin 传入"
fi

case "$INPUT" in
  *[![:space:]]*) : ;;
  *) die "input 为空：接口要求 input 必填、不可为空" ;;
esac

# ---- 3. 选一个 JSON 工具（jq 优先，python3 兜底）----------------------------
JSON_TOOL=""
if command -v jq >/dev/null 2>&1; then
  JSON_TOOL="jq"
elif command -v python3 >/dev/null 2>&1; then
  JSON_TOOL="python3"
else
  die "缺少 JSON 工具：需要 jq 或 python3 之一（用于安全转义/解析，绝不能手拼 JSON）" 5
fi

TMPDIR_JQ="$(mktemp -d "${TMPDIR:-/tmp}/jqr.XXXXXX")" || die "无法创建临时目录"
trap 'rm -rf "$TMPDIR_JQ"' EXIT
REQ="$TMPDIR_JQ/request.json"
RESP="$TMPDIR_JQ/response.json"

if [ "$JSON_TOOL" = "jq" ]; then
  printf '%s' "$INPUT" | jq -Rs '{input: .}' > "$REQ" || die "构造请求体失败"
else
  printf '%s' "$INPUT" | python3 -c 'import json,sys; sys.stdout.write(json.dumps({"input": sys.stdin.read()}, ensure_ascii=False))' > "$REQ" || die "构造请求体失败"
fi

# ---- 4. 发请求（不重试；key 不回显）----------------------------------------
HTTP_CODE="$(curl -sS -X POST "$API_URL" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  --data-binary @"$REQ" \
  -o "$RESP" -w '%{http_code}' 2>"$TMPDIR_JQ/curl.err")"
CURL_RC=$?

if [ $CURL_RC -ne 0 ]; then
  sed 's/Bearer [^ ]*/Bearer ***/g' "$TMPDIR_JQ/curl.err" >&2
  die "请求失败（curl 退出码 $CURL_RC），未扣费，可稍后手动重试" 3
fi

# ---- 5. 解析响应 -----------------------------------------------------------
if [ "$JSON_TOOL" = "jq" ]; then
  CODE="$(jq -r '.code // empty' "$RESP" 2>/dev/null)"
  MSG="$(jq -r '.msg // .message // empty' "$RESP" 2>/dev/null)"
  OUTPUT="$(jq -r '.data.output // empty' "$RESP" 2>/dev/null)"
  CONTENT_ID="$(jq -r '.data.content_id // empty' "$RESP" 2>/dev/null)"
  CHAT_ID="$(jq -r '.data.content_chat_id // empty' "$RESP" 2>/dev/null)"
else
  eval "$(python3 - "$RESP" <<'PY'
import json, shlex, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    d = {}
data = d.get("data") or {}
def q(name, value):
    print("%s=%s" % (name, shlex.quote("" if value is None else str(value))))
q("CODE", d.get("code", ""))
q("MSG", d.get("msg", d.get("message", "")))
q("OUTPUT", data.get("output", ""))
q("CONTENT_ID", data.get("content_id", ""))
q("CHAT_ID", data.get("content_chat_id", ""))
PY
)"
fi

if [ -z "${CODE:-}" ]; then
  printf 'error: 响应不是预期的 JSON（HTTP %s），原始响应：\n' "$HTTP_CODE" >&2
  head -c 2000 "$RESP" >&2; printf '\n' >&2
  exit 3
fi

if [ "$CODE" != "0" ]; then
  case "$CODE" in
    10401) HINT="输入含违规内容：修改原文后再试（未扣费）" ;;
    10706) HINT="焦耳余额不足：请充值或检查余额（未扣费）" ;;
    11501) HINT="API Key 无效：检查 JIAOQUANER_API_KEY 是否正确、是否携带" ;;
    11502) HINT="API Key 已禁用：更换可用 key" ;;
    11503) HINT="API Key 已过期：更换 key" ;;
    500)   HINT="服务内部错误（不扣费）：稍后重试；持续失败请反馈后端" ;;
    *)     HINT="未知错误码，把 code 与 msg 反馈给焦圈儿" ;;
  esac
  printf 'error: 接口返回 code=%s msg=%s\nhint: %s\n' "$CODE" "${MSG:-}" "$HINT" >&2
  exit 2
fi

[ -n "${OUTPUT:-}" ] || { printf 'error: code=0 但 data.output 为空，原始响应：\n' >&2; head -c 2000 "$RESP" >&2; printf '\n' >&2; exit 2; }

[ -n "${CONTENT_ID:-}" ] && printf 'content_id=%s\n' "$CONTENT_ID" >&2
[ -n "${CHAT_ID:-}" ]    && printf 'content_chat_id=%s\n' "$CHAT_ID" >&2

if [ -n "$OUT_FILE" ]; then
  printf '%s\n' "$OUTPUT" > "$OUT_FILE" || die "写入 $OUT_FILE 失败"
  printf 'saved=%s\n' "$OUT_FILE" >&2
fi

if [ "$RAW_JSON" = "1" ]; then
  cat "$RESP"
  printf '\n'
else
  printf '%s\n' "$OUTPUT"
fi
