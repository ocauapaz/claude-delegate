---
name: delegate
description: Take a raw/messy user prompt, rewrite it into a clean agent-ready brief, infer the right model + depth tier, and dispatch it to a subagent. Use when the user invokes /delegate or asks to hand the work to a subagent.
---

# Delegate

Raw prompt in → improved brief + routed subagent out. One dispatch, no ceremony.

> **Tunables.** Two things in this file are opinions, not laws: the default model
> (`opus`, step 2) and the token-budget ceiling (`--max-budget-usd`, step 4).
> Edit them to match your plan. Everything else is mechanics.

## Step 0: is delegating worth it?

A subagent re-sends the full inherited system prompt **and its whole tool schema block on
every turn it takes**. That overhead dwarfs the actual work on small tasks — a 10-line edit
delegated to a `tools: *` agent can cost more than an hour of working in this session.

Delegate only when at least one holds:
- the work is genuinely wide (several independent scopes, or a sweep across many files)
- it would otherwise dump far more into this context than the answer needs
- the user explicitly asked for a subagent

Otherwise say so in one line and just do it here. This is the single biggest cost lever in
the skill — do not skip it because the user typed `/delegate`.

## Steps

### 1. Rewrite the prompt

Turn what the user wrote into a short English brief. The subagent starts with **zero**
conversation context, so make the implicit explicit — but keep it light.

Lean, not exhaustive. Goal, scope, what to return — prose, no headers, no checklists,
no templates. Length follows the task: a one-line ask stays one line.

Cut anything the agent can find on its own: rules already in the repo's `AGENTS.md` /
`CLAUDE.md` (one line, "follow AGENTS.md", covers all of it), file contents it will read
anyway, background it can grep for. Brief it like a competent teammate, not a ticket.

**Name the files.** Every exploratory turn a subagent takes re-sends its whole context, so
a vague brief costs far more than a vague prompt does here. If you already know the paths,
put them in the brief — that turns a 15-turn sweep into a 3-turn edit. If you don't know
them, grep for them yourself first; that search is cheap in this session and expensive in
a subagent's.

Do **not** invent requirements the user did not ask for. Ambiguity that changes the
outcome → ask the user before dispatching. Ambiguity that doesn't → one-line assumption.

### 2. Pick the tier

**The default model is `opus`.** What varies between tiers is depth, not the model — the
only exception is the `trivial` tier. If your plan or budget calls for a different default,
change it in the table below; the rest of the skill does not care which model it is.

| Signal | Tier | `model` | Depth line to inject |
|---|---|---|---|
| Extremely simple and fully specified — rename, doc tweak, one grep-and-report, a mechanical find/replace where the target is already named | **trivial** | `haiku` | "Be direct. Do the named change and stop. Do not explore." |
| Normal feature, bug fix, refactor within a known subsystem, focused review | **standard** | `opus` | *(none)* |
| Cross-cutting, architecture, gnarly race/sync bug, security, unclear root cause | **deep** | `opus` | "Think hard. Trace the full flow before editing; verify the root cause, not the symptom." |

`trivial` has to earn it: the task is unambiguous **and** you already know the exact file.
Any doubt → `standard`. Between `standard` and `deep`, ties go to `standard`; escalate on a
second pass if it comes back thin.

### 3. Pick the agent type

The built-in types are expensive: `general-purpose` is `tools: *`, and `Explore`/`Plan` are
"all tools except Edit/Write" — so **all of them** re-send the schema of every MCP server
you have connected, on every turn the agent takes. With a handful of servers attached that
is tens of thousands of tokens per turn, paid again and again.

Use the narrow definitions that ship with this skill instead:

| Need | `subagent_type` | tools |
|---|---|---|
| Read-only: find code, trace a flow, answer "where is X" | `delegate-scout` | Read, Grep, Glob, Bash |
| Scoped change in a known subsystem | `delegate-worker` | + Edit, Write |
| Cross-cutting, unclear root cause, race/sync, security | `delegate-deep` | + Edit, Write |

They live in `~/.claude/agents/` and carry no MCP tools. Reach for a built-in type **only**
when the task genuinely needs an MCP tool (browser, design tool, database, issue tracker) —
and say why.

### 4. Dispatch

Two routes. Preflight once per session with `claude auth status` — if it returns
`"loggedIn": true`, take route A; otherwise route B.

**Route A — `claude -p` (preferred).** The only route with a real effort knob and no MCP
schemas at all. One `Bash` call:

```bash
claude -p "<brief>" --model opus --effort <low|medium|high> \
  --strict-mcp-config --tools "Read,Edit,Write,Grep,Glob" \
  --allowedTools "Edit Write" \
  --json-schema '{"type":"object","properties":{"changed":{"type":"array","items":{"type":"string"}},"commands_to_run":{"type":"array","items":{"type":"string"}},"notes":{"type":"string"}},"required":["changed","commands_to_run"]}' \
  --max-budget-usd 2 --output-format json --no-session-persistence \
  --exclude-dynamic-system-prompt-sections
```

- `--effort` takes the tier from step 2 directly — no depth line needed.
- `--tools` mirrors the step-3 table; drop `Edit,Write` for read-only work.
- `--strict-mcp-config` with no `--mcp-config` loads zero MCP servers. This is the flag
  that kills the cost: on a session with several MCP servers connected, measured 17.1k
  context per turn versus 44.0k with the default config. On a one-turn job that is ~18%
  cheaper; across a 15-turn agent it is 27k extra tokens re-read *every turn*.
- `--max-budget-usd` is a hard ceiling — raise it for `deep`, keep it low for `trivial`.
- Long jobs → `run_in_background: true`. Read `.result` out of the JSON.

**Bash is deliberately absent from `--tools`.** A subprocess cannot surface a permission
prompt, so anything it could run would either be silently denied or silently allowed —
neither is acceptable for shell commands. Instead the subagent edits files and *returns*
the commands it wants run, and **this thread runs them**, where the normal permission UI
applies. Tell it so in the brief: "You have no shell. Put every command you would run to
validate your change into `commands_to_run`."

`--allowedTools "Edit Write"` pre-approves only those two tools. Keep the list to exactly
that — do not add `Bash` to it, and do not reach for `--permission-mode`; both would hand
the subprocess unattended shell access and defeat the design above.

**Route B — `Agent` tool (fallback, and the default for anything that writes).**
`subagent_type` from step 3, `model`, the rewritten brief as `prompt`, `description` = 3-5
words. Effort falls back to the depth line from step 2. Parallel independent scopes →
multiple `Agent` calls in **one** message. Use `isolation: "worktree"` only when several
agents write files concurrently.

If route A fails on auth, don't retry it — fall to route B and tell the user to run
`claude setup-token` once.

**Always** show the user what was dispatched — every time, one block per agent, no
exceptions and no summarizing the brief away:

```
agent:  delegate-worker
model:  opus
effort: deep — "Think hard. Trace the full flow before editing..."
prompt:
<the rewritten brief, verbatim, exactly as sent>
```

`effort` names the tier plus the depth line actually injected (or `standard — none`).

Then dispatch — don't wait for approval unless the brief required an assumption you're
unsure about.

### 5. Report back

**Route A: run its `commands_to_run` here.** That is the whole point of withholding Bash —
the subagent edited blind and has not verified anything. Run the validation commands in
this thread, where permissions work. Drop any command that is unrelated to validating the
change (git writes, installs, deletes) and say you dropped it. If a check fails, fix it
inline when it's small, or re-dispatch with the failure output pasted into the brief.

Then relay the outcome, not the transcript — the subagent's report is not shown to the
user. Report what changed, what you ran, and what came back red. If it came back thin or
wrong, say so plainly and offer a re-dispatch one tier up.

### 6. Always close with the run card

One block, last thing in the response, every time — what you dispatched *and* what it
cost, together. Repeating the routing here is deliberate: the numbers are only readable
next to the settings that produced them.

```
route:  A (claude -p)
agent:  delegate-worker · tools Read,Edit,Write,Grep,Glob
model:  opus · effort high
tokens: 14 in · 17.2k cache write · 24.2k cache read · 65 out · 7 turns
cost:   $0.42 of $2.00 budget · 1m 12s
```

On route B, `agent:` is the `subagent_type` and `effort:` is the tier plus the depth line
that was injected (or `standard — none`).

Pull from the result object: `usage.input_tokens`, `usage.cache_creation_input_tokens`,
`usage.cache_read_input_tokens`, `usage.output_tokens`, `num_turns`, `total_cost_usd`,
`duration_ms`, against the `--max-budget-usd` you set. Extract with `python -c` on the
piped JSON rather than eyeballing it.

Flag it in one line when something looks off — turns much higher than the task warranted,
cost near the budget ceiling, or a `permission_denials` array that isn't empty (that means
the subagent tried something the allowlist blocked and may have silently given up on it).

Route B gives no usage data back. Say `cost: n/a (route B)` rather than guessing or
omitting the line — the whole point is that you can see which route is actually cheaper.

## Limits

- The `Agent` tool has no `effort` parameter — on route B the depth line from step 2 is the
  only substitute. Route A's `--effort` is the real thing. `Workflow` also has per-call
  `effort`, but needs the user's explicit opt-in.
- If the repo's own rules say subagents are opt-in, this skill IS that opt-in. Don't
  delegate outside of it.
