#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Extract task number from first line of current-task.md
FIRST_LINE=$(head -n 1 current-task.md)
TASK_NUM=$(echo "$FIRST_LINE" | sed 's/# Task //')

if ! [[ "$TASK_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: Could not parse task number from '$FIRST_LINE'"
    exit 1
fi

# Get version from status.md
VERSION=$(grep '^Version:' status.md | sed 's/Version: //')

if [ -z "$VERSION" ]; then
    echo "Error: Could not find version in status.md"
    exit 1
fi

# Ensure archive directory exists
mkdir -p "archive/$VERSION"

# Move current task to archive
mv current-task.md "archive/$VERSION/task-$TASK_NUM.md"
echo "Archived: archive/$VERSION/task-$TASK_NUM.md"

# Calculate next task number
NEXT_NUM=$((TASK_NUM + 1))

# Create new current-task.md
cat > current-task.md << EOF
# Task $NEXT_NUM
Not defined yet.
EOF

# Update TaskNr in status.md
sed -i "s/^TaskNr: .*/TaskNr: $NEXT_NUM/" status.md

echo "Created: current-task.md (Task $NEXT_NUM)"
