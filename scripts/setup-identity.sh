#!/usr/bin/env zsh
# ============================================================
# SSH Key + Git 身份 交互式配置脚本
#
# 功能：
#   1. 生成 SSH 密钥对，存放在 ~/.ssh/<别名>/
#   2. 创建 ~/Workspace/<别名>/ 工作目录
#   3. 自动配置 .gitconfig includeIf 条件
#   4. 自动追加 ~/.ssh/config Host 配置
#   5. 可选设为全局默认身份
#
# 用法:
#   ./setup-identity.sh                       # 交互式创建新身份
#   ./setup-identity.sh --set-default <别名>  # 切换默认身份到已有的别名
#   ./setup-identity.sh --set-default         # 列出所有身份及当前默认
#
# ============================================================
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
ask() { echo -e "${CYAN}[?]${NC} $1"; }

WORKSPACE_DIR="$HOME/Workspace"
SSH_DIR="$HOME/.ssh"
GITCONFIG="$HOME/.gitconfig"
GITCONFIG_DEFAULT="$HOME/.gitconfig-default"

# ============================================================
# 辅助函数：获取当前默认身份别名
# ============================================================
get_current_default() {
  if [[ -f "$GITCONFIG_DEFAULT" ]]; then
    # 从 sshCommand 中提取别名（路径格式: ~/.ssh/<别名>/id_xxx）
    local ssh_path=$(grep "sshCommand" "$GITCONFIG_DEFAULT" 2>/dev/null | grep -oE '\.ssh/[^/]+/' | sed 's|\.ssh/||;s|/||')
    if [[ -n "$ssh_path" ]]; then
      echo "$ssh_path"
      return 0
    fi
  fi
  return 1
}

# ============================================================
# 辅助函数：将指定别名设为默认
# ============================================================
apply_default() {
  local alias_name="$1"
  local identity_file="$HOME/.gitconfig-$alias_name"

  if [[ ! -f "$identity_file" ]]; then
    echo "错误：身份配置 $identity_file 不存在"; exit 1
  fi

  # 复制身份配置为 default
  cp "$identity_file" "$GITCONFIG_DEFAULT"
  info "已将 $alias_name 设为全局默认身份 → $GITCONFIG_DEFAULT"

  # 确保主 .gitconfig 中有 include 指向 default
  if grep -q "path = $GITCONFIG_DEFAULT" "$GITCONFIG" 2>/dev/null; then
    info ".gitconfig 已包含默认身份引用"
  else
    local temp_file=$(mktemp)
    cat > "$temp_file" <<EOF
[include]
    path = $GITCONFIG_DEFAULT

EOF
    cat "$GITCONFIG" >> "$temp_file"
    mv "$temp_file" "$GITCONFIG"
    info "已将默认身份添加到 .gitconfig 顶部"
  fi
}

# ============================================================
# 参数模式：--set-default <别名>
# ============================================================
if [[ "${1:-}" == "--set-default" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "用法: ./setup-identity.sh --set-default <别名>"
    echo ""
    echo "可用的身份："
    for f in "$HOME"/.gitconfig-*; do
      [[ "$f" == *"-default" ]] && continue
      name="${f##*/.gitconfig-}"
      current_default=$(get_current_default)
      if [[ "$name" == "$current_default" ]]; then
        echo "  * $name （当前默认）"
      else
        echo "    $name"
      fi
    done
    exit 1
  fi
  apply_default "$2"
  exit 0
fi

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
printf "  别名: "; read -r ALIAS
if [[ -z "$ALIAS" ]]; then
  echo "错误：别名不能为空"; exit 1
fi

# Git 用户名
ask "请输入 Git 用户名（提交时显示的名称）："
printf "  用户名 [$ALIAS]: "; read -r GIT_NAME
GIT_NAME="${GIT_NAME:-$ALIAS}"

# Git 邮箱
ask "请输入 Git 邮箱："
printf "  邮箱: "; read -r GIT_EMAIL
if [[ -z "$GIT_EMAIL" ]]; then
  echo "错误：邮箱不能为空"; exit 1
fi

# SSH Host
ask "请输入 SSH Host 地址（如 github.com、gitlab.example.com）："
printf "  Host: "; read -r SSH_HOST
if [[ -z "$SSH_HOST" ]]; then
  echo "错误：Host 不能为空"; exit 1
fi

# SSH Host 别名（用于多账号区分同一平台）
DEFAULT_HOST_ALIAS="$SSH_HOST"
if [[ "$SSH_HOST" == "github.com" && "$ALIAS" != "github" ]]; then
  DEFAULT_HOST_ALIAS="github.com-${ALIAS}"
fi
ask "SSH Host 别名（用于 git remote，多账号时可区分）："
printf "  Host 别名 [$DEFAULT_HOST_ALIAS]: "; read -r HOST_ALIAS
HOST_ALIAS="${HOST_ALIAS:-$DEFAULT_HOST_ALIAS}"

# 密钥类型
echo ""
ask "选择 SSH 密钥类型："
echo "  1) ed25519（推荐，默认）"
echo "  2) rsa（4096 位）"
echo "  3) ecdsa（256 位）"
echo "  4) ed25519-sk（硬件密钥）"
printf "  选择 [1]: "; read -r KEY_CHOICE
case "${KEY_CHOICE:-1}" in
  1) KEY_TYPE="ed25519" ;;
  2) KEY_TYPE="rsa"; KEY_BITS="-b 4096" ;;
  3) KEY_TYPE="ecdsa"; KEY_BITS="-b 256" ;;
  4) KEY_TYPE="ed25519-sk" ;;
  *) KEY_TYPE="ed25519" ;;
esac
KEY_BITS="${KEY_BITS:-}"

# 是否设为默认
echo ""
CURRENT_DEFAULT=$(get_current_default)
if [[ -n "$CURRENT_DEFAULT" ]]; then
  ask "当前全局默认身份: $CURRENT_DEFAULT"
  ask "是否将 $ALIAS 切换为新的全局默认？"
  printf "  切换默认 [y/N]: "; read -r SET_DEFAULT
  SET_DEFAULT="${SET_DEFAULT:-N}"
else
  ask "尚未配置全局默认身份，是否将 $ALIAS 设为默认？"
  printf "  设为默认 [Y/n]: "; read -r SET_DEFAULT
  SET_DEFAULT="${SET_DEFAULT:-Y}"
fi

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
echo "  工作目录:    ~/Workspace/$ALIAS/"
if [[ "$SET_DEFAULT" =~ ^[Yy] ]]; then
  echo "  全局默认:    ✓ 是（替换 ${CURRENT_DEFAULT:-无}）"
else
  echo "  全局默认:    ✗ 否（保持 ${CURRENT_DEFAULT:-无}）"
fi
echo "──────────────────────────────"
echo ""
printf "确认配置？[Y/n] "; read -r CONFIRM
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
# 3. 创建 Workspace 目录
# ============================================================
WORK_DIR="$WORKSPACE_DIR/$ALIAS"
mkdir -p "$WORK_DIR"
info "工作目录已创建: $WORK_DIR"

# ============================================================
# 4. 配置 .gitconfig includeIf
# ============================================================
GITCONFIG_IDENTITY="$HOME/.gitconfig-$ALIAS"

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
# 5. 设为全局默认身份
# ============================================================
if [[ "$SET_DEFAULT" =~ ^[Yy] ]]; then
  apply_default "$ALIAS"
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
[[ "$SET_DEFAULT" =~ ^[Yy] ]] && echo "    4. 在任意目录下 git 操作默认使用此身份"
echo ""
echo "  切换默认身份："
echo "    $(realpath $0) --set-default <别名>"
