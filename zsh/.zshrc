# ============================================================
# Powerlevel10k Instant Prompt（必须在最顶部）
# ============================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================
# 敏感环境变量（从独立文件加载）
# ============================================================
[[ -f ~/.zsh_secrets ]] && source ~/.zsh_secrets

# ============================================================
# Zinit 插件管理器
# ============================================================
source "${HOME}/.local/share/zinit/zinit.git/zinit.zsh"

zinit ice depth=1
zinit light romkatv/powerlevel10k

zinit wait lucid for \
  atinit"zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull"zinit creinstall -q ." \
    zsh-users/zsh-completions

zinit wait lucid for \
  OMZL::git.zsh \
  OMZP::git

# ============================================================
# 环境变量 & PATH
# ============================================================
export EDITOR="vim"
export LANG="en_US.UTF-8"

export PNPM_HOME="$HOME/Library/pnpm"
export BUN_INSTALL="$HOME/.bun"
export PATH="$HOME/.local/bin:$PATH"

path=(
  $PNPM_HOME/bin
  $BUN_INSTALL/bin
  $path
)
typeset -U path

# ============================================================
# CLI 工具初始化
# ============================================================
eval "$(zoxide init zsh)"
eval "$(fnm env --use-on-cd --shell zsh --log-level quiet)"

# ============================================================
# History 配置
# ============================================================
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# ============================================================
# 补全 & 按键绑定
# ============================================================
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

zinit snippet OMZL::key-bindings.zsh
zinit snippet OMZL::completion.zsh

# ============================================================
# Aliases — 通用
# ============================================================
alias ls="eza --group-directories-first"
alias ll="eza -la --group-directories-first --git"
alias lt="eza -la --tree --level=2"
alias l="eza -la"
alias cat="bat --paging=never -p"

# ============================================================
# Aliases — 个人 & 工作
# ============================================================
alias w2r="w2 restart"
alias ccd="claude --dangerously-skip-permissions --effort max"

# ============================================================
# Homebrew 国内镜像源（清华大学 TUNA）
# ============================================================
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"

# ============================================================
# Powerlevel10k 配置（必须在最末尾）
# ============================================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
