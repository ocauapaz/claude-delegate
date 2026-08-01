# delegate

A Claude Code skill that turns a messy prompt into a clean brief, picks the right depth
tier and the cheapest agent that can do the job, dispatches it, and shows you what it cost.

The point is not "spawn a subagent". Claude Code already does that. The point is that
naive delegation is *expensive* — a subagent re-sends its entire system prompt and its
whole tool-schema block on every turn — and this skill makes the cheap path the default
path.

```
you:      /delegate the login redirect is broken after the session refactor

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

## What it actually does

| | |
|---|---|
| **Refuses cheap work** | Step 0 asks whether delegating is worth it at all. A 10-line edit costs more delegated than done inline — the skill says so and just does it. |
| **Rewrites the prompt** | The subagent has zero conversation context. Your prompt becomes a short standalone brief with the file paths already named, because a vague brief costs far more in a subagent than in your session. |
| **Routes by depth, not by model** | Three tiers — `trivial` / `standard` / `deep`. The model stays pinned; what changes is reasoning effort. |
| **Picks a narrow agent** | `general-purpose`, `Explore` and `Plan` all carry every MCP server you have connected, re-sent every turn. The bundled `delegate-scout` / `delegate-worker` / `delegate-deep` carry none. |
| **Strips MCP entirely on route A** | `claude -p --strict-mcp-config` loads zero MCP servers: measured 17.1k context per turn vs 44.0k with the default config. |
| **Withholds the shell** | A subprocess can't surface a permission prompt, so the subagent gets no `Bash`. It returns the commands it wants run and *your* session runs them, where permissions still work. |
| **Prints the bill** | Every run closes with a card: tokens, turns, cost against budget, wall time. So you can see which route is actually cheaper instead of guessing. |

## Install

Requires [Claude Code](https://claude.com/claude-code).

```bash
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
./install.sh
```

`./install.sh --project` installs into `./.claude` of the current repo instead of
`~/.claude`, if you only want it in one project.

<details>
<summary>Windows PowerShell (no bash)</summary>

```powershell
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
New-Item -ItemType Directory -Force "$HOME\.claude\skills","$HOME\.claude\agents"
Copy-Item -Recurse -Force .\skills\delegate "$HOME\.claude\skills\"
Copy-Item -Force .\agents\delegate-*.md "$HOME\.claude\agents\"
```

</details>

<details>
<summary>Manual — no git</summary>

Download the repo as a zip, then copy:

- `skills/delegate/` → `~/.claude/skills/delegate/`
- `agents/delegate-*.md` → `~/.claude/agents/`

</details>

Restart Claude Code afterwards so it picks up the new skill and agents.

## Usage

```
/delegate <whatever you were about to type>
```

It also fires on plain phrasing — "hand this to a subagent", "get an agent to do this".

Nothing else to learn. The skill decides the tier, the agent and the route; you read the
dispatch block before it runs and the run card after.

If a run comes back thin, say so — the skill re-dispatches one tier up with the failure
output pasted into the brief.

## Configuration

Two knobs, both inside `skills/delegate/SKILL.md`:

- **Default model** (step 2 table) — ships as `opus`, with `haiku` for the `trivial` tier.
  Change either if your plan or budget differs; the rest of the skill doesn't care which
  model it names.
- **`--max-budget-usd`** (step 4) — ships as `2`, a hard ceiling on route A. Raise it for
  deep work, lower it if you want a tighter leash.

The three agent definitions in `agents/` are also plain markdown — edit their `effort`,
`tools` or instructions to taste.

## Routes

**Route A — `claude -p`.** Preferred. A real `--effort` knob, zero MCP schemas, a hard
dollar ceiling, and structured JSON back including full usage data. Requires
`claude auth status` to report `"loggedIn": true`; if not, run `claude setup-token` once.

**Route B — the `Agent` tool.** Fallback. No effort parameter (the skill injects a depth
line into the prompt instead) and no usage data, so the run card reports
`cost: n/a (route B)` rather than guessing.

## Layout

```
skills/delegate/SKILL.md    the skill
agents/delegate-scout.md    read-only investigator     (Read, Grep, Glob, Bash)
agents/delegate-worker.md   scoped implementer         (+ Edit, Write)
agents/delegate-deep.md     high-effort implementer    (+ Edit, Write, more thinking)
install.sh
```

## License

MIT
