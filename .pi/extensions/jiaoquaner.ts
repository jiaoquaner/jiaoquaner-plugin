import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// 焦圈儿（jiaoquaner）Pi 扩展：把本包的 skills 目录注册进 Pi，
// 使技能可被 Pi 原生技能系统发现、按需加载。
// 焦圈儿是任务型能力（降 AI 率），因此不做每会话强制注入。

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "../..");
const skillsDir = resolve(packageRoot, "skills");

export default function jiaoquanerPiExtension(pi: ExtensionAPI) {
	pi.on("resources_discover", async () => ({
		skillPaths: [skillsDir],
	}));
}
