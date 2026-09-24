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

# Newer Codex CLIs log several limit types (limit_id "codex" is the account
# limit; others, e.g. "codex_bengalfox", are separate model quotas like
# GPT-Codex-Spark). Emit the newest line PER limit_id, account limit first.
# Legacy lines without limit_id count as the account limit.
OUT=$(for f in $FILES; do
    tail -c 262144 "$f" 2>/dev/null | grep '"rate_limits"' | tac
done | awk '
{
    id = "codex"
    if (match($0, /"limit_id"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        id = substr($0, RSTART, RLENGTH)
        sub(/^"limit_id"[[:space:]]*:[[:space:]]*"/, "", id)
        sub(/"$/, "", id)
    }
    # Pick the newest snapshot per limit by its own timestamp, not by file
    # order: resuming an old session touches its file before it logs a new
    # snapshot, so a recently modified file can still hold a weeks-old value.
    ts = ""
    if (match($0, /"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        ts = substr($0, RSTART, RLENGTH)
        sub(/^"timestamp"[[:space:]]*:[[:space:]]*"/, "", ts)
        sub(/"$/, "", ts)
    }
    if (!(id in seen)) {
        order[n++] = id
        seen[id] = $0
        best[id] = ts
    } else if (ts > best[id]) {
        seen[id] = $0
        best[id] = ts
    }
}
END {
    if ("codex" in seen) print seen["codex"]
    for (i = 0; i < n; i++) if (order[i] != "codex") print seen[order[i]]
}')

if [ -n "$OUT" ]; then
    printf '%s\n' "$OUT"
    exit 0
fi

echo "NODATA"
