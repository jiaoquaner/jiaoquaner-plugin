---
name: humanize
description: 调用焦圈儿（jiaoquaner）/api/v1/agent/reduce-ai-rate 接口对文本进行「降 AI 率」改写，返回改写后的完整文本。当用户想降低某段文字/文章/文档的 AI 味、去 AI 化、降 AI 率、让文本更像人写的，或直接要求调用降 AI 率接口时使用。支持直接传文本或传文件路径，用 curl 发请求、无需任何运行时依赖。此为焦圈儿平台能力，公共上下文见 jiaoquaner:jiaoquaner。
argument-hint: [待降AI率的文本或文件路径]
---

对传入文本调用焦圈儿「降 AI 率」接口，拿回改写后的完整文本。全程用系统自带的 `curl` 发 HTTP 请求，不依赖 Python 等运行时，方便直接给用户使用。

**用户请求**: $ARGUMENTS

## 接口信息

- 请求：`POST https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate`
- 认证：请求头 `Authorization: Bearer <API_KEY>`
- 请求体：`{"input": "待降AI率的原文"}`，`input` 必填、不可为空
- 成功响应：`{"code":0,"data":{"output":"改写后文本","content_id":"...","content_chat_id":"..."}}`
- 计费：按 API Key 所属用户的焦耳余额扣费，改写失败不扣费。**每次调用都是真实消费，不要为「测试」空跑或私自重试。**

## 步骤一：拿到 API Key（优先环境变量）

按顺序解析，找到即用：

```bash
API_KEY="${JIAOQUANER_API_KEY:-$jiaoquaner_api_key}"
```

如果为空，说明用户没配置。**不要中断，转达以下二选一让用户配置**，拿到后再继续：

1. 设置环境变量（推荐、可复用）：`export JIAOQUANER_API_KEY=sk-xxxxxx`
   —— 注意需在启动当前会话前 export，或让用户把 key 直接贴给你，本次运行用 `JIAOQUANER_API_KEY=sk-xxxxxx` 临时赋值。
2. 直接把明文 key（形如 `sk-xxxxxx`）贴给你，本次运行用上。

key 的获取方式：在焦圈儿 Web 端「API keys」页面创建，仅返回一次。
**绝不要把用户的 key 写进任何文件或提交到 git。**

## 步骤二：发请求

`input` 里的文本常含引号、换行、中文，绝不能手拼进 JSON 字符串——用 `jq` 安全构造请求体、解析响应。

**文本较短、直接给的：**

```bash
curl -sS -X POST "https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n --arg input "待降AI率的原文……" '{input:$input}')"
```

**从文件读入（长文推荐，避免命令行过长）：**

```bash
curl -sS -X POST "https://api-server.jiaoquaner.com/api/v1/agent/reduce-ai-rate" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  --data "$(jq -n --arg input "$(cat /path/to/draft.txt)" '{input:$input}')"
```

把响应存进变量再解析，便于区分成功/失败：

```bash
RESP="$(curl -sS ... )"          # 同上
echo "$RESP" | jq -r '.data.output // empty'   # 成功时取正文
echo "$RESP" | jq -r '.code, .msg'             # 出错时看 code 和 msg
```

### 没有 jq 时的降级

`jq` 是常见工具，但并非必装。若 `command -v jq` 为空：
- **构造请求体**：自己把待处理文本读进来，生成一个转义正确的 JSON 文件（对 `"` `\` 换行等做 JSON 转义），写到临时目录如 `request.json`，再 `curl ... --data @request.json`。
- **解析响应**：`-o response.json` 保存后，直接读文件判断 `code` 是否为 0、取 `data.output`。
不要因为没有 jq 就手拼 JSON 字符串，转义出错会导致 10401 之类的误报或请求失败。

## 步骤三：回传结果与错误处理

`code == 0` → 把 `data.output` 完整展示给用户即可；需要落库 ID 时一并给出 `content_id` / `content_chat_id`。

`code != 0` → 按下表向用户解释并给下一步建议：

| code | 含义 | 建议 |
|------|------|------|
| 10401 | 输入含违规内容 | 让用户修改原文后重试 |
| 10706 | 焦耳余额不足 | 让用户充值/检查余额 |
| 11501 | API Key 无效 | 检查 key 是否正确、是否携带 |
| 11502 | API Key 已禁用 | 换可用 key |
| 11503 | API Key 已过期 | 换 key |
| 500 | 服务内部错误（不扣费） | 稍后重试；持续失败反馈后端 |

## 边界

- 接口全程同步、单次返回，不做人工率检测 / 自动重试 / 焦耳返还——不要自行加重试循环反复扣费。
- 只接受 `input` 一个业务参数，没有分段/批量/并发能力。确需批量处理多段文本时逐条调用，并提前告知用户这会多次扣费。
