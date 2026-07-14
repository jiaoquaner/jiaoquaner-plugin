#!/usr/bin/env bash
# 校验各 CLI manifest 的 version 是否都与根目录 VERSION 一致。
# CI 与 release.sh 都会调用它；不一致时以非零码退出。
set -euo pipefail

cd "$(dirname "$0")/.."
exec python3 scripts/version.py check
