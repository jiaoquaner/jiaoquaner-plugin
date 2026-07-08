# 在 OpenCode 安装焦圈儿（jiaoquaner）

## 前置

- 已安装 [OpenCode.ai](https://opencode.ai)

## 安装

在 `opencode.json`（全局或项目级）的 `plugin` 数组里加入：

```json
{
  "plugin": ["jiaoquaner@git+https://github.com/jiaoquaner/jiaoquaner-plugin.git"]
}
```

重启 OpenCode。插件会通过 OpenCode 的插件管理器安装，并把 `skills/` 目录注册进来，焦圈儿技能随即可被发现、**按需触发**（不会强制注入每个会话）。

固定某个版本：

```json
{
  "plugin": ["jiaoquaner@git+https://github.com/jiaoquaner/jiaoquaner-plugin.git#v0.1.0"]
}
```

## 使用

用 OpenCode 原生 `skill` 工具：

```
use skill tool to list skills
use skill tool to load jiaoquaner
use skill tool to load humanize
```

## 工具映射

技能里用动作描述（“运行 shell 命令”“向用户提问”等），在 OpenCode 上对应：

- 运行 `curl` / `jq` 等命令 → `bash`
- 读文件 → `read`
- 新建 / 编辑 / 删除文件 → `apply_patch`
- 搜索文件内容 / 按名查找 → `grep`、`glob`
- 抓取 URL → `webfetch`
- 加载技能 → OpenCode 原生 `skill` 工具

## 排查

1. 查日志：`opencode run --print-logs "hello" 2>&1 | grep -i jiaoquaner`
2. 确认 `opencode.json` 里的 plugin 行
3. 用 `skill` 工具列出已发现的技能，确认 `jiaoquaner` / `humanize` 在列
