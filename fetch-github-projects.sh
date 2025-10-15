#!/bin/bash
# -----------------------------------------------------------------------------
# Quiet GitHub fetcher — updates all repos in a directory with minimal output
# -----------------------------------------------------------------------------

set -euo pipefail

TARGET_DIR="${1:-$HOME/GitHub}"
start_time=$(date +%s)

echo "Updating all Git repositories in: $TARGET_DIR"
echo

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi

cd "$TARGET_DIR"

for dir in */; do
    if [ -d "$dir/.git" ]; then
        pushd "$dir" > /dev/null

        # Detect default branch
        DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
        if [ -z "$DEFAULT_BRANCH" ]; then
            if git show-ref --quiet refs/heads/main; then
                DEFAULT_BRANCH="main"
            elif git show-ref --quiet refs/heads/master; then
                DEFAULT_BRANCH="master"
            else
                DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            fi
        fi

        # Run pull quietly, only showing actual changes or errors
        OUTPUT=$(git pull origin "$DEFAULT_BRANCH" 2>&1)
        STATUS=$?

        if [ $STATUS -eq 0 ]; then
            # Only print repo name if something changed
            if ! grep -q "Already up to date" <<< "$OUTPUT"; then
                echo "✅ ${dir%/}: updated ($DEFAULT_BRANCH)"
            else
                echo "• ${dir%/}: up to date"
            fi
        else
            echo "⚠️  ${dir%/}: pull failed ($DEFAULT_BRANCH)"
            echo "$OUTPUT" | sed 's/^/   /'
        fi

        popd > /dev/null
    fi
done

end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo
echo "Finished updating all repositories in ${execution_time}s."
