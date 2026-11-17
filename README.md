# Dotfiles

macOS 开发环境一键配置，包含 Shell、终端、编辑器、CLI 工具、Git 多身份管理的完整自动化脚本。

## 快速开始

新 Mac 打开 Terminal.app，执行以下命令（需要仓库已公开，且 `bootstrap.sh` 已推送到 `main`）：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ovislab/dotfiles/main/bootstrap.sh)"
```

入口兼容 macOS 自带的 Bash 3.2，不需要预先安装 Git、Homebrew、GitHub CLI 或配置 SSH。
它先检查 Apple 命令行工具，必要时触发系统安装弹窗，等待完成后通过 HTTPS 克隆仓库，再执行 `setup.sh`。
系统安装确认、管理员密码和最后的 GitHub 浏览器授权仍需本人完成。

重复运行时，如果 `~/dotfiles` 是本仓库的干净 `main` 分支，入口会通过 HTTPS 快进更新；
有未提交改动、分支不符或目标属于其他仓库时停止，不自动覆盖或切换。
已有 SSH origin 会保留，启动更新本身使用 HTTPS。

也可以在命令行工具已安装后手动克隆，或从已有仓库直接运行：

```zsh
git clone https://github.com/ovislab/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

安装必要步骤失败会中止，不会显示“环境配置完成”。修复错误后可以重新运行入口。
GitHub 授权失败时，软件与文件配置可能已完成，可单独重试 `./scripts/setup-github.sh`。
Git 配置部署后会重新设置 `gh` 凭据助手，避免配置覆盖导致 HTTPS 认证丢失。
SSH 和多账号身份由后面的 `setup-identity.sh` 按需配置，不是首次安装的前提。

## 安装流程

`setup.sh` 会依次完成：

| 步骤 | 说明 |
|------|------|
| 1 | 安装 Homebrew + 配置清华镜像源 |
| 2 | 通过 Brewfile 安装所有 CLI 工具、GUI 应用、字体 |
| 3 | 安装 Rust（rustup） |
| 4 | 配置 Go 环境 |
| 5 | 安装 Zinit（zsh 插件管理器） |
| 6 | 安装 Bun |
| 7 | 通过 fnm 安装 Node.js v24 |
| 8 | 复制 .zshrc + .p10k.zsh |
| 9 | 复制 .gitconfig |
| 10 | 复制 Claude 设置，并将 Agent 全局指令软链接到仓库原稿 |
| 11 | 创建 ~/.zsh_secrets 密钥文件 |
| 12 | 复用已有 GitHub 登录或启动浏览器授权，配置 HTTPS 凭据助手 |

## Git 多身份 + SSH Key 配置

```zsh
./scripts/setup-identity.sh
```

交互式完成：
1. 输入别名（如 GitHub 用户名 `qiyue`）
2. 输入 Git 用户名、邮箱
3. 输入 SSH Host（如 `github.com`）
4. 选择密钥类型（默认 ed25519）

脚本自动：
- 生成密钥到 `~/.ssh/<别名>/id_ed25519`
- 追加 `~/.ssh/config` Host 配置
- 创建 `~/Workspace/<别名>/` 工作目录
- 写入 `.gitconfig-<别名>` 并配置 `includeIf`
- 输出公钥，方便复制到平台

在 `~/Workspace/<别名>/` 下 clone 的项目会自动使用对应身份。

## 目录结构

```
dotfiles/
├── bootstrap.sh                  # 新 Mac 在线启动入口（系统 Bash）
├── setup.sh                      # 一键安装入口
├── scripts/setup-github.sh       # GitHub 登录及 HTTPS 凭据配置，可单独重试
├── scripts/setup-identity.sh     # 交互式 SSH + Git 身份配置
├── scripts/setup-agents.sh       # Agent 指令部署 / 检查，可单独运行
├── scripts/sync-back.sh          # 反向同步（本机 → 仓库）
├── Brewfile                      # Homebrew 包清单
├── git/.gitconfig                # Git 全局配置
├── zsh/.zshrc                    # Zsh 主配置
├── zsh/.p10k.zsh                 # Powerlevel10k 主题
├── zsh/.zsh_secrets.example      # 密钥模板
├── agents/AGENTS.md              # 全局 Agent 指令（权威源）
├── agents/README.md              # 各工具入口、手动适配和生效检查
├── agents/CHAT-INSTRUCTIONS.md   # ChatGPT / Gemini 网页聊天精简版
├── claude/settings.json          # Claude Code 设置
├── vscode/settings.json          # VSCode / Cursor 编辑器设置
├── vscode/keybindings.json       # VSCode / Cursor 快捷键
├── vscode/extensions.json        # VSCode 插件清单
├── .gitignore
└── README.md
```

## 敏感信息

Token 和密钥存放在 `~/.zsh_secrets`（不纳入 git）。首次安装后请编辑：

```zsh
vim ~/.zsh_secrets
```

模板见 `zsh/.zsh_secrets.example`。

## 包含的软件

### CLI 工具
bat, btop, eza, fd, ffmpeg, fnm, fzf, git, git-delta, go, lazygit, llama.cpp, pnpm, ripgrep, tmux, uv, wget, xcodegen, zoxide

### GUI 应用
Warp, Cursor, VS Code, Docker Desktop, TablePlus, Bruno, iStat Menus, AppCleaner, Macs Fan Control, itsycal

### Shell 环境
- Zsh + Powerlevel10k + Zinit
- 插件：fast-syntax-highlighting, zsh-autosuggestions, zsh-completions, OMZ git

### 语言 & 运行时
- Rust（rustup）
- Go（Homebrew）
- Node.js v24（fnm）
- Bun、pnpm

### 编辑器
- VSCode / Cursor（共用一套 settings + keybindings）
- 38 个插件自动安装

### 字体
JetBrains Mono Nerd, Maple Mono NF, Meslo LG Nerd

## 自定义

| 文件 | 用途 |
|------|------|
| `Brewfile` | 增删软件包 |
| `zsh/.zshrc` | Shell 配置 |
| `zsh/.p10k.zsh` | 终端主题（或 `p10k configure`） |
| `vscode/settings.json` | 编辑器设置 |
| `vscode/keybindings.json` | 编辑器快捷键 |
| `vscode/extensions.json` | 插件清单 |
| `git/.gitconfig` | Git 全局设置 |
| `agents/AGENTS.md` | 全局 Agent 指令原稿，各本机入口直接软链接到这里 |

## Agent 指令

首次安装由 `setup.sh` 部署。现有电脑只更新 Agent 指令时运行：

```zsh
./scripts/setup-agents.sh
./scripts/setup-agents.sh --check
```

Codex、Claude Code、Gemini CLI 和 Antigravity 共用 `agents/AGENTS.md`。
`~/AGENTS.md` 保留为兼容入口，各工具的全局入口直接链接到仓库，避免多份副本。
替换的旧文件和软链接保存在 `~/.local/state/dotfiles/agents-backups/`。
修改原稿即更新全部链接内容；已运行的会话需按工具要求重新加载。
仓库必须保留在部署时的位置，移动仓库后需重新运行部署脚本。

普通 ChatGPT 和 Gemini 聊天需手动填写应用中的自定义指令，不能通过本机软链接自动设置。
各入口、官方依据和实际加载检查见 [Agent 配置说明](agents/README.md)。

## 同步更新

当本机配置有修改，想同步回仓库时：

Agent 指令直接修改仓库原稿，不参与反向同步；网页聊天精简版需同时检查是否仍与原稿一致。

```zsh
cd ~/dotfiles
./scripts/sync-back.sh        # 交互式逐个确认
./scripts/sync-back.sh --all  # 同步所有变化（不逐个确认）
./scripts/sync-back.sh --dry  # 仅查看差异，不执行操作
```

确认后提交：

```zsh
git add -A && git commit -m "chore: update dotfiles" && git push
```

## 脚本检查

```zsh
bash -n bootstrap.sh scripts/setup-github.sh
zsh -n setup.sh scripts/setup-agents.sh scripts/sync-back.sh
python3 -B -m unittest discover -s tests -v
```

启动与 GitHub 登录测试使用替身命令和临时目录，不安装软件或修改真实用户配置。
`DOTFILES_BOOTSTRAP_DIR` 可指定仓库落地目录，默认 `~/dotfiles`；新机通常无需设置。

安装流程参考：[Apple 命令行工具](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools.md)、
[Homebrew 安装](https://docs.brew.sh/Installation)、[GitHub 浏览器登录](https://cli.github.com/manual/gh_auth_login)、
[GitHub 凭据助手](https://cli.github.com/manual/gh_auth_setup-git)。
