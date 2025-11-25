#!/usr/bin/env bash
################################################################################
# Script Name: fix-compliance-batch.sh
# Description: Batch fix compliance issues across all scripts
# Platform: macOS
################################################################################

set -euo pipefail

echo "=== Fixing Script Compliance Issues ==="
echo

# Fix shebang lines
echo "1. Fixing shebang lines..."
find . -type f -name "*.sh" ! -path "*/.*" -exec sed -i '' '1s|^#!/bin/bash$|#!/usr/bin/env bash|' {} \;
echo "   ✓ Updated shebangs to #!/usr/bin/env bash"

# Add set -euo pipefail where missing (after shebang, before any other code)
echo "2. Adding error handling (set -euo pipefail)..."
for script in $(find . -type f -name "*.sh" ! -path "*/.*" ! -path "*/lib/*"); do
    # Skip if already has error handling
    if grep -q "set -euo pipefail\|set -eo pipefail" "$script" 2>/dev/null; then
        continue
    fi
    
    # Skip if it's bu.sh or mu.sh (they intentionally don't exit on error)
    if [[ "$script" =~ (bu|mu)\.sh$ ]]; then
        continue
    fi
    
    # Find first non-comment, non-shebang line and add set -euo pipefail before it
    awk '
        BEGIN { added = 0 }
        /^#!/ { print; next }
        /^[[:space:]]*#/ && added == 0 { print; next }
        /^[[:space:]]*$/ && added == 0 { print; next }
        added == 0 {
            print ""
            print "set -euo pipefail"
            print ""
            added = 1
        }
        { print }
    ' "$script" > "$script.tmp" && mv "$script.tmp" "$script"
    
    echo "   ✓ Added to $(basename "$script")"
done

echo
echo "=== Compliance fixes applied ==="
echo "Next steps:"
echo "1. Review changes with: git diff"
echo "2. Test scripts: bash -n script.sh"
echo "3. Run shellcheck on modified scripts"
echo "4. Commit changes"

