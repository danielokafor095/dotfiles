#!/usr/bin/env zsh
# ============================================================
# macOS 开发环境一键配置脚本
# 用法: bash install.sh
# ============================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
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
info "正在通过 Brewfile 安装软件包..."
brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock

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
# 8. 符号链接配置文件
# ============================================================
link_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -f "$dst" ]]; then
    mv "$dst" "${dst}.backup.$(date +%s)"
    warn "已备份 $dst"
  fi
  ln -sf "$src" "$dst"
  info "已链接 $dst → $src"
}

link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

# ============================================================
# 9. Git 配置
# ============================================================
link_file "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
mkdir -p "$HOME/workspace"
info "工作目录 ~/workspace 已就绪（用 setup-identity.sh 添加身份）"

# ============================================================
# 10. Claude Code 配置
# ============================================================
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
link_file "$DOTFILES_DIR/claude/settings.json" "$CLAUDE_DIR/settings.json"
link_file "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/CLAUDE.md"
info "Claude Code 配置已链接（插件会在首次启动时自动安装）"

# ============================================================
# 11. Ghostty 终端配置
# ============================================================
GHOSTTY_CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$GHOSTTY_CONFIG_DIR"
link_file "$DOTFILES_DIR/ghostty/config" "$GHOSTTY_CONFIG_DIR/config.ghostty"

# ============================================================
# 12. VSCode 配置
# ============================================================
VSCODE_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_DIR"
link_file "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_DIR/settings.json"
link_file "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
info "VSCode 配置已链接"

# ============================================================
# 13. Cursor 配置
# ============================================================
CURSOR_DIR="$HOME/Library/Application Support/Cursor/User"
mkdir -p "$CURSOR_DIR"
link_file "$DOTFILES_DIR/cursor/settings.json" "$CURSOR_DIR/settings.json"
link_file "$DOTFILES_DIR/cursor/keybindings.json" "$CURSOR_DIR/keybindings.json"
info "Cursor 配置已链接"

# ============================================================
# 14. Yazi 文件管理器配置
# ============================================================
mkdir -p "$HOME/.config/yazi"
link_file "$DOTFILES_DIR/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
info "Yazi 配置已链接"

# ============================================================
# 15. Zellij 终端复用配置
# ============================================================
mkdir -p "$HOME/.config/zellij"
link_file "$DOTFILES_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
info "Zellij 配置已链接"

# ============================================================
# 16. 密钥文件
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
echo "  → 配置 Git 身份 + SSH Key: bash $DOTFILES_DIR/scripts/setup-identity.sh"
