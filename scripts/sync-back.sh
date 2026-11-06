#!/usr/bin/env zsh
# ============================================================
# 反向同步脚本：将本机配置文件的变更同步回 dotfiles 仓库
#
# 功能：
#   1. 逐一对比本机已部署的配置文件与仓库源文件
#   2. 无变化的自动跳过
#   3. 有变化的显示摘要，交互式选择是否同步回仓库
#
# 用法:
#   ./scripts/sync-back.sh          # 交互式逐个确认
#   ./scripts/sync-back.sh --all    # 同步所有有变化的文件（不逐个确认）
#   ./scripts/sync-back.sh --dry    # 仅显示差异，不执行任何复制
#
# ============================================================
set -uo pipefail

DOTFILES_DIR="${0:A:h:h}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
skip() { echo -e "${DIM}[·]${NC} $1"; }

# ============================================================
# 配置映射表：本机路径 → 仓库路径
# ============================================================
typeset -A FILE_MAP
FILE_MAP=(
  "$HOME/.zshrc"                                                    "$DOTFILES_DIR/zsh/.zshrc"
  "$HOME/.p10k.zsh"                                                 "$DOTFILES_DIR/zsh/.p10k.zsh"
  "$HOME/.gitconfig"                                                "$DOTFILES_DIR/git/.gitconfig"
  "$HOME/.claude/settings.json"                                     "$DOTFILES_DIR/claude/settings.json"
  # 本机 CLAUDE.md 是指向 AGENTS.md 的软链，只同步权威文件
  "$HOME/AGENTS.md"                                                 "$DOTFILES_DIR/agents/AGENTS.md"
)

# ============================================================
# 参数解析
# ============================================================
MODE="interactive"
case "${1:-}" in
  --all) MODE="all" ;;
  --dry) MODE="dry" ;;
  --help|-h)
    echo "用法: ./scripts/sync-back.sh [--all|--dry|--help]"
    echo ""
    echo "  (无参数)  交互式逐个确认"
    echo "  --all     同步所有有变化的文件"
    echo "  --dry     仅显示差异，不执行复制"
    echo "  --help    显示此帮助"
    exit 0
    ;;
esac

# ============================================================
# 主逻辑
# ============================================================
echo ""
echo "=============================="
echo "  Dotfiles 反向同步"
echo "=============================="
echo ""

CHANGED=0
SYNCED=0
SKIPPED=0

for deployed repo_file in "${(@kv)FILE_MAP}"; do
  # 本机文件不存在则跳过
  if [[ ! -f "$deployed" ]]; then
    skip "$deployed （不存在，跳过）"
    continue
  fi

  # 仓库文件不存在则视为新增
  if [[ ! -f "$repo_file" ]]; then
    warn "$deployed → 仓库中无对应文件（新增）"
    CHANGED=$((CHANGED + 1))

    if [[ "$MODE" == "dry" ]]; then
      continue
    elif [[ "$MODE" == "all" ]]; then
      cp "$deployed" "$repo_file"
      info "已同步（新增）"
      SYNCED=$((SYNCED + 1))
      continue
    fi

    printf "${CYAN}[?]${NC} 同步到仓库？[y/N/d(diff)] "
    read -r choice
    case "$choice" in
      [Yy]) cp "$deployed" "$repo_file"; info "已同步"; SYNCED=$((SYNCED + 1)) ;;
      *) skip "跳过"; SKIPPED=$((SKIPPED + 1)) ;;
    esac
    continue
  fi

  # 对比差异
  if diff -q "$deployed" "$repo_file" &>/dev/null; then
    skip "${deployed/#$HOME/~} （无变化）"
    continue
  fi

  # 有差异
  CHANGED=$((CHANGED + 1))
  DIFF_STAT=$(diff --stat "$repo_file" "$deployed" 2>/dev/null || diff -u "$repo_file" "$deployed" | head -5)

  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${CYAN}${deployed/#$HOME/~}${NC}"
  echo -e "  → ${DIM}${repo_file/#$DOTFILES_DIR/dotfiles}${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # 显示简要差异行数
  local added=$(diff "$repo_file" "$deployed" | grep -c "^>" 2>/dev/null || echo 0)
  local removed=$(diff "$repo_file" "$deployed" | grep -c "^<" 2>/dev/null || echo 0)
  echo -e "  ${GREEN}+${added}${NC} / ${RED}-${removed}${NC} 行变化"

  if [[ "$MODE" == "dry" ]]; then
    echo -e "  ${DIM}(dry-run 模式，不执行操作)${NC}"
    continue
  fi

  if [[ "$MODE" == "all" ]]; then
    cp "$deployed" "$repo_file"
    info "已同步"
    SYNCED=$((SYNCED + 1))
    continue
  fi

  # 交互模式
  while true; do
    printf "${CYAN}[?]${NC} 操作: [y]同步 / [n]跳过 / [d]查看diff > "
    read -r choice
    case "$choice" in
      [Yy])
        cp "$deployed" "$repo_file"
        info "已同步"
        SYNCED=$((SYNCED + 1))
        break
        ;;
      [Nn]|"")
        skip "跳过"
        SKIPPED=$((SKIPPED + 1))
        break
        ;;
      [Dd])
        echo ""
        diff -u "$repo_file" "$deployed" --color=always | head -60
        echo ""
        if diff -u "$repo_file" "$deployed" | wc -l | read -r total_lines && [[ $total_lines -gt 60 ]]; then
          echo -e "  ${DIM}(仅显示前 60 行，完整 diff 请使用: diff -u \"$repo_file\" \"$deployed\")${NC}"
        fi
        echo ""
        ;;
      *)
        echo "  输入 y/n/d"
        ;;
    esac
  done
done

# ============================================================
# 汇总
# ============================================================
echo ""
echo "──────────────────────────────"
echo -e "  检测到变化: ${CHANGED} 个文件"
echo -e "  已同步:     ${GREEN}${SYNCED}${NC}"
echo -e "  已跳过:     ${DIM}${SKIPPED}${NC}"
echo "──────────────────────────────"
echo ""

if [[ $SYNCED -gt 0 ]]; then
  info "同步完成，可在 dotfiles 目录查看 git diff 确认变更"
  echo -e "  cd ~/dotfiles && git diff"
fi
