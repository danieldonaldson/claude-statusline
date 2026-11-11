#!/usr/bin/env bash
# Install the statusline + wakeup hook into a Claude Code config dir.
# Symlinks files from this repo (so `git pull` updates them) and merges the
# required entries into settings.json without touching anything else.
#
#   ./install.sh                 # installs into ${CLAUDE_CONFIG_DIR:-~/.claude}
#   CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$cfg/settings.json"

for dep in jq bc git; do
    command -v "$dep" >/dev/null || { echo "missing dependency: $dep" >&2; exit 1; }
done

mkdir -p "$cfg/hooks"

link() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
        echo "backed up existing $dst"
    fi
    ln -sfn "$src" "$dst"
    echo "linked $dst -> $src"
}

link "$repo/statusline-command.sh"   "$cfg/statusline-command.sh"
link "$repo/hooks/wakeup-marker.sh"  "$cfg/hooks/wakeup-marker.sh"

[ -f "$settings" ] || echo '{}' > "$settings"

status_cmd="bash $cfg/statusline-command.sh"
hook_cmd="bash '$cfg/hooks/wakeup-marker.sh'"

new=$(jq --arg sc "$status_cmd" --arg hc "$hook_cmd" '
    .statusLine = ((.statusLine // {}) + {type: "command", command: $sc})
  | .statusLine.refreshInterval //= 30
  | .hooks //= {}
  | .hooks.PostToolUse //= []
  | if any(.hooks.PostToolUse[]?.hooks[]?; .command == $hc) then .
    else .hooks.PostToolUse += [{matcher: "^ScheduleWakeup$",
                                 hooks: [{type: "command", command: $hc, timeout: 5}]}]
    end
' "$settings")

if [ "$new" = "$(jq . "$settings")" ]; then
    echo "settings.json already configured"
else
    cp "$settings" "$settings.bak.$(date +%Y%m%d%H%M%S)"
    printf '%s\n' "$new" > "$settings"
    echo "updated $settings (backup saved alongside)"
fi

echo "done — restart Claude Code (or start a new session) to pick up the hook"
