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

# Search for the last ACCOUNT rate_limits line in each file (newest first).
# Newer Codex CLIs log several limit types (e.g. limit_id "codex_bengalfox"
# for the separate GPT-Codex-Spark quota) — only limit_id "codex" is the
# account limit. Older CLIs have no limit_id at all.
for f in $FILES; do
    CAND=$(tail -c 262144 "$f" 2>/dev/null | grep '"rate_limits"')
    [ -n "$CAND" ] || continue
    LINE=$(printf '%s\n' "$CAND" | grep '"limit_id"[[:space:]]*:[[:space:]]*"codex"' | tail -1)
    if [ -z "$LINE" ]; then
        LINE=$(printf '%s\n' "$CAND" | grep -v '"limit_id"' | tail -1)
    fi
    if [ -n "$LINE" ]; then
        echo "$LINE"
        exit 0
    fi
done

echo "NODATA"
