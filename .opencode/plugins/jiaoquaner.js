/**
 * 焦圈儿（jiaoquaner）plugin for OpenCode.ai
 *
 * 通过 config 钩子把本插件的 skills 目录注册进 OpenCode，
 * 使焦圈儿技能可被原生 `skill` 工具发现、按需加载 —— 无需符号链接。
 *
 * 与 superpowers 不同：焦圈儿是任务型能力（降 AI 率），
 * 因此不做「每会话强制注入」，技能只在相关时触发。
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const JiaoquanerPlugin = async () => {
  const skillsDir = path.resolve(__dirname, '../../skills');

  return {
    // 把 skills 路径注入实时 config，让 OpenCode 懒发现时能找到焦圈儿技能，
    // 无需手动改配置或建符号链接。
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};
