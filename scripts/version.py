#!/usr/bin/env python3
"""版本号单一真相源（SSOT）工具。

根目录的 VERSION 是唯一需要人工维护的版本号；各 CLI 的 manifest 只是它的投影。

    python3 scripts/version.py check       # 校验所有 manifest 与 VERSION 一致
    python3 scripts/version.py set 0.2.0   # 写入 VERSION 并同步所有 manifest
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "VERSION"

# 各 CLI 读取的 manifest。每个文件里有且只有一处 "version" 字段。
MANIFESTS = [
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
    ".codex-plugin/plugin.json",
    ".cursor-plugin/plugin.json",
    ".kimi-plugin/plugin.json",
    "gemini-extension.json",
]

VERSION_RE = re.compile(r'("version"\s*:\s*")([^"]*)(")')
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")


def read_ssot() -> str:
    version = VERSION_FILE.read_text(encoding="utf-8").strip()
    if not SEMVER_RE.match(version):
        die(f"VERSION 内容不是合法语义化版本号: {version!r}")
    return version


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def manifest_version(path: Path) -> str:
    """读出 manifest 里的版本号，顺带确保它有且只有一处。"""
    matches = VERSION_RE.findall(path.read_text(encoding="utf-8"))
    if len(matches) != 1:
        die(f'{path.relative_to(ROOT)} 里找到 {len(matches)} 处 "version" 字段，预期 1 处')
    return matches[0][1]


def cmd_check() -> int:
    expected = read_ssot()
    mismatched = []
    for rel in MANIFESTS:
        path = ROOT / rel
        if not path.exists():
            die(f"manifest 不存在: {rel}")
        actual = manifest_version(path)
        status = "ok" if actual == expected else "MISMATCH"
        if actual != expected:
            mismatched.append((rel, actual))
        print(f"  [{status:>8}] {rel}: {actual}")

    if mismatched:
        print(f"\nVERSION 是 {expected}，但以下 manifest 不一致：", file=sys.stderr)
        for rel, actual in mismatched:
            print(f"  {rel}: {actual}", file=sys.stderr)
        print("\n运行 `python3 scripts/version.py set <版本号>` 同步。", file=sys.stderr)
        return 1

    print(f"\n所有 manifest 与 VERSION ({expected}) 一致。")
    return 0


def cmd_set(new_version: str) -> int:
    if not SEMVER_RE.match(new_version):
        die(f"不是合法语义化版本号（形如 1.2.3 或 1.2.3-beta.1）: {new_version!r}")

    VERSION_FILE.write_text(f"{new_version}\n", encoding="utf-8")
    print(f"VERSION -> {new_version}")

    for rel in MANIFESTS:
        path = ROOT / rel
        if not path.exists():
            die(f"manifest 不存在: {rel}")
        manifest_version(path)  # 校验只有一处
        text = path.read_text(encoding="utf-8")
        path.write_text(
            VERSION_RE.sub(lambda m: f"{m.group(1)}{new_version}{m.group(3)}", text),
            encoding="utf-8",
        )
        print(f"  {rel} -> {new_version}")

    return 0


def main() -> int:
    args = sys.argv[1:]
    if not args:
        die("用法: version.py check | set <版本号>")

    if args[0] == "check":
        return cmd_check()
    if args[0] == "set":
        if len(args) != 2:
            die("用法: version.py set <版本号>")
        return cmd_set(args[1])

    die(f"未知子命令: {args[0]}（可用: check, set）")
    return 1


if __name__ == "__main__":
    sys.exit(main())
