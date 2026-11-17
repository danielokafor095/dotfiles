#!/bin/bash
# 在 Git 配置部署完成后登录，并设置 HTTPS 凭据助手；可单独重试。
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  printf '%s\n' '未找到 GitHub CLI，请先安装：brew install gh' >&2
  exit 1
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  printf '%s\n' '正在通过浏览器登录 GitHub，请按提示完成授权。'
  gh auth login --hostname github.com --git-protocol https --web
fi

gh auth setup-git --hostname github.com
printf '%s\n' 'GitHub CLI 已登录，Git HTTPS 凭据助手已配置。'
