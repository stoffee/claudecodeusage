#!/bin/sh
# Runs the hook script embedded in SessionMonitor.swift against fixtures and
# checks the lane / herdr_tab_id it records. No Swift build needed.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

awk '/static let hookScript = #"""/{f=1; next} /^    """#/{f=0} f' "$ROOT/ClaudeUsage/SessionMonitor.swift" \
  | sed 's/^    //' > "$T/hook.sh"
chmod +x "$T/hook.sh"

fail=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}
field() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" "$T/home/.claude/claudeusage/sessions/s1.json"; }
event() { printf '{"session_id":"s1","hook_event_name":"UserPromptSubmit","cwd":"%s"}' "$1"; }
hook() { env -i HOME="$T/home" PATH=/usr/bin:/bin "$@" "$T/hook.sh"; }

mkdir -p "$T/one/.claude" "$T/multi/.claude" "$T/none" "$T/crlf/.claude"
printf 'sysop\n' > "$T/one/.claude/bbs-agent"
printf '# seats in this repo\nhashistack\ncamera-detection  # the cams\nvault-for-claude\n' > "$T/multi/.claude/bbs-agent"
printf 'sysop\r\n' > "$T/crlf/.claude/bbs-agent"

event "$T/none"  | hook BBS_AGENT=speedy HERDR_TAB_ID=w1:t3
check "BBS_AGENT is authoritative"     speedy "$(field lane)"
check "herdr tab id is recorded"       w1:t3  "$(field herdr_tab_id)"

event "$T/one"   | hook BBS_AGENT=speedy
check "BBS_AGENT beats bbs-agent file" speedy "$(field lane)"

event "$T/one"   | hook
check "single-seat file is used"       sysop  "$(field lane)"

event "$T/multi" | hook
check "multi-seat file gives no lane"  ""     "$(field lane)"

event "$T/none"  | hook
check "nothing gives no lane"          ""     "$(field lane)"
check "no herdr gives no tab id"       ""     "$(field herdr_tab_id)"

event "$T/crlf" | hook
check "CRLF single-seat file is used"   sysop  "$(field lane)"
check "CRLF sidecar is valid JSON"      valid  "$(/usr/bin/python3 -c 'import json,sys; json.load(open(sys.argv[1])); print("valid")' "$T/home/.claude/claudeusage/sessions/s1.json" 2>/dev/null)"

exit $fail
