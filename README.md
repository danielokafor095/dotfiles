# Dotfiles

macOS 开发环境一键配置，包含 zsh、CLI 工具、字体、GUI 应用的完整安装脚本。

## 快速开始

```bash
git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
zsh setup.sh
```

## 包含内容

### CLI 工具
bat, btop, eza, fd, ffmpeg, fnm, fzf, git, git-delta, go, lazygit, pnpm, ripgrep, tmux, uv, wget, yazi, zellij, zoxide

### GUI 应用
Ghostty, Cursor, VS Code, Docker Desktop, TablePlus, Bruno, iStat Menus, AppCleaner 等

### Shell 环境
- **Zsh** + **Powerlevel10k** 主题
- **Zinit** 插件管理器
- 插件：fast-syntax-highlighting, zsh-autosuggestions, zsh-completions, OMZ git
- **fnm** 管理 Node.js，**pnpm** + **Bun** 包管理

### 字体
JetBrains Mono Nerd, Maple Mono NF, Meslo LG Nerd

## 敏感信息

Token 和密钥存放在 `~/.zsh_secrets`（不纳入 git）。首次安装后请编辑：

```bash
vim ~/.zsh_secrets
```

模板见 `zsh/.zsh_secrets.example`。

## 自定义

- 修改 `Brewfile` 增删软件包
- 修改 `zsh/.zshrc` 调整 shell 配置
- 修改 `zsh/.p10k.zsh` 调整终端主题（或运行 `p10k configure`）

## 更新

本地修改配置后同步到仓库：

```bash
cd ~/dotfiles
git add -A && git commit -m "update config" && git push
```
