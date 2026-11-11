#!/usr/bin/env bash
# PostToolUse hook for ScheduleWakeup: records the pending wakeup so the
# statusline (statusline-command.sh) can show "⏰ <countdown>" and the reason.
# File format, one line: <wake_epoch>\t<reason>
# The statusline deletes the file once the time has passed.

input=$(cat)
marker="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/next-wakeup"

stop=$(jq -r '.tool_input.stop // false' <<<"$input" 2>/dev/null)
if [ "$stop" = "true" ]; then
    rm -f "$marker"
    exit 0
fi

delay=$(jq -r '.tool_input.delaySeconds // empty' <<<"$input" 2>/dev/null)
reason=$(jq -r '.tool_input.reason // "" | gsub("[\t\n]"; " ")' <<<"$input" 2>/dev/null)
[ -z "$delay" ] && exit 0

# Runtime clamps the delay to [60, 3600]; mirror that.
delay=${delay%.*}
[ "$delay" -lt 60 ] 2>/dev/null && delay=60
[ "$delay" -gt 3600 ] 2>/dev/null && delay=3600

printf '%s\t%s\n' "$(( $(date +%s) + delay ))" "$reason" > "$marker"
exit 0
