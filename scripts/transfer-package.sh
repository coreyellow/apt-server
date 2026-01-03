#!/bin/bash
set -e

# Script to transfer a specific version of a package from test to stable
# This script copies the .deb file and its associated changelog files
# Usage: transfer-package.sh <package-name> <version>

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_NAME="$1"
VERSION="$2"

if [ -z "$PACKAGE_NAME" ] || [ -z "$VERSION" ]; then
    echo "Error: Package name and version are required"
    echo "Usage: $0 <package-name> <version>"
    exit 1
fi

echo "================================================================"
echo "Package Transfer: Test → Stable"
echo "================================================================"
echo "Package: $PACKAGE_NAME"
echo "Version: $VERSION"
echo ""

# Find .deb files in test distribution matching the package name and version
# Pattern matches standard Debian naming: PACKAGE_VERSION_ARCH.deb
TEST_POOL_DIR="$REPO_DIR/pool/test"
STABLE_POOL_DIR="$REPO_DIR/pool/stable"

# Check if package directory exists in test
if [ ! -d "$TEST_POOL_DIR/$PACKAGE_NAME" ]; then
    echo "Error: Package directory not found in test: $TEST_POOL_DIR/$PACKAGE_NAME"
    exit 1
fi

# Find all .deb files matching the package name and version
found_files=0

# Create stable package directory if it doesn't exist
mkdir -p "$STABLE_POOL_DIR/$PACKAGE_NAME"

while IFS= read -r -d '' deb_file; do
    found_files=$((found_files + 1))
    filename=$(basename "$deb_file")
    
    echo "Found package file: $filename"
    
    # Copy the .deb file to stable
    dest_file="$STABLE_POOL_DIR/$PACKAGE_NAME/$filename"
    
    if [ -f "$dest_file" ]; then
        echo "  Warning: File already exists in stable, overwriting: $filename"
    fi
    
    cp "$deb_file" "$dest_file"
    echo "  ✓ Copied to stable: $dest_file"
    
done < <(find "$TEST_POOL_DIR/$PACKAGE_NAME" -type f -name "${PACKAGE_NAME}_${VERSION}_*.deb" -print0)

if [ "$found_files" -eq 0 ]; then
    echo "Error: No .deb files found matching '$PACKAGE_NAME' version '$VERSION' in test distribution"
    echo "Searched in: $TEST_POOL_DIR/$PACKAGE_NAME"
    echo "Pattern: ${PACKAGE_NAME}_${VERSION}_*.deb"
    exit 1
fi

echo ""
echo "Successfully copied $found_files package file(s) to stable distribution"

# Transfer changelog files if they exist
# Changelogs are stored in changelogs/main/FIRST_LETTER/PACKAGE/PACKAGE_VERSION/
CHANGELOG_DIR="$REPO_DIR/changelogs/main"

# Get the first letter of the package name (lowercase)
first_letter="${PACKAGE_NAME:0:1}"
first_letter="${first_letter,,}"
changelog_path="$CHANGELOG_DIR/$first_letter/$PACKAGE_NAME/${PACKAGE_NAME}_${VERSION}"

if [ -d "$changelog_path" ]; then
    echo ""
    echo "Note: Changelog files already exist at: $changelog_path"
    echo "These will be kept as-is. If you need to update them, they will be"
    echo "regenerated when the update-repo.sh script runs."
else
    echo ""
    echo "Note: No existing changelog found. Changelogs will be extracted"
    echo "from the package when update-repo.sh runs."
fi

echo ""
echo "================================================================"
echo "Package transfer completed successfully!"
echo "Package: $PACKAGE_NAME version $VERSION"
echo "Status: Available in stable distribution"
echo "================================================================"
