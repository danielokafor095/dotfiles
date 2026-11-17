#!/bin/bash
# 新 Mac 入口：仅依赖系统 Bash，先准备 Git，再获取完整仓库。
set -euo pipefail
trap 'printf "启动未完成（第 %s 行），请处理上面的错误后重新运行。\n" "$LINENO" >&2' ERR

REPO_URL="https://github.com/ovislab/dotfiles.git"
BRANCH="main"
DOTFILES_DIR="${DOTFILES_BOOTSTRAP_DIR:-$HOME/dotfiles}"

info() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  die '此安装入口仅支持 macOS。'
fi
if [[ "$EUID" -eq 0 ]]; then
  die '请以当前登录用户运行，不要给整条命令加 sudo。'
fi

developer_tools_ready() {
  xcode-select -p >/dev/null 2>&1 && xcrun --find git >/dev/null 2>&1
}

if ! developer_tools_ready; then
  info '正在请求安装 Apple 命令行工具，请在系统弹窗中确认；脚本会等待安装完成。'
  xcode-select --install
  waited=0
  until developer_tools_ready; do
    if [[ "$waited" -ge 1800 ]]; then
      die '等待命令行工具超过 30 分钟。请确认系统安装结果，再重新运行此命令。'
    fi
    sleep 5
    waited=$((waited + 5))
  done
fi
git --version

if [[ -e "$DOTFILES_DIR" || -L "$DOTFILES_DIR" ]]; then
  [[ -d "$DOTFILES_DIR" ]] || die "目标路径不是目录：$DOTFILES_DIR"
  repo_root=$(git -C "$DOTFILES_DIR" rev-parse --show-toplevel)
  actual_dir=$(cd "$DOTFILES_DIR" && pwd -P)
  [[ "$repo_root" == "$actual_dir" ]] || die "目标目录不是独立的 Git 仓库：$DOTFILES_DIR"
  origin=$(git -C "$DOTFILES_DIR" remote get-url origin)
  case "$origin" in
    https://github.com/ovislab/dotfiles|https://github.com/ovislab/dotfiles.git|git@github.com:ovislab/dotfiles.git) ;;
    *) die "目标目录的 origin 不属于 ovislab/dotfiles，请先核对：$DOTFILES_DIR" ;;
  esac
  working_changes=$(git -C "$DOTFILES_DIR" status --porcelain)
  [[ -z "$working_changes" ]] || die "仓库有未提交改动，请先处理：$DOTFILES_DIR"
  current_branch=$(git -C "$DOTFILES_DIR" symbolic-ref --quiet --short HEAD)
  [[ "$current_branch" == "$BRANCH" ]] || die "当前分支不是 ${BRANCH}，请先处理：$DOTFILES_DIR"
  info '正在通过 HTTPS 快进更新已有 dotfiles，保留现有 origin 地址。'
  GIT_TERMINAL_PROMPT=0 git -C "$DOTFILES_DIR" pull --ff-only "$REPO_URL" "$BRANCH"
else
  info "正在下载 dotfiles 到 $DOTFILES_DIR"
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  GIT_TERMINAL_PROMPT=0 git clone --branch "$BRANCH" "$REPO_URL" "$DOTFILES_DIR"
fi

[[ -f "$DOTFILES_DIR/setup.sh" ]] || die '仓库缺少 setup.sh，请检查下载结果。'
cd "$DOTFILES_DIR"
zsh "$DOTFILES_DIR/setup.sh"
