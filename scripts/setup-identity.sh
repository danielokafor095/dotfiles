#!/usr/bin/env zsh
# ============================================================
# SSH Key + Git 身份 交互式配置脚本
#
# 功能：
#   1. 生成 SSH 密钥对，存放在 ~/.ssh/<别名>/
#   2. 创建 ~/workspace/<别名>/ 工作目录
#   3. 自动配置 .gitconfig includeIf 条件
#   4. 自动追加 ~/.ssh/config Host 配置
#
# 用法: bash setup-identity.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
ask() { echo -e "${CYAN}[?]${NC} $1"; }

WORKSPACE_DIR="$HOME/workspace"
SSH_DIR="$HOME/.ssh"
GITCONFIG="$HOME/.gitconfig"

# ============================================================
# 交互式收集信息
# ============================================================
echo ""
echo "=============================="
echo "  SSH Key + Git 身份配置工具"
echo "=============================="
echo ""

# 别名
ask "请输入别名（通常用平台用户名，如 github 用户名）："
read -rp "  别名: " ALIAS
if [[ -z "$ALIAS" ]]; then
  echo "错误：别名不能为空"; exit 1
fi

# Git 用户名
ask "请输入 Git 用户名（提交时显示的名称）："
read -rp "  用户名 [$ALIAS]: " GIT_NAME
GIT_NAME="${GIT_NAME:-$ALIAS}"

# Git 邮箱
ask "请输入 Git 邮箱："
read -rp "  邮箱: " GIT_EMAIL
if [[ -z "$GIT_EMAIL" ]]; then
  echo "错误：邮箱不能为空"; exit 1
fi

# SSH Host
ask "请输入 SSH Host 地址（如 github.com、gitlab.alibaba-inc.com）："
read -rp "  Host: " SSH_HOST
if [[ -z "$SSH_HOST" ]]; then
  echo "错误：Host 不能为空"; exit 1
fi

# SSH Host 别名（用于多账号区分同一平台）
DEFAULT_HOST_ALIAS="$SSH_HOST"
if [[ "$SSH_HOST" == "github.com" && "$ALIAS" != "github" ]]; then
  DEFAULT_HOST_ALIAS="github.com-${ALIAS}"
fi
ask "SSH Host 别名（用于 git remote，多账号时可区分）："
read -rp "  Host 别名 [$DEFAULT_HOST_ALIAS]: " HOST_ALIAS
HOST_ALIAS="${HOST_ALIAS:-$DEFAULT_HOST_ALIAS}"

# 密钥类型
echo ""
ask "选择 SSH 密钥类型："
echo "  1) ed25519（推荐，默认）"
echo "  2) rsa（4096 位）"
echo "  3) ecdsa（256 位）"
echo "  4) ed25519-sk（硬件密钥）"
read -rp "  选择 [1]: " KEY_CHOICE
case "${KEY_CHOICE:-1}" in
  1) KEY_TYPE="ed25519" ;;
  2) KEY_TYPE="rsa"; KEY_BITS="-b 4096" ;;
  3) KEY_TYPE="ecdsa"; KEY_BITS="-b 256" ;;
  4) KEY_TYPE="ed25519-sk" ;;
  *) KEY_TYPE="ed25519" ;;
esac
KEY_BITS="${KEY_BITS:-}"

# ============================================================
# 确认
# ============================================================
echo ""
echo "──────────────────────────────"
echo "  别名:        $ALIAS"
echo "  Git 用户名:  $GIT_NAME"
echo "  Git 邮箱:    $GIT_EMAIL"
echo "  SSH Host:    $SSH_HOST"
echo "  Host 别名:   $HOST_ALIAS"
echo "  密钥类型:    $KEY_TYPE"
echo "  密钥路径:    ~/.ssh/$ALIAS/id_$KEY_TYPE"
echo "  工作目录:    ~/workspace/$ALIAS/"
echo "──────────────────────────────"
echo ""
read -rp "确认配置？[Y/n] " CONFIRM
if [[ "${CONFIRM:-Y}" =~ ^[Nn] ]]; then
  echo "已取消。"; exit 0
fi

# ============================================================
# 1. 生成 SSH Key
# ============================================================
KEY_DIR="$SSH_DIR/$ALIAS"
KEY_PATH="$KEY_DIR/id_$KEY_TYPE"

mkdir -p "$KEY_DIR"

if [[ -f "$KEY_PATH" ]]; then
  warn "密钥已存在: $KEY_PATH，跳过生成"
else
  ssh-keygen -t "$KEY_TYPE" $KEY_BITS -C "$GIT_EMAIL" -f "$KEY_PATH" -N ""
  info "SSH 密钥已生成: $KEY_PATH"
fi

# ============================================================
# 2. 配置 ~/.ssh/config
# ============================================================
SSH_CONFIG="$SSH_DIR/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if grep -q "# Identity: $ALIAS" "$SSH_CONFIG" 2>/dev/null; then
  warn "SSH config 中已存在 $ALIAS 的配置，跳过"
else
  cat >> "$SSH_CONFIG" <<EOF

# Identity: $ALIAS
Host $HOST_ALIAS
  HostName $SSH_HOST
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
EOF
  info "已追加 SSH config: Host $HOST_ALIAS"
fi

# ============================================================
# 3. 创建 workspace 目录
# ============================================================
WORK_DIR="$WORKSPACE_DIR/$ALIAS"
mkdir -p "$WORK_DIR"
info "工作目录已创建: $WORK_DIR"

# ============================================================
# 4. 配置 .gitconfig includeIf
# ============================================================
GITCONFIG_IDENTITY="$HOME/.gitconfig-$ALIAS"

# 写入身份配置文件
cat > "$GITCONFIG_IDENTITY" <<EOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL

[core]
    sshCommand = ssh -i $KEY_PATH -o IdentitiesOnly=yes
EOF
info "已写入 $GITCONFIG_IDENTITY"

# 追加 includeIf 到主 .gitconfig（如果不存在）
INCLUDE_PATTERN="gitdir:$WORK_DIR/"
if grep -q "$INCLUDE_PATTERN" "$GITCONFIG" 2>/dev/null; then
  warn ".gitconfig 中已存在该 includeIf，跳过"
else
  cat >> "$GITCONFIG" <<EOF

[includeIf "gitdir:$WORK_DIR/"]
    path = $GITCONFIG_IDENTITY
EOF
  info "已追加 .gitconfig includeIf: $WORK_DIR/"
fi

# ============================================================
# 完成
# ============================================================
echo ""
info "🎉 配置完成！"
echo ""
echo "  公钥内容（复制到平台设置中）："
echo "  ────────────────────────────"
cat "${KEY_PATH}.pub"
echo ""
echo "  ────────────────────────────"
echo ""
echo "  后续操作："
echo "    1. 将上面的公钥添加到 $SSH_HOST 的 SSH Keys 设置中"
echo "    2. 测试连接: ssh -T git@$HOST_ALIAS"
echo "    3. 在 $WORK_DIR 下 clone 项目，git 会自动使用对应身份"
