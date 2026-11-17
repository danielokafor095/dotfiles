#!/usr/bin/env zsh
# ============================================================
# macOS 开发环境一键配置脚本
# 用法: ./setup.sh
# ============================================================
set -uo pipefail

DOTFILES_DIR="${0:A:h}"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# ============================================================
# 1. Homebrew
# ============================================================
if ! command -v brew &>/dev/null; then
  warn "Homebrew 未安装，正在安装..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon 路径
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  info "Homebrew 已安装"
fi

# 配置清华镜像源
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
info "Homebrew 镜像源已配置（清华 TUNA）"

# ============================================================
# 2. Brew Bundle（安装所有包）
# ============================================================
# 预先添加第三方 tap（需要显式信任）
brew tap asmvik/formulae 2>/dev/null || true
brew tap steipete/tap 2>/dev/null || true
info "第三方 Tap 已添加"

# 预缓存 sudo 密码（部分 cask 安装需要权限）
info "部分应用安装需要管理员权限，请输入密码..."
sudo -v
# 后台保持 sudo 会话有效
while true; do sudo -n true; sleep 50; done 2>/dev/null &
SUDO_PID=$!

info "正在通过 Brewfile 安装软件包..."
brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "部分包安装失败，可稍后手动重试"

# 结束 sudo 保活进程
kill "$SUDO_PID" 2>/dev/null

# ============================================================
# 3. Rust（通过 rustup）
# ============================================================
if ! command -v rustup &>/dev/null; then
  info "正在安装 Rust（rustup）..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  info "Rust 已安装（$(rustc --version)）"
fi

# ============================================================
# 4. Go 环境变量
# ============================================================
if command -v go &>/dev/null; then
  info "Go 已安装（$(go version | awk '{print $3}')）"
  export GOPATH="$HOME/go"
  mkdir -p "$GOPATH"
else
  warn "Go 未安装，请检查 Brewfile 是否正确执行"
fi

# ============================================================
# 5. Zinit 插件管理器
# ============================================================
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  info "正在安装 Zinit..."
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
else
  info "Zinit 已安装"
fi

# ============================================================
# 6. Bun
# ============================================================
if ! command -v bun &>/dev/null; then
  info "正在安装 Bun..."
  curl -fsSL https://bun.sh/install | bash
else
  info "Bun 已安装"
fi

# ============================================================
# 7. Node.js（通过 fnm）
# ============================================================
eval "$(fnm env --shell bash)"
if ! fnm list | grep -q "v24"; then
  info "正在通过 fnm 安装 Node.js v24..."
  fnm install 24
  fnm default 24
else
  info "Node.js v24 已安装"
fi

# ============================================================
# 8. 复制配置文件（独立副本，避免仓库状态变化）
# ============================================================
copy_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -f "$dst" ]]; then
    mv "$dst" "${dst}.backup.$(date +%s)"
    warn "已备份 $dst"
  fi
  cp "$src" "$dst"
  info "已复制 $src → $dst"
}

copy_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
copy_file "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

# ============================================================
# 9. Git 配置
# ============================================================
copy_file "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
mkdir -p "$HOME/Workspace"
info "工作目录 ~/Workspace 已就绪（用 setup-identity.sh 添加身份）"

# ============================================================
# 10. Agents 配置
# ============================================================
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$CLAUDE_DIR"
copy_file "$DOTFILES_DIR/claude/settings.json" "$CLAUDE_DIR/settings.json"
if ! zsh "$DOTFILES_DIR/scripts/setup-agents.sh"; then
  warn "Agents 指令部署或检查未通过，请运行 scripts/setup-agents.sh --check 查看"
  exit 1
fi

# ============================================================
# 11. 密钥文件
# ============================================================
if [[ ! -f "$HOME/.zsh_secrets" ]]; then
  if [[ -f "$DOTFILES_DIR/zsh/.zsh_secrets" ]]; then
    cp "$DOTFILES_DIR/zsh/.zsh_secrets" "$HOME/.zsh_secrets"
    info "已从 dotfiles 复制 ~/.zsh_secrets（含真实 token）"
  else
    cp "$DOTFILES_DIR/zsh/.zsh_secrets.example" "$HOME/.zsh_secrets"
    warn "已创建 ~/.zsh_secrets（模板），请编辑填入真实 token："
    warn "  vim ~/.zsh_secrets"
  fi
  chmod 600 "$HOME/.zsh_secrets"
else
  info "~/.zsh_secrets 已存在，跳过"
fi

# ============================================================
# 完成
# ============================================================
echo ""
info "🎉 环境配置完成！"
echo "  → 请重新打开终端，或执行: exec zsh"
echo "  → 首次启动会自动下载 zsh 插件（需要网络）"
echo "  → 别忘了编辑 ~/.zsh_secrets 填入你的 token"
echo "  → 配置 Git 身份 + SSH Key: $DOTFILES_DIR/scripts/setup-identity.sh"
echo "  → VSCode / Cursor 配置请使用编辑器内置 Settings Sync 恢复"
