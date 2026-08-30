#!/bin/sh
# Read the latest Codex CLI rate-limit snapshot from local session logs.
# No network calls — everything comes from ~/.codex/sessions/.
#
# Output: JSON with usage data, or "NODATA" if no logs found.

CODEX_DIR="${CODEX_CONFIG_DIR:-$HOME/.codex}"
SESSIONS="$CODEX_DIR/sessions"

if [ ! -d "$SESSIONS" ]; then
    echo "NODATA"
    exit 0
fi

# Find the 5 most recently modified .jsonl files
FILES=$(find "$SESSIONS" -name '*.jsonl' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-)

if [ -z "$FILES" ]; then
    echo "NODATA"
    exit 0
fi

# Search for the last rate_limits line in each file (newest first)
for f in $FILES; do
    LINE=$(tail -c 262144 "$f" 2>/dev/null | grep '"rate_limits"' | tail -1)
    if [ -n "$LINE" ]; then
        echo "$LINE"
        exit 0
    fi
done

echo "NODATA"
