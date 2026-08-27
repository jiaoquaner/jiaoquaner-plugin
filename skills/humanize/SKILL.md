---
name: humanize
description: 一键过朱雀 AI 检测的降 AI 率工具，公众号、小红书、头条号、知乎、百家号通用。调用焦圈儿（jiaoquaner）/api/v1/agent/reduce-ai-rate 接口对文本进行「降 AI 率」改写，返回改写后的完整文本。当用户想降低某段文字/文章/文档的 AI 味、去 AI 化、降 AI 率、让文本更像人写的，或直接要求调用降 AI 率接口时使用。支持直接传文本或传文件路径；本 skill 自带可执行脚本 scripts/reduce_ai_rate.sh（macOS/Linux/WSL/Git Bash）与 scripts/reduce_ai_rate.ps1（Windows PowerShell），一条命令完成建请求/发请求/解析响应。此为焦圈儿平台能力，公共上下文见 jiaoquaner:jiaoquaner。
argument-hint: [待降AI率的文本或文件路径]
---

对传入文本调用焦圈儿「降 AI 率」接口，拿回改写后的完整文本。

**用户请求**: $ARGUMENTS

## 首选：直接用本 skill 自带的脚本

**不要自己拼 JSON、自己写 curl、自己猜响应字段名**——本 skill 目录下的 `scripts/reduce_ai_rate.sh` 已经把「安全转义原文 → 发请求 → 判 code → 取正文 → 翻译错误码」全部做完了。手写这套最常见的翻车点是引号/换行/中文没转义、把 `data.output` 写成 `output`、把 HTTP 200 当成业务成功。

### 步骤 0：按当前 shell 选版本

本 skill 的 `scripts/` 下有两个契约完全一致的实现，**按你实际能执行的 shell 选一个**：

| 你的执行环境 | 用哪个 | 依赖 |
|--------------|--------|------|
| macOS / Linux / WSL / Git Bash（有 `sh` 或 `bash`） | `reduce_ai_rate.sh` | `curl` + (`jq` 或 `python3`)，二者有其一即可 |
| Windows 原生 PowerShell / cmd（没有 bash） | `reduce_ai_rate.ps1` | 仅需 PowerShell 5.1+（Windows 自带），无外部依赖 |

两者的参数、stdout/stderr 约定、退出码完全相同，下面的说明通用。

### 步骤 1：定位脚本（一次即可，把路径记在变量里）

**脚本就在你正在读的这份 SKILL.md 旁边**：`<本文件所在目录>/scripts/reduce_ai_rate.sh`。
你知道自己是从哪个路径加载的这份 skill，**直接把那个目录填进下面的 `SKILL_DIR` 即可**，这是最快也最准的方式（多个客户端/多个版本共存时，也能保证用的是当前这份）。

sh 环境：

```bash
SKILL_DIR="<把这里换成本 SKILL.md 所在目录，如 .../skills/humanize>"
SCRIPT="$SKILL_DIR/scripts/reduce_ai_rate.sh"
# 兜底 1：Claude Code 会注入 CLAUDE_PLUGIN_ROOT，其它客户端没有则自动跳过
[ -f "$SCRIPT" ] || SCRIPT="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/humanize/scripts/reduce_ai_rate.sh}"
# 兜底 2：限定深度的搜索，别全盘扫 home
[ -f "${SCRIPT:-}" ] || SCRIPT="$(find ~/.claude ~/.config ~/.cursor ~/.codex ~/.gemini ~/.kimi ~/.pi . \
  -maxdepth 8 -path '*humanize/scripts/reduce_ai_rate.sh' 2>/dev/null | head -1)"
echo "${SCRIPT:-NOT_FOUND}"
```

PowerShell 环境（注意 Windows 的 `find` 是文本搜索命令，不能用来找文件）：

```powershell
$s = Join-Path '<把这里换成本 SKILL.md 所在目录>' 'scripts\reduce_ai_rate.ps1'
if (-not (Test-Path $s) -and $env:CLAUDE_PLUGIN_ROOT) {
  $s = Join-Path $env:CLAUDE_PLUGIN_ROOT 'skills\humanize\scripts\reduce_ai_rate.ps1'
}
if (-not (Test-Path $s)) {
  $roots = @("$env:USERPROFILE\.claude", "$env:USERPROFILE\.codex", "$env:USERPROFILE\.cursor",
             "$env:USERPROFILE\.gemini", "$env:USERPROFILE\.kimi", "$env:USERPROFILE\.pi", '.') |
           Where-Object { Test-Path $_ }
  $s = Get-ChildItem -Path $roots -Recurse -Depth 8 -Filter reduce_ai_rate.ps1 -ErrorAction SilentlyContinue |
       Select-Object -First 1 -ExpandProperty FullName
}
if ($s -and (Test-Path $s)) { $s } else { 'NOT_FOUND' }
```

三条都落空（`NOT_FOUND`）时，走文末的「兜底：手写 curl」——有些客户端可能只加载了 SKILL.md 正文而没有落地 `scripts/` 目录。

### 步骤 2：确认 API Key

key 从环境变量读，`JIAOQUANER_API_KEY` 优先、`jiaoquaner_api_key` 兜底。脚本自己会检查并在缺失时报错退出（退出码 4），所以**不必**提前探测；若想先确认：

```bash
[ -n "${JIAOQUANER_API_KEY:-${jiaoquaner_api_key:-}}" ] && echo "key ok" || echo "key missing"
```

`key missing` 时**不要中断**，转达以下二选一让用户配置，拿到后再继续：

1. 设置环境变量（推荐、可复用）：`export JIAOQUANER_API_KEY=sk-xxxxxx` —— 需在启动当前会话前 export。
2. 直接把明文 key（形如 `sk-xxxxxx`）贴给你，本次运行前置临时赋值：`JIAOQUANER_API_KEY=sk-xxxxxx bash "$SCRIPT" ...`

key 在焦圈儿 Web 端「API keys」页面创建，仅返回一次。
**绝不要把用户的 key 写进任何文件（含 `.env`、shell rc）或提交到 git，也不要 echo 出来。**

### 步骤 3：调用

sh 环境（脚本是 POSIX `sh`，用 `sh`/`bash`/`dash`/`zsh` 跑都可以）：

```bash
sh "$SCRIPT" -f /path/to/draft.md          # 从文件读原文（长文首选）
sh "$SCRIPT" -t "这是一段待降 AI 率的原文"    # 直接传文本（短文本）
cat draft.md | sh "$SCRIPT"                # 从 stdin 读
sh "$SCRIPT" -f draft.md -o result.md      # 顺带把正文写进文件
sh "$SCRIPT" -f draft.md --json            # stdout 给完整响应 JSON
sh "$SCRIPT" --help                        # 完整用法
```

PowerShell 环境（参数名用长名：`-File` / `-Text` / `-Out` / `-Json` / `-Help`）：

```powershell
& $s -File C:\path\to\draft.md
& $s -Text "这是一段待降 AI 率的原文"
Get-Content draft.md -Raw | & $s
& $s -File draft.md -Out result.md
# 若被执行策略拦下：powershell -ExecutionPolicy Bypass -File $s -File draft.md
```

原文里的引号、换行、制表符、中文、emoji、反斜杠都由脚本安全转义，**原样送达、不丢末尾换行**，你不需要做任何预处理或转义。长文（比如几千字以上）优先用 `-f` + `-o`，别把全文塞进命令行。

### 步骤 4：读结果

脚本的输出约定是固定的，按这个来解析，不要另行猜测：

- **stdout** = 改写后的完整正文（`--json` 时为完整响应 JSON）。可以直接管道、重定向、原样转述给用户。
- **stderr** = `content_id=` / `content_chat_id=` 等元信息与错误说明。**不要把 stderr 混进正文**（别用 `2>&1` 后整体当结果）。
- **退出码**：

  | 退出码 | 含义 | 你该做什么 |
  |--------|------|-----------|
  | 0 | 成功 | 把 stdout 完整展示给用户；需要时附上 stderr 里的 content_id |
  | 2 | 接口业务错误（`code != 0`） | 按 stderr 里的 `hint` 转达用户，见下表 |
  | 3 | 网络/HTTP 失败或响应非预期 JSON（未扣费） | 如实告知，可让用户稍后手动重试 |
  | 4 | 用法错误（缺 key、输入为空、文件不存在） | 按提示补齐后再调 |
  | 5 | 环境缺依赖（sh 版：没有 curl，或 jq 与 python3 都没有） | 让用户装其一，或改用兜底 curl |

`code != 0` 时脚本已经打印了中文 hint，对应关系：

| code | 含义 | 建议 |
|------|------|------|
| 10401 | 输入含违规内容 | 让用户修改原文后重试 |
| 10706 | 焦耳余额不足 | 让用户充值/检查余额 |
| 11501 | API Key 无效 | 检查 key 是否正确、是否携带 |
| 11502 | API Key 已禁用 | 换可用 key |
| 11503 | API Key 已过期 | 换 key |
| 500 | 服务内部错误（不扣费） | 稍后重试；持续失败反馈后端 |

## 接口信息（供排查用）

- 请求：`POST https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate`
- 认证：请求头 `Authorization: Bearer ${JIAOQUANER_API_KEY}`
- 请求体：`{"input": "待降AI率的原文"}`，`input` 必填、不可为空，只接受这一个业务参数
- 成功响应：`{"code":0,"data":{"output":"改写后文本","content_id":"...","content_chat_id":"..."}}`
- HTTP 200 不代表成功，**一切以 `code == 0` 为准**
- 脚本支持用 `JIAOQUANER_API_BASE` 覆盖域名，仅用于本地 mock 自测，正常调用不要设置

## 兜底：手写 curl（仅当脚本找不到时）

用 `jq` 安全构造请求体与解析响应，绝不手拼 JSON 字符串：

```bash
RESP="$(curl -sS -X POST "https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate" \
  -H "Authorization: Bearer ${JIAOQUANER_API_KEY:-$jiaoquaner_api_key}" \
  -H "Content-Type: application/json" \
  --data "$(jq -Rs '{input: .}' < /path/to/draft.md)")"
echo "$RESP" | jq -r 'if .code == 0 then .data.output else "ERR code=\(.code) msg=\(.msg // "")" end'
```

没有 `jq` 时用 `python3` 生成 `request.json` 再 `curl --data @request.json`，并保存响应到文件解析——**不要因为没有 jq 就手拼 JSON 字符串**，转义出错会导致 10401 之类的误报或请求失败。

PowerShell 环境用内置的 `ConvertTo-Json` 做转义（同样不要手拼字符串）：

```powershell
$body = @{ input = (Get-Content draft.md -Raw) } | ConvertTo-Json -Compress
$r = Invoke-RestMethod -Uri "https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate" -Method Post `
  -Headers @{ Authorization = "Bearer $env:JIAOQUANER_API_KEY" } `
  -ContentType 'application/json; charset=utf-8' `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
if ($r.code -eq 0) { $r.data.output } else { "ERR code=$($r.code) msg=$($r.msg)" }
```

## 边界与计费纪律

- 每次成功调用都按 API Key 所属用户的**焦耳余额真实扣费**，失败不扣费。**不要为「测试」空跑，不要私自加重试循环反复扣费**（脚本本身不做任何自动重试）。
- 接口全程同步、单次返回，不做人工率检测、不自动重试、不返还焦耳。
- 没有分段/批量/并发能力。确需处理多段文本时逐条调用，并**提前告知用户这会多次扣费**。
