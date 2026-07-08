---
name: jiaoquaner
description: 当用户想降低某段文字/文章/文档的 AI 率、去 AI 化、去 AI 味、降 AI 痕迹，抱怨文本「AI 味太重 / 被判定为 AI 生成 / 过不了 AI 检测」，或想让文本更像人写、更自然时使用；也用于调用焦圈儿（jiaoquaner）平台的其它 AI 接口能力，或用户提到「焦圈儿」「jiaoquaner」、api-server.jiaoquaner.com 时。这是焦圈儿平台各 AI 能力的统一入口。
argument-hint: [想用焦圈儿做什么 / 待处理文本或文件]
---

# 焦圈儿（jiaoquaner）平台入口

焦圈儿平台各 API 能力的**统一入口**。所有子能力共享同一套域名、鉴权、计费规则与错误码——先在这里建立公共上下文，再交给对应子 skill 完成具体请求。

**用户请求**: $ARGUMENTS

## 能力路由

先判断意图，再进入对应子 skill：

| 用户意图 | 子 skill | 接口 |
|----------|----------|------|
| 降 AI 率 / 去 AI 化 / 让文本更像人写 | **jiaoquaner:humanize** | `POST /api/v1/agent/reduce-ai-rate` |

**REQUIRED SUB-SKILL:** 确定意图后，用对应子 skill（如 `jiaoquaner:humanize`）构造并发送请求。本层只负责公共上下文（鉴权 / 计费 / 错误码），子 skill 只写该接口特有的请求体与响应。

匹配不到能力时，如实告诉用户焦圈儿平台暂无对应接口，不要臆造 endpoint。

## 公共配置（所有子能力通用）

- **域名**：`https://api-server.jiaoquaner.com`
- **认证**：请求头 `Authorization: Bearer <API_KEY>`
- **传输**：系统自带 `curl`，`jq` 安全构造/解析 JSON，不依赖 Python 等运行时

### API Key（优先环境变量）

```bash
API_KEY="${JIAOQUANER_API_KEY:-$jiaoquaner_api_key}"
```

为空时**不要中断**，转达二选一让用户配置后再继续：

1. `export JIAOQUANER_API_KEY=sk-xxxxxx`（推荐、可复用，需在启动会话前 export）
2. 直接把明文 key（形如 `sk-xxxxxx`）贴给你，本次运行用 `JIAOQUANER_API_KEY=sk-xxxxxx` 临时赋值

key 在焦圈儿 Web 端「API keys」页面创建，仅返回一次。**绝不要把 key 写进任何文件或提交到 git。**

## 计费纪律（强制）

- 每次调用都按 API Key 所属用户的**焦耳余额真实扣费**，失败不扣费。
- **不要为「测试」空跑，不要私自加重试循环反复扣费。**
- 接口均同步、单次返回，无批量/并发；确需逐条处理多段文本时先告知用户「会多次扣费」。

## 通用错误码

`code == 0` 为成功，取 `data` 中的业务字段展示。`code != 0` 按下表处理：

| code | 含义 | 建议 |
|------|------|------|
| 10401 | 输入含违规内容 | 让用户修改原文后重试 |
| 10706 | 焦耳余额不足 | 让用户充值/检查余额 |
| 11501 | API Key 无效 | 检查 key 是否正确、是否携带 |
| 11502 | API Key 已禁用 | 换可用 key |
| 11503 | API Key 已过期 | 换 key |
| 500 | 服务内部错误（不扣费） | 稍后重试；持续失败反馈后端 |

子 skill 若有能力特有的 code / `data` 字段，在其自身文档中补充，本表为平台通用兜底。

## 接入新能力

焦圈儿新增接口时：在「能力路由」表加一行意图→子 skill 映射，在本 plugin 的 `skills/` 下新建对应子 skill 目录（如 `skills/xxx/SKILL.md`），只写该接口特有的请求体 / 响应 / 专属错误码，公共部分继续复用本入口，避免重复。
