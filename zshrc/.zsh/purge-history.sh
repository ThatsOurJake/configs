#!/bin/zsh

# Script to purge entries from $HISTFILE
# Usage: purge-history.sh [--lines <n> | --term <search_term>] [--confirm]

set -e

# Function to display usage
usage() {
    echo "Usage: $0 [--lines <n>] [--term <search_term>] [--confirm]"
    echo ""
    echo "Options:"
    echo "  --lines <n>         Remove the last n lines from history"
    echo "  --term <term>       Remove all entries containing the specified term"
    echo "  --confirm           Actually perform the deletion (runs in dry-run mode by default)"
    echo ""
    echo "Note: --lines and --term can be used together."
    echo "      When both are specified, it removes the last n lines containing the term."
    echo "      The script runs in dry-run mode by default. Use --confirm to actually delete."
    exit 1
}

# Function to clean history line format (removes timestamp prefix)
# Zsh extended history format: : <timestamp>:<elapsed>;<command>
clean_history_line() {
    echo "$1" | sed -E 's/^: [0-9]+:[0-9]+;//'
}

# Check if HISTFILE is set, if not try to determine it
if [[ -z "$HISTFILE" ]]; then
    # Try common zsh history file locations
    if [[ -f "$HOME/.zsh_history" ]]; then
        HISTFILE="$HOME/.zsh_history"
        elif [[ -f "$HOME/.zhistory" ]]; then
        HISTFILE="$HOME/.zhistory"
    else
        echo "Error: \$HISTFILE is not set and could not find history file."
        echo "Please set HISTFILE environment variable or ensure ~/.zsh_history exists."
        exit 1
    fi
fi

# Check if history file exists
if [[ ! -f "$HISTFILE" ]]; then
    echo "Error: History file $HISTFILE does not exist."
    exit 1
fi

# Parse arguments
if [[ $# -eq 0 ]]; then
    usage
fi

LINES_VALUE=""
TERM_VALUE=""
CONFIRM=false

# Parse all arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lines)
            if [[ -z "$2" ]]; then
                echo "Error: --lines requires a value."
                usage
            fi
            LINES_VALUE="$2"
            # Validate that VALUE is a positive integer
            if ! [[ "$LINES_VALUE" =~ ^[0-9]+$ ]] || [[ "$LINES_VALUE" -le 0 ]]; then
                echo "Error: --lines requires a positive integer."
                exit 1
            fi
            shift 2
        ;;
        --term)
            if [[ -z "$2" ]]; then
                echo "Error: --term requires a value."
                usage
            fi
            TERM_VALUE="$2"
            shift 2
        ;;
        --confirm)
            CONFIRM=true
            shift
        ;;
        *)
            echo "Error: Unknown option $1"
            usage
        ;;
    esac
done

# Validate that at least one option was specified
if [[ -z "$LINES_VALUE" ]] && [[ -z "$TERM_VALUE" ]]; then
    echo "Error: At least one of --lines or --term must be specified."
    usage
fi

# Perform the purge operation
TEMP_FILE=$(mktemp)
FILTERED_HIST=$(mktemp)

# Get the script name (handles both full path and just filename)
SCRIPT_NAME=$(basename "$0")

# Filter out any lines containing references to this purge script or its alias
# This prevents the current purge command from being included in the history processing
# Match the script name or 'ph' alias as a complete word at the beginning of the command
grep -v -E "(^|;)(${SCRIPT_NAME}|ph)( |$)" "$HISTFILE" > "$FILTERED_HIST" || cp "$HISTFILE" "$FILTERED_HIST"

# Determine what to remove based on provided options
if [[ -n "$LINES_VALUE" ]] && [[ -n "$TERM_VALUE" ]]; then
    # Both --lines and --term specified: remove last n lines containing the term
    echo "Finding the last $LINES_VALUE lines containing '$TERM_VALUE'..."
    echo ""
    
    # Get all lines containing the term, then take the last n
    MATCHING_LINES=$(grep -F "$TERM_VALUE" "$FILTERED_HIST" | tail -n "$LINES_VALUE")
    
    if [[ -z "$MATCHING_LINES" ]]; then
        echo "(No matching entries found)"
        rm "$TEMP_FILE" "$FILTERED_HIST"
        exit 0
    fi
    
    echo "The following entries will be removed:"
    while IFS= read -r line; do
        clean_history_line "$line"
    done <<< "$MATCHING_LINES"
    echo ""
    
    # Create a temp file with the lines to remove for exact matching
    LINES_TO_REMOVE=$(mktemp)
    echo "$MATCHING_LINES" > "$LINES_TO_REMOVE"
    
    # Remove these exact lines from history
    grep -v -F -f "$LINES_TO_REMOVE" "$FILTERED_HIST" > "$TEMP_FILE" || true
    rm "$LINES_TO_REMOVE"
    
    BEFORE_COUNT=$(wc -l < "$FILTERED_HIST")
    AFTER_COUNT=$(wc -l < "$TEMP_FILE")
    REMOVED_COUNT=$((BEFORE_COUNT - AFTER_COUNT))
    echo "Total entries to remove: $REMOVED_COUNT"
    
    elif [[ -n "$LINES_VALUE" ]]; then
    # Only --lines specified: remove last n lines
    TOTAL_LINES=$(wc -l < "$FILTERED_HIST")
    LINES_TO_KEEP=$((TOTAL_LINES - LINES_VALUE))
    
    if [[ $LINES_TO_KEEP -le 0 ]]; then
        echo "WARNING: This will remove ALL history entries (requested $LINES_VALUE lines, but file only has $TOTAL_LINES lines)."
        echo ""
        > "$TEMP_FILE"
        tail -n "$LINES_VALUE" "$FILTERED_HIST" | while IFS= read -r line; do
            clean_history_line "$line"
        done
    else
        echo "The following $LINES_VALUE lines will be removed:"
        echo ""
        tail -n "$LINES_VALUE" "$FILTERED_HIST" | while IFS= read -r line; do
            clean_history_line "$line"
        done
        echo ""
        head -n "$LINES_TO_KEEP" "$FILTERED_HIST" > "$TEMP_FILE"
    fi
    
    elif [[ -n "$TERM_VALUE" ]]; then
    # Only --term specified: remove all lines containing the search term
    BEFORE_COUNT=$(wc -l < "$FILTERED_HIST")
    echo "The following entries containing '$TERM_VALUE' will be removed:"
    echo ""
    if grep -F "$TERM_VALUE" "$FILTERED_HIST" > /dev/null 2>&1; then
        grep -F "$TERM_VALUE" "$FILTERED_HIST" | while IFS= read -r line; do
            clean_history_line "$line"
        done
    else
        echo "(No matching entries found)"
    fi
    echo ""
    grep -v -F "$TERM_VALUE" "$FILTERED_HIST" > "$TEMP_FILE" || true
    AFTER_COUNT=$(wc -l < "$TEMP_FILE")
    REMOVED_COUNT=$((BEFORE_COUNT - AFTER_COUNT))
    
    echo "Total entries to remove: $REMOVED_COUNT"
fi

# Check if running in dry-run mode
if [[ "$CONFIRM" == false ]]; then
    echo ""
    echo "=== DRY RUN MODE ==="
    echo "No changes have been made to your history file."
    echo "To actually perform this deletion, run the command again with --confirm flag."
    rm "$TEMP_FILE" "$FILTERED_HIST"
    exit 0
fi

# If we get here, user confirmed - perform the actual deletion
echo ""
echo "=== PERFORMING DELETION ==="

# Replace the original history file
mv "$TEMP_FILE" "$HISTFILE"
rm "$FILTERED_HIST"

# Reload the history file in the current session
echo "Reloading history..."
fc -R "$HISTFILE"

echo "History purge complete!"
