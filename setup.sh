#!/usr/bin/env zsh
# ============================================================
# macOS 开发环境一键配置脚本
# 用法: ./setup.sh
# ============================================================
set -euo pipefail

DOTFILES_DIR="${0:A:h}"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

SUDO_PID=""
cleanup() {
  if [[ -n "$SUDO_PID" ]]; then
    kill "$SUDO_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'warn "安装未完成，请处理上面的错误后重试。"' ZERR

run_bash_installer() {
  local url="$1" content
  shift
  content=$(curl -fsSL "$url")
  [[ -n "$content" ]] || { warn "下载的安装脚本为空：$url"; return 1; }
  /bin/bash -c "$content" -- "$@"
}

activate_homebrew() {
  local brew_path brew_env
  for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_path" ]]; then
      brew_env=$("$brew_path" shellenv)
      eval "$brew_env"
      return
    fi
  done
}

# ============================================================
# 1. Homebrew
# ============================================================
# 在安装前配置镜像；保留调用者已有的镜像设置。
export HOMEBREW_API_DOMAIN="${HOMEBREW_API_DOMAIN:-https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api}"
export HOMEBREW_BOTTLE_DOMAIN="${HOMEBREW_BOTTLE_DOMAIN:-https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles}"
export HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_BREW_GIT_REMOTE:-https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git}"
info "Homebrew 镜像源已配置"

# 已安装但尚未进入 PATH 的 Homebrew 也应复用。
if ! command -v brew &>/dev/null; then
  activate_homebrew
fi
if ! command -v brew &>/dev/null; then
  info "正在安装 Homebrew..."
  run_bash_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  activate_homebrew
fi
command -v brew >/dev/null
info "Homebrew 已就绪"

# ============================================================
# 2. Brew Bundle（安装所有包）
# ============================================================
# 预先添加第三方 tap（需要显式信任）
brew tap asmvik/formulae
brew tap steipete/tap
info "第三方 Tap 已添加"

# 预缓存 sudo 密码（部分 cask 安装需要权限）
info "部分应用安装需要管理员权限，请输入密码..."
sudo -v
# 后台保持 sudo 会话有效
(while sudo -n true; do sleep 50; done) 2>/dev/null &
SUDO_PID=$!

info "正在通过 Brewfile 安装软件包..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 结束 sudo 保活进程
cleanup
SUDO_PID=""

# ============================================================
# 3. Rust（通过 rustup）
# ============================================================
if ! command -v rustup &>/dev/null; then
  info "正在安装 Rust（rustup）..."
  run_bash_installer https://sh.rustup.rs -y
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
  exit 1
fi

# ============================================================
# 5. Zinit 插件管理器
# ============================================================
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  info "正在安装 Zinit..."
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
else
  info "Zinit 已安装"
fi

# ============================================================
# 6. Bun
# ============================================================
if ! command -v bun &>/dev/null; then
  info "正在安装 Bun..."
  run_bash_installer https://bun.sh/install
else
  info "Bun 已安装"
fi

# ============================================================
# 7. Node.js（通过 fnm）
# ============================================================
fnm_env=$(fnm env --shell zsh)
eval "$fnm_env"
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
    if cmp -s "$src" "$dst"; then
      info "$dst 已是最新配置"
      return
    fi
    mv "$dst" "${dst}.backup.$(date +%Y%m%d-%H%M%S).$$"
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
# 12. GitHub 登录（在 Git 配置部署后修复凭据助手）
# ============================================================
bash "$DOTFILES_DIR/scripts/setup-github.sh"

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
