[English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · **简体中文**

# delegate

一个 Claude Code skill：把杂乱的提示词改写成干净的任务简报，选出合适的深度档位和能完成
这项工作的最便宜的 agent，派发出去，并告诉你这次花了多少钱。

重点不是"开一个子 agent"——Claude Code 本来就能做。重点是天真地委派非常*昂贵*：子 agent
每一轮都会重新发送完整的 system prompt 和整块工具 schema。这个 skill 让省钱的那条路成为
默认路径。

```
你：      /delegate 会话重构之后登录跳转坏了

claude:   agent:  delegate-deep
          model:  opus
          effort: deep — "Think hard. Trace the full flow before editing..."
          prompt:
          Fix the post-login redirect regression introduced by the session refactor.
          Start at src/auth/session.ts and src/routes/login.tsx. Follow AGENTS.md.
          You have no shell — put validation commands into `commands_to_run`.

          ...

          route:  A (claude -p)
          agent:  delegate-deep · tools Read,Edit,Write,Grep,Glob
          model:  opus · effort high
          tokens: 14 in · 17.2k cache write · 24.2k cache read · 65 out · 7 turns
          cost:   $0.42 of $2.00 budget · 1m 12s
```

## 它到底做了什么

| | |
|---|---|
| **拒绝不值得的委派** | 第 0 步先问委派是否划算。十行的改动委派出去比就地完成更贵——skill 会直接说明并自己动手。 |
| **改写提示词** | 子 agent 没有任何对话上下文。你的提示会变成一份简短、可独立阅读的简报，并且已经写明文件路径：模糊的简报在子 agent 里的代价远高于在你的会话里。 |
| **按深度而非模型分流** | 三个档位——`trivial` / `standard` / `deep`。模型固定，变化的是推理强度。 |
| **挑选工具面窄的 agent** | `general-purpose`、`Explore` 和 `Plan` 会携带你连接的每一个 MCP server，并在每一轮重新发送。内置的 `delegate-scout` / `delegate-worker` / `delegate-deep` 一个都不带。 |
| **路线 A 完全剥离 MCP** | `claude -p --strict-mcp-config` 不加载任何 MCP server：实测每轮 17.1k 上下文，而默认配置为 44.0k。 |
| **不给 shell** | 子进程无法弹出权限确认，所以子 agent 拿不到 `Bash`。它把想执行的命令返回出来，由*你的*会话执行——那里权限机制照常生效。 |
| **打印账单** | 每次运行都以一张卡片收尾：token、轮数、相对预算的花费、耗时。于是你能看清哪条路线真的更便宜，而不是靠猜。 |

## 安装

需要 [Claude Code](https://claude.com/claude-code)。

```bash
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
./install.sh
```

`./install.sh --project` 会装到当前仓库的 `./.claude` 而不是 `~/.claude`，适合只在单个
项目里使用。

<details>
<summary>Windows PowerShell（没有 bash）</summary>

```powershell
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
New-Item -ItemType Directory -Force "$HOME\.claude\skills","$HOME\.claude\agents"
Copy-Item -Recurse -Force .\skills\delegate "$HOME\.claude\skills\"
Copy-Item -Force .\agents\delegate-*.md "$HOME\.claude\agents\"
```

</details>

<details>
<summary>手动安装——不用 git</summary>

下载仓库 zip 包，然后复制：

- `skills/delegate/` → `~/.claude/skills/delegate/`
- `agents/delegate-*.md` → `~/.claude/agents/`

</details>

之后重启 Claude Code，让它加载新的 skill 和 agent。

## 用法

```
/delegate <你本来要写的内容>
```

日常说法也能触发——"交给子 agent 做"、"让个 agent 处理这个"。

没有别的要学。档位、agent 和路线都由 skill 决定；你只需在派发前看派发块，运行后看运行卡片。

如果结果太单薄，直说——skill 会把失败输出贴进简报，升一档重新派发。

## 配置

两个旋钮，都在 `skills/delegate/SKILL.md` 里：

- **默认模型**（第 2 步的表格）——默认是 `opus`，`trivial` 档用 `haiku`。如果你的套餐或预算
  不同就改掉；skill 的其余部分并不关心具体是哪个模型。
- **`--max-budget-usd`**（第 4 步）——默认是 `2`，是路线 A 的硬上限。做深度工作可以调高，想
  勒紧一点就调低。

`agents/` 里的三个 agent 定义同样是纯 markdown——`effort`、`tools` 和指令都可以随意改。

## 两条路线

**路线 A —— `claude -p`。** 首选。有真正的 `--effort` 开关、零 MCP schema、硬性美元上限，
并返回带完整用量数据的结构化 JSON。需要 `claude auth status` 返回 `"loggedIn": true`；
否则先执行一次 `claude setup-token`。

**路线 B —— `Agent` 工具。** 兜底方案。没有 effort 参数（skill 改为在提示里注入一行深度
指令），也没有用量数据，所以运行卡片会写 `cost: n/a (route B)` 而不是瞎猜。

## 目录结构

```
skills/delegate/SKILL.md    skill 本体
agents/delegate-scout.md    只读调查员          (Read, Grep, Glob, Bash)
agents/delegate-worker.md   限定范围的实现者     (+ Edit, Write)
agents/delegate-deep.md     高强度推理实现者     (+ Edit, Write，更多思考)
install.sh
```

## 许可证

MIT
