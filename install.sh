#!/usr/bin/env bash
# Install the delegate skill + its narrow agents into Claude Code.
#   ./install.sh              -> ~/.claude          (all projects)
#   ./install.sh --project    -> ./.claude          (this repo only)
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$HOME/.claude"
[ "${1:-}" = "--project" ] && dest="$PWD/.claude"

mkdir -p "$dest/skills" "$dest/agents"
cp -r "$src/skills/delegate" "$dest/skills/"
cp "$src"/agents/delegate-*.md "$dest/agents/"

echo "installed -> $dest"
echo "  skills/delegate/SKILL.md"
echo "  agents/delegate-scout.md delegate-worker.md delegate-deep.md"
echo "restart Claude Code, then run /delegate"
