#!/bin/bash
set -e

# Script to delete a DEB package from the APT repository
# This script removes the .deb file and its associated changelog files
# If version is specified, only that version is deleted. Otherwise, all versions are deleted.

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_NAME="$1"
VERSION="$2"

if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: Package name is required"
    echo "Usage: $0 <package-name> [version]"
    exit 1
fi

if [ -n "$VERSION" ]; then
    echo "Searching for package: $PACKAGE_NAME version $VERSION"
else
    echo "Searching for package: $PACKAGE_NAME (all versions)"
fi

# Find and delete .deb files matching the package name (and version if specified)
# Pattern matches standard Debian naming: PACKAGE_VERSION_ARCH.deb or PACKAGE.deb
# Using underscore ensures we don't match packages with the name as a prefix
if [ -n "$VERSION" ]; then
    echo "Searching for files matching pattern: ${PACKAGE_NAME}_${VERSION}_*.deb"
else
    echo "Searching for files matching pattern: ${PACKAGE_NAME}_*.deb or ${PACKAGE_NAME}.deb"
fi

deleted_count=0
if [ -n "$VERSION" ]; then
    # Delete specific version only
    while IFS= read -r -d '' deb_file; do
        echo "Deleting: $deb_file"
        rm -f "$deb_file"
        deleted_count=$((deleted_count + 1))
    done < <(find "$REPO_DIR/pool" -type f -name "${PACKAGE_NAME}_${VERSION}_*.deb" -print0)
else
    # Delete all versions
    while IFS= read -r -d '' deb_file; do
        echo "Deleting: $deb_file"
        rm -f "$deb_file"
        deleted_count=$((deleted_count + 1))
    done < <(find "$REPO_DIR/pool" -type f \( -name "${PACKAGE_NAME}_*.deb" -o -name "${PACKAGE_NAME}.deb" \) -print0)
fi

if [ "$deleted_count" -eq 0 ]; then
    if [ -n "$VERSION" ]; then
        echo "Warning: No .deb files found matching '$PACKAGE_NAME' version '$VERSION'"
    else
        echo "Warning: No .deb files found matching '$PACKAGE_NAME'"
    fi
else
    echo "Deleted $deleted_count package file(s)"
fi

# Delete associated changelog files
# Changelogs are stored in changelogs/main/FIRST_LETTER/PACKAGE/PACKAGE_VERSION/
CHANGELOG_DIR="$REPO_DIR/changelogs/main"

# Get the first letter of the package name
first_letter=$(echo "$PACKAGE_NAME" | cut -c1 | tr '[:upper:]' '[:lower:]')
changelog_base_path="$CHANGELOG_DIR/$first_letter/$PACKAGE_NAME"

if [ -n "$VERSION" ]; then
    # Delete specific version changelog
    changelog_path="$changelog_base_path/$PACKAGE_NAME"_"$VERSION"
    if [ -d "$changelog_path" ]; then
        echo "Deleting changelogs: $changelog_path"
        rm -rf "$changelog_path"
    else
        echo "No changelogs found for package: $PACKAGE_NAME version $VERSION"
    fi
else
    # Delete all changelogs for the package
    if [ -d "$changelog_base_path" ]; then
        echo "Deleting changelogs: $changelog_base_path"
        rm -rf "$changelog_base_path"
    else
        echo "No changelogs found for package: $PACKAGE_NAME"
    fi
fi

echo "Package deletion completed!"
if [ -n "$VERSION" ]; then
    echo "Deleted package files and changelogs for: $PACKAGE_NAME version $VERSION"
else
    echo "Deleted package files and changelogs for: $PACKAGE_NAME (all versions)"
fi
