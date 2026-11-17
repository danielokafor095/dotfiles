#!/usr/bin/env zsh
# 仅部署 Agent 指令，不运行软件安装或覆盖应用设置。
# DOTFILES_AGENT_HOME 可指定独立的部署目录；默认使用当前用户目录。
set -euo pipefail

DOTFILES_DIR="${0:A:h:h}"
AGENT_HOME="${DOTFILES_AGENT_HOME:-$HOME}"
AGENT_HOME="${AGENT_HOME:A}"
SOURCE="$DOTFILES_DIR/agents/AGENTS.md"
CODEX_DIR="${CODEX_HOME:-$AGENT_HOME/.codex}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$AGENT_HOME/.claude}"
TARGETS=(
  "$AGENT_HOME/AGENTS.md"
  "$CODEX_DIR/AGENTS.md"
  "$CLAUDE_DIR/CLAUDE.md"
  "$AGENT_HOME/.gemini/GEMINI.md"
)
MODE="install"
BACKUP_DIR=""
BACKUP_COUNT=0

case "${1:-}" in
  "") ;;
  --check) MODE="check" ;;
  --help|-h)
    print '用法: ./scripts/setup-agents.sh [--check]'
    print '  默认：备份旧文件并建立软链接；--check：只检查链接和全局覆盖文件。'
    print '  独立目录：DOTFILES_AGENT_HOME=/目标目录 ./scripts/setup-agents.sh'
    exit 0 ;;
  *) print -u2 "未知参数：$1"; exit 2 ;;
esac
if (( $# > 1 )); then
  print -u2 '参数过多'; exit 2
fi
if [[ ! -s "$SOURCE" ]]; then
  print -u2 "指令原稿不存在或为空：$SOURCE"; exit 1
fi

backup_existing() {
  local dst="$1"
  if [[ -z "$BACKUP_DIR" ]]; then
    local root="$AGENT_HOME/.local/state/dotfiles/agents-backups"
    mkdir -p "$root"
    BACKUP_DIR=$(mktemp -d "$root/$(date +%Y%m%d-%H%M%S).XXXXXXXX")
  fi
  BACKUP_COUNT=$((BACKUP_COUNT + 1))
  local backup="$BACKUP_DIR/$BACKUP_COUNT-${dst:t}"
  mv "$dst" "$backup"
  print -r -- "已备份：$dst → $backup"
}

linked_to_source() {
  [[ -L "$1" && "$(readlink "$1")" == "$SOURCE" ]]
}

check_links() {
  local failed=0 dst
  for dst in "${TARGETS[@]}"; do
    if linked_to_source "$dst"; then
      print -r -- "链接正常：$dst → $SOURCE"
    else
      print -u2 -r -- "链接缺失或指向错误：$dst"
      failed=1
    fi
  done
  if [[ -s "$CODEX_DIR/AGENTS.override.md" ]]; then
    print -u2 -r -- "注意：$CODEX_DIR/AGENTS.override.md 会优先于 AGENTS.md 加载，请检查内容。"
    failed=1
  fi
  if [[ -f "$AGENT_HOME/CLAUDE.md" || -L "$AGENT_HOME/CLAUDE.md" ]]; then
    print -u2 -r -- "注意：$AGENT_HOME/CLAUDE.md 仍存在，可能作为目录级指令额外加载。"
  fi
  if [[ -f "$AGENT_HOME/.gemini/AGENTS.md" || -L "$AGENT_HOME/.gemini/AGENTS.md" ]]; then
    print -u2 '注意：~/.gemini/AGENTS.md 仍存在，Antigravity 可能额外加载，请检查是否重复或冲突。'
  fi
  return "$failed"
}

if [[ "$MODE" == "check" ]]; then
  check_links
  exit $?
fi

# 先检查全部目标，避免把目录误当成待替换文件。
for dst in "${TARGETS[@]}"; do
  if [[ -e "${dst:h}" && ! -d "${dst:h}" ]]; then
    print -u2 -r -- "目标父路径不是目录，停止部署：${dst:h}"
    exit 1
  fi
  if [[ -e "$dst" && ! -f "$dst" && ! -L "$dst" ]]; then
    print -u2 -r -- "目标不是普通文件或软链接，停止部署：$dst"
    exit 1
  fi
done

for dst in "${TARGETS[@]}"; do
  if linked_to_source "$dst"; then
    continue
  fi
  mkdir -p "${dst:h}"
  if [[ -e "$dst" || -L "$dst" ]]; then
    backup_existing "$dst"
  fi
  ln -s "$SOURCE" "$dst"
done

# 旧安装只在用户目录放 CLAUDE.md。迁移已知共享链接到真正的全局入口，
# 避免同一套指令同时作为全局规则和祖先目录规则加载；独立内容保留。
legacy="$AGENT_HOME/CLAUDE.md"
if [[ -L "$legacy" && "$legacy" -ef "$SOURCE" ]]; then
  backup_existing "$legacy"
fi

check_links
print '指令已部署。新建 Agent 会话后检查实际加载内容；ChatGPT/Gemini 网页设置需手动粘贴，见 agents/README.md。'
