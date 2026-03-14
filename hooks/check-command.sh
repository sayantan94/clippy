#!/bin/bash
# Clippy PreToolUse hook for Claude Code
# Reads rules dynamically from ~/.clippy/rules.yaml (or .clippy/rules.yaml in project)
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude as feedback)
# Logs all activity to ~/.clippy/activity.jsonl

CLIPPY_HOME="${CLIPPY_HOME:-$HOME/.clippy}"
RULES_FILE="$CLIPPY_HOME/rules.yaml"
LOGFILE="$CLIPPY_HOME/activity.jsonl"
mkdir -p "$CLIPPY_HOME"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
SESSION=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROJECT=$(basename "$CWD" 2>/dev/null || echo "unknown")

if [ -z "$COMMAND" ]; then
    exit 0
fi

# Use local project rules if they exist, otherwise global
if [ -n "$CWD" ] && [ -f "$CWD/.clippy/rules.yaml" ]; then
    RULES_FILE="$CWD/.clippy/rules.yaml"
fi

# Deduplicate: skip if same command is already being processed (global + project hooks)
CMD_HASH=$(echo "${SESSION}:${COMMAND}" | shasum | cut -d' ' -f1)
LOCK_DIR="$CLIPPY_HOME/.lock_${CMD_HASH}"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi
# Clean up lock after a short delay (in background)
(sleep 1 && rmdir "$LOCK_DIR" 2>/dev/null) &

log_event() {
    local severity="$1"
    local rule="$2"
    local action="$3"
    printf '{"ts":"%s","session":"%s","project":"%s","cwd":"%s","tool":"%s","severity":"%s","rule":"%s","action":"%s","command":"%s"}\n' \
        "$TIMESTAMP" "$SESSION" "$PROJECT" "$CWD" "$TOOL" "$severity" "$rule" "$action" \
        "$(echo "$COMMAND" | head -c 200 | sed 's/"/\\"/g')" >> "$LOGFILE"
}

# If no rules file, allow everything
if [ ! -f "$RULES_FILE" ]; then
    log_event "none" "-" "allowed"
    exit 0
fi

# Parse rules from YAML and check command against each one
# Format: name, pattern, severity, description — parsed line by line
CURRENT_NAME=""
CURRENT_PATTERN=""
CURRENT_SEVERITY=""
CURRENT_DESC=""

check_rule() {
    if [ -n "$CURRENT_NAME" ] && [ -n "$CURRENT_PATTERN" ]; then
        if echo "$COMMAND" | grep -qE "$CURRENT_PATTERN"; then
            case "$CURRENT_SEVERITY" in
                critical)
                    log_event "critical" "$CURRENT_NAME" "blocked"
                    echo "🚨 CLIPPY BLOCKED: ${CURRENT_DESC:-$CURRENT_NAME}" >&2
                    echo "   This action has been blocked by clippy-guard safety rules." >&2
                    echo "   Edit rules: $RULES_FILE" >&2
                    exit 2
                    ;;
                warning)
                    log_event "warning" "$CURRENT_NAME" "warned"
                    echo "⚠️  CLIPPY WARNING: ${CURRENT_DESC:-$CURRENT_NAME}" >&2
                    exit 0
                    ;;
                info)
                    log_event "info" "$CURRENT_NAME" "info"
                    echo "ℹ️  CLIPPY: ${CURRENT_DESC:-$CURRENT_NAME}" >&2
                    exit 0
                    ;;
            esac
        fi
    fi
}

while IFS= read -r line; do
    # Stop at ai_tools section
    if echo "$line" | grep -q '^ai_tools:'; then
        check_rule
        break
    fi

    # Match rule fields
    name=$(echo "$line" | sed -n 's/^[[:space:]]*-[[:space:]]*name:[[:space:]]*//p')
    if [ -n "$name" ]; then
        check_rule
        CURRENT_NAME="$name"
        CURRENT_PATTERN=""
        CURRENT_SEVERITY=""
        CURRENT_DESC=""
        continue
    fi

    pattern=$(echo "$line" | sed -n 's/^[[:space:]]*pattern:[[:space:]]*"\(.*\)"/\1/p' | sed 's/\\\\/\\/g')
    if [ -n "$pattern" ]; then
        CURRENT_PATTERN="$pattern"
        continue
    fi

    severity=$(echo "$line" | sed -n 's/^[[:space:]]*severity:[[:space:]]*//p')
    if [ -n "$severity" ]; then
        CURRENT_SEVERITY="$severity"
        continue
    fi

    desc=$(echo "$line" | sed -n 's/^[[:space:]]*description:[[:space:]]*"\(.*\)"/\1/p')
    if [ -n "$desc" ]; then
        CURRENT_DESC="$desc"
        continue
    fi
done < "$RULES_FILE"

# Check the last rule
check_rule

# No rule matched — allow
log_event "none" "-" "allowed"
exit 0
