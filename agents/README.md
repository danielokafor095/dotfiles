# Agent 全局指令

`AGENTS.md` 是本机 Agent 指令的唯一原稿。所有受支持的本机入口直接软链接到它，编辑链接文件也会修改仓库原稿。
`CHAT-INSTRUCTIONS.md` 是供网页聊天手动粘贴的精简适配版；修改原稿后需复核它，应用端不会自动同步。

## 部署

在仓库目录运行：

```zsh
./scripts/setup-agents.sh
./scripts/setup-agents.sh --check
```

脚本仅部署指令，不安装软件，不修改认证、模型或应用设置。重复运行不会重复备份已正确指向原稿的链接。
已有文件、错误链接和断链会先移动到 `~/.local/state/dotfiles/agents-backups/<时间.随机标识>/`，再创建链接。
日志包含每份旧文件的原位置和备份位置。恢复时先删除对应的新链接，再将备份移回日志记录的原位置。
`--check` 只检查文件系统中的链接和已知覆盖入口，不调用模型，不能证明某个已运行会话加载了这些指令。

## 入口与适用范围

以下路径按默认用户配置目录列出，2026-11-16 核对官方文档：

| 工具 | 入口 | 安装与检查 |
|---|---|---|
| Codex CLI / 使用本机配置的 Codex 客户端 | `~/.codex/AGENTS.md` | 自动链接；设置了 `CODEX_HOME` 时使用该目录。非空的 `AGENTS.override.md` 会替代该文件，脚本保留它并报检查失败。远程/云端环境需在其自身环境配置。 |
| Claude Code | `~/.claude/CLAUDE.md` | 自动链接；设置了 `CLAUDE_CONFIG_DIR` 时使用该目录。 |
| Gemini CLI | `~/.gemini/GEMINI.md` | 自动链接，适用于默认 `context.fileName`。自定义文件名需检查设置与实际加载内容。 |
| Antigravity App / IDE / CLI | `~/.gemini/GEMINI.md` | 与 Gemini CLI 共用默认全局入口。 |
| 兼容入口 | `~/AGENTS.md` | 自动链接，供手动引用或支持该目录规则的工具使用；不能用它替代各工具的全局入口。 |
| 普通 ChatGPT 网页 / 桌面 / 手机聊天 | 应用内“个性化 → 自定义指令” | 手动粘贴 `CHAT-INSTRUCTIONS.md`，不通过本机指令文件配置。 |
| 普通 Gemini 网页 / 手机聊天 | 应用内 Instructions for Gemini / Saved info（名称与可用性因账号、地区而异） | 手动填写 `CHAT-INSTRUCTIONS.md`，与 Gemini CLI 配置分开。 |

为了避免重复加载，不额外创建 `~/.gemini/AGENTS.md` 或 `~/CLAUDE.md`。
迁移旧安装时，如果 `~/CLAUDE.md` 是指向共享原稿的软链接，脚本会备份并移走；其中有独立内容时保留并提醒检查。
macOS 默认文件系统通常不区分大小写；新配置统一采用工具文档中的大小写，避免在其他文件系统上失效。

项目内的指令、全局规则目录、插件规则及更高优先级的产品指令仍可能影响行为。脚本不会清除这些配置；核对实际加载内容时检查重复和冲突。
不要把全局指令当作权限或安全强制机制。

## 确认会话实际加载

1. **Codex**：新建会话，让它列出加载的指令来源并复述一条独有规则，例如“只有实际执行后才能说我验证了”。需要进一步核实来源时，按官方文档检查该会话的上下文或已启用的会话日志。单纯回答自己“遵守了”不能证明效果。
2. **Claude Code**：新建会话，在 `/memory` 查看加载的指令文件；支持 `/context all` 的版本也可查看 Memory files，确认全局入口。
3. **Gemini CLI**：执行 `/memory reload`，再用 `/memory show` 检查注入的完整内容，确认有新规则且无旧版冲突内容。
4. **Antigravity**：在 Customizations → Rules 检查 Global 规则入口，重新开启会话验证。界面随版本变化，以实际规则面板为准。
5. **ChatGPT / Gemini 普通聊天**：在应用设置中确认保存内容和启用状态，再开新聊天做行为检查。仓库文件更新后需重新粘贴。

文件读取成功与模型能否稳定遵守规则是两件事。可用固定的简单问答、含错误前提的问题、需查证的问题和小型实施任务对照观察。

## 脚本验证

```zsh
zsh -n setup.sh scripts/setup-agents.sh scripts/sync-back.sh
python3 -B -m unittest discover -s tests -v
```

测试在临时目录中验证迁移、备份、重复部署和错误处理，不改动真实用户配置。
`DOTFILES_AGENT_HOME` 用于指定独立部署目录；`CODEX_HOME`、`CLAUDE_CONFIG_DIR` 若已设置仍优先，测试会在子进程中排除这两个覆盖配置。

## 官方依据

- [Codex：AGENTS.md 的全局位置、优先级及加载检查](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Claude Code：CLAUDE.md 的位置、加载与排查](https://code.claude.com/docs/en/memory)
- [Claude Code：CLAUDE_CONFIG_DIR 与用户目录](https://code.claude.com/docs/en/claude-directory)
- [Gemini CLI：GEMINI.md、context.fileName 与 /memory](https://geminicli.com/docs/cli/gemini-md/)
- [Antigravity：Global rules 与适用客户端](https://antigravity.google/docs/rules)
- [ChatGPT：应用内自定义指令设置](https://help.openai.com/en/articles/8096356-chatgpt-custom-instructions)
- [Gemini Apps：用户指令 / Saved info](https://support.google.com/gemini/answer/13594961?hl=en)
