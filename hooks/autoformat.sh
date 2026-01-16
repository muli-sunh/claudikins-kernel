#!/bin/bash
# autoformat.sh - PostToolUse hook for claudikins-kernel
# Runs prettier on edited/written files (Boris's pattern)
#
# Only formats files that prettier supports. Fails silently if prettier
# not installed or file type not supported.

set -euo pipefail

# Don't fail the hook if prettier isn't available
trap 'exit 0' ERR

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Read input from stdin
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Make path absolute if relative
if [[ "$FILE_PATH" != /* ]]; then
    FILE_PATH="$PROJECT_DIR/$FILE_PATH"
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Only format supported file types
case "$EXT" in
    js|jsx|ts|tsx|json|md|mdx|css|scss|less|html|yaml|yml|graphql|vue|svelte)
        # Check if prettier is available
        if command -v npx &> /dev/null; then
            # Run prettier with --write, ignore errors (unsupported files, etc.)
            npx prettier --write "$FILE_PATH" 2>/dev/null || true
        elif command -v prettier &> /dev/null; then
            prettier --write "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
    *)
        # Unsupported file type, skip silently
        ;;
esac

exit 0
