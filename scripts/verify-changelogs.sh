#!/bin/bash
# Script to verify changelog extraction and hosting

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHANGELOG_DIR="$REPO_DIR/changelogs"

echo "Verifying changelog hosting..."
echo "================================"

# Count total changelogs
total_changelogs=$(find "$CHANGELOG_DIR" -name "changelog" -type f 2>/dev/null | wc -l)
echo "Total changelogs extracted: $total_changelogs"
echo ""

# List all packages with changelogs
echo "Packages with changelogs:"
echo "-------------------------"
find "$CHANGELOG_DIR" -name "changelog" -type f 2>/dev/null | while read -r changelog; do
    # Extract package info from path
    pkg_path=$(dirname "$changelog")
    pkg_version=$(basename "$pkg_path")
    pkg_name=$(basename "$(dirname "$pkg_path")")
    
    # Check for compressed version
    if [ -f "${changelog}.gz" ]; then
        compressed="✓"
    else
        compressed="✗"
    fi
    
    # Get changelog size
    size=$(stat -c%s "$changelog" 2>/dev/null || echo "0")
    
    echo "  - $pkg_name ($pkg_version) - ${size} bytes - compressed: $compressed"
    
    # Show first line of changelog
    first_line=$(head -n1 "$changelog")
    echo "    First entry: $first_line"
done

echo ""
echo "Verification complete!"
