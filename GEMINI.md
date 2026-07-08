# 焦圈儿（jiaoquaner）技能

本扩展提供焦圈儿平台的 AI 能力技能，位于 `./skills/`：

- `jiaoquaner` —— 平台统一入口：鉴权 / 计费 / 错误码 / 能力路由
- `humanize` —— 降 AI 率 / 去 AI 化改写（`POST /api/v1/agent/reduce-ai-rate`）

**按需触发**：当用户想降低某段文字 / 文章 / 文档的 AI 率、去 AI 化、去 AI 味、让文本更像人写，或提到「焦圈儿」「jiaoquaner」平台时，读取 `./skills/jiaoquaner/SKILL.md`（或 `./skills/humanize/SKILL.md`）并按其步骤执行。其它情况无需加载。
