#!/bin/bash
set -e

# Script to update APT repository metadata
# This script generates Packages files and Release files for the repository
# Usage: update-repo.sh [distribution]
#   distribution: stable, test, or "all" to update all distributions (default: all)

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:-all}"
COMPONENTS="main"
ARCHITECTURES="amd64 arm64 i386"

# Determine which distributions to process
if [ "$DIST" = "all" ]; then
    DISTRIBUTIONS="stable test"
    echo "Updating APT repository for all distributions..."
else
    DISTRIBUTIONS="$DIST"
    echo "Updating APT repository for distribution: $DIST..."
fi

# Process each distribution
for current_dist in $DISTRIBUTIONS; do
    echo ""
    echo "Processing distribution: $current_dist"
    
    # Generate Packages files for each architecture
    for arch in $ARCHITECTURES; do
        echo "  Processing architecture: $arch"
        
        PACKAGES_DIR="$REPO_DIR/dists/$current_dist/main/binary-$arch"
        PACKAGES_FILE="$PACKAGES_DIR/Packages"
        
        # Ensure directory exists
        mkdir -p "$PACKAGES_DIR"
        
        # Create empty Packages file
        > "$PACKAGES_FILE"
        
        # Find all .deb files in pool for this distribution
        POOL_PATHS=()
        # Add distribution-specific pool directory for scanning
        POOL_PATHS+=("$REPO_DIR/pool/$current_dist")
        
        for pool_path in "${POOL_PATHS[@]}"; do
            if [ ! -d "$pool_path" ]; then
                continue
            fi
            
            find "$pool_path" -name "*.deb" -print0 2>/dev/null | while IFS= read -r -d '' deb_file; do
                # Get package info using dpkg-deb
                if dpkg-deb --info "$deb_file" | grep -q "Architecture: $arch\|Architecture: all"; then
                    echo "    Adding package: $(basename "$deb_file")"
                    
                    # Extract package control information
                    dpkg-deb -f "$deb_file" >> "$PACKAGES_FILE"
                    
                    # Add Filename field (relative to repository root)
                    rel_path=$(realpath --relative-to="$REPO_DIR" "$deb_file")
                    echo "Filename: $rel_path" >> "$PACKAGES_FILE"
                    
                    # Add Size field
                    size=$(stat -c%s "$deb_file")
                    echo "Size: $size" >> "$PACKAGES_FILE"
                    
                    # Add MD5sum, SHA1, SHA256
                    md5=$(md5sum "$deb_file" | cut -d' ' -f1)
                    sha1=$(sha1sum "$deb_file" | cut -d' ' -f1)
                    sha256=$(sha256sum "$deb_file" | cut -d' ' -f1)
                    echo "MD5sum: $md5" >> "$PACKAGES_FILE"
                    echo "SHA1: $sha1" >> "$PACKAGES_FILE"
                    echo "SHA256: $sha256" >> "$PACKAGES_FILE"
                    
                    # Add blank line to separate packages
                    echo "" >> "$PACKAGES_FILE"
                fi
            done
        done
        
        # Compress Packages file
        gzip -9 -c "$PACKAGES_FILE" > "$PACKAGES_FILE.gz"
        xz -9 -c "$PACKAGES_FILE" > "$PACKAGES_FILE.xz"
    done
done

# Extract and host changelog files
echo ""
echo "Extracting changelog files..."
CHANGELOG_DIR="$REPO_DIR/changelogs"

# Process each distribution
for current_dist in $DISTRIBUTIONS; do
    echo "  Processing changelogs for distribution: $current_dist"
    
    # Find pool paths for this distribution
    POOL_PATHS=()
    # Add distribution-specific pool directory for scanning
    POOL_PATHS+=("$REPO_DIR/pool/$current_dist")
    
    for pool_path in "${POOL_PATHS[@]}"; do
        if [ ! -d "$pool_path" ]; then
            continue
        fi
        
        # Process each .deb file to extract changelogs
        find "$pool_path" -name "*.deb" -print0 2>/dev/null | while IFS= read -r -d '' deb_file; do
            # Get package name and version
            pkg_name=$(dpkg-deb -f "$deb_file" Package)
            pkg_version=$(dpkg-deb -f "$deb_file" Version)
            
            if [ -n "$pkg_name" ] && [ -n "$pkg_version" ]; then
                # Get first letter of package name for directory structure
                first_letter=$(echo "$pkg_name" | cut -c1 | tr '[:upper:]' '[:lower:]')
                
                # Create changelog directory path following Debian convention
                # Format: changelogs/main/FIRST_LETTER/PACKAGE/PACKAGE_VERSION/
                changelog_path="$CHANGELOG_DIR/main/$first_letter/$pkg_name/${pkg_name}_${pkg_version}"
                mkdir -p "$changelog_path"
                
                # Try to extract changelog from package
                # Changelog is typically at /usr/share/doc/PACKAGE/changelog
                if dpkg-deb --fsys-tarfile "$deb_file" | tar -t 2>/dev/null | grep -q "^./usr/share/doc/$pkg_name/changelog$"; then
                    echo "    Extracting changelog for $pkg_name ($pkg_version)"
                    dpkg-deb --fsys-tarfile "$deb_file" | tar -xO "./usr/share/doc/$pkg_name/changelog" > "$changelog_path/changelog" 2>/dev/null || true
                    
                    # Also create compressed versions as many repositories do
                    if [ -f "$changelog_path/changelog" ] && [ -s "$changelog_path/changelog" ]; then
                        gzip -9 -c "$changelog_path/changelog" > "$changelog_path/changelog.gz"
                    fi
                fi
            fi
        done
    done
done

# Generate Release files for each distribution
for current_dist in $DISTRIBUTIONS; do
    echo ""
    echo "Creating Release file for distribution: $current_dist"
    RELEASE_FILE="$REPO_DIR/dists/$current_dist/Release"
    
    cat > "$RELEASE_FILE" << EOF
Origin: APT Server
Label: APT Server
Suite: $current_dist
Codename: $current_dist
Architectures: $ARCHITECTURES
Components: $COMPONENTS
Description: Custom APT Repository
Date: $(date -Ru)
EOF

    # Add MD5Sum, SHA1, and SHA256 sections
    echo "MD5Sum:" >> "$RELEASE_FILE"
    for arch in $ARCHITECTURES; do
        for file in "main/binary-$arch/Packages" "main/binary-$arch/Packages.gz" "main/binary-$arch/Packages.xz"; do
            if [ -f "$REPO_DIR/dists/$current_dist/$file" ]; then
                size=$(stat -c%s "$REPO_DIR/dists/$current_dist/$file")
                md5=$(md5sum "$REPO_DIR/dists/$current_dist/$file" | cut -d' ' -f1)
                echo " $md5 $size $file" >> "$RELEASE_FILE"
            fi
        done
    done

    echo "SHA1:" >> "$RELEASE_FILE"
    for arch in $ARCHITECTURES; do
        for file in "main/binary-$arch/Packages" "main/binary-$arch/Packages.gz" "main/binary-$arch/Packages.xz"; do
            if [ -f "$REPO_DIR/dists/$current_dist/$file" ]; then
                size=$(stat -c%s "$REPO_DIR/dists/$current_dist/$file")
                sha1=$(sha1sum "$REPO_DIR/dists/$current_dist/$file" | cut -d' ' -f1)
                echo " $sha1 $size $file" >> "$RELEASE_FILE"
            fi
        done
    done

    echo "SHA256:" >> "$RELEASE_FILE"
    for arch in $ARCHITECTURES; do
        for file in "main/binary-$arch/Packages" "main/binary-$arch/Packages.gz" "main/binary-$arch/Packages.xz"; do
            if [ -f "$REPO_DIR/dists/$current_dist/$file" ]; then
                size=$(stat -c%s "$REPO_DIR/dists/$current_dist/$file")
                sha256=$(sha256sum "$REPO_DIR/dists/$current_dist/$file" | cut -d' ' -f1)
                echo " $sha256 $size $file" >> "$RELEASE_FILE"
            fi
        done
    done
done

echo ""
echo "Repository updated successfully!"
echo "Repository root: $REPO_DIR"
echo "Distributions: $DISTRIBUTIONS"
