# jiaoquaner 焦圈儿平台插件

焦圈儿（jiaoquaner）平台各 AI 接口能力的 Claude Code 技能库。以一个**统一入口**收敛公共鉴权、计费纪律与错误码，再路由到各具体能力子技能。

## 包含的技能

| 技能 | 触发场景 | 接口 |
|------|----------|------|
| `jiaoquaner:jiaoquaner` | 平台统一入口：判断意图、建立公共上下文（鉴权/计费/错误码）后分发 | — |
| `jiaoquaner:humanize` | 降 AI 率 / 去 AI 化 / 让文本更像人写 | `POST /api/v1/agent/reduce-ai-rate` |

## 安装

技能内容（`skills/*/SKILL.md`）跨 CLI 通用，仓库为每个 CLI 各配了一份适配清单，均指向同一份 `./skills/`。技能**按需触发**，不会强制注入每个会话。

### Claude Code

```
/plugin marketplace add jiaoquaner/jiaoquaner-plugin
/plugin install jiaoquaner@jiaoquaner
/reload-plugins
```

本地开发也可直接指向目录：`/plugin marketplace add /path/to/jiaoquaner-plugin`。

### OpenCode

在 `opencode.json` 的 `plugin` 数组加入（详见 [`.opencode/INSTALL.md`](./.opencode/INSTALL.md)）：

```json
{ "plugin": ["jiaoquaner@git+https://github.com/jiaoquaner/jiaoquaner-plugin.git"] }
```

### Kimi Code

支持从 git 仓库直装：

```text
/plugins install https://github.com/jiaoquaner/jiaoquaner-plugin
```

或打开 `/plugins` 插件管理器，从市场里找 `jiaoquaner` 安装。适配文件：`.kimi-plugin/plugin.json`。

### Pi

作为 Pi 包从仓库安装：

```bash
pi install git:github.com/jiaoquaner/jiaoquaner-plugin
```

本地开发，用当前目录作为临时包运行：

```bash
pi -e /path/to/jiaoquaner-plugin
```

适配文件：`.pi/extensions/jiaoquaner.ts`（注册 `skills/`，按需触发，不做每会话注入）。

### Gemini CLI

作为 Gemini 扩展从仓库安装（读取 `gemini-extension.json` + `GEMINI.md`）：

```bash
gemini extensions install https://github.com/jiaoquaner/jiaoquaner-plugin
```

> 具体命令以你所用 Gemini CLI 版本的 `gemini extensions --help` 为准。

### Codex

Codex 的插件走**官方市场** [`openai/plugins`](https://github.com/openai/plugins)，`.codex-plugin/plugin.json` 是为此准备的适配清单。目前 Codex 没有"从任意 git 仓库直装"的文档化命令，要在 Codex 里装本插件，需先把它提交到官方 `openai/plugins` 市场；之后：

```bash
# 在 Codex CLI 里
/plugins          # 打开插件搜索
jiaoquaner        # 搜索
# 选择 Install Plugin
```

（未上架前，Codex 里无法直接安装本仓库。）

### Cursor

Cursor 走**自家插件市场**，`.cursor-plugin/plugin.json` 是适配清单。同样没有自托管 git 直装命令，需先上架 Cursor 市场；之后在 Cursor Agent 对话里：

```text
/add-plugin jiaoquaner
```

（未上架前，Cursor 里无法直接安装本仓库。）

### 其它

`.agents/plugins/marketplace.json` 为通用 agents 市场准备；各适配文件均指向同一份 `./skills/`。

## 配置 API Key

技能优先读环境变量，二选一：

```bash
export JIAOQUANER_API_KEY=sk-xxxxxx   # 推荐、可复用；需在启动会话前 export
```

或本次运行临时赋值 `JIAOQUANER_API_KEY=sk-xxxxxx`。Key 在焦圈儿 Web 端「API keys」页面创建，仅返回一次。**切勿把 key 写进任何文件或提交到 git。**

## 计费说明

- 每次调用按 API Key 所属用户的**焦耳余额真实扣费**，失败不扣费。
- 接口均同步、单次返回，无批量/并发；技能不会私自加重试循环反复扣费。

## 扩展新能力

焦圈儿新增接口时：

1. 在 `skills/` 下新建子技能目录，如 `skills/xxx/SKILL.md`；
2. 子技能只写该接口特有的请求体 / 响应 / 专属错误码；
3. 在入口 `skills/jiaoquaner/SKILL.md` 的「能力路由」表加一行意图 → 子技能映射；
4. 公共鉴权 / 计费 / 错误码继续复用入口，避免重复。

## 许可

[MIT](./LICENSE)
