#!/bin/bash
set -e

# Script to clean up APT repository pools by removing old package versions
# This script keeps only the latest version of each package
# Usage: cleanup-pool.sh [distribution]
#   distribution: stable, test, or "all" to clean all distributions (default: all)

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${1:-all}"

# Determine which distributions to process
if [ "$DIST" = "all" ]; then
    DISTRIBUTIONS="stable test"
    echo "Cleaning up pools for all distributions..."
elif [ "$DIST" = "stable" ] || [ "$DIST" = "test" ]; then
    DISTRIBUTIONS="$DIST"
    echo "Cleaning up pool for distribution: $DIST..."
else
    echo "Error: Invalid distribution '$DIST'"
    echo "Usage: $0 [distribution]"
    echo "  distribution: stable, test, or all (default: all)"
    exit 1
fi

echo "================================================================"
echo "Pool Cleanup - Keep Latest Versions Only"
echo "================================================================"
echo ""

total_deleted=0

# Process each distribution
for current_dist in $DISTRIBUTIONS; do
    echo "Processing distribution: $current_dist"
    echo "----------------------------------------------------------------"
    
    POOL_DIR="$REPO_DIR/pool/$current_dist"
    
    if [ ! -d "$POOL_DIR" ]; then
        echo "  Warning: Pool directory not found: $POOL_DIR"
        continue
    fi
    
    # Find all package directories (excluding 'main' legacy directory)
    for package_dir in "$POOL_DIR"/*; do
        if [ ! -d "$package_dir" ]; then
            continue
        fi
        
        package_name=$(basename "$package_dir")
        
        # Skip 'main' legacy directory
        if [ "$package_name" = "main" ]; then
            continue
        fi
        
        echo ""
        echo "  Package: $package_name"
        
        # Find all .deb files for this package and extract unique versions
        unset version_map
        declare -A version_map
        version_count=0
        
        while IFS= read -r -d '' deb_file; do
            filename=$(basename "$deb_file")
            # Extract version from filename: PACKAGE_VERSION_ARCH.deb
            # Remove package name prefix and .deb suffix, then extract version
            version=$(echo "$filename" | sed "s/^${package_name}_//" | sed 's/_[^_]*\.deb$//')
            
            if [ -n "$version" ]; then
                version_map["$version"]=1
                version_count=$((version_count + 1))
            fi
        done < <(find "$package_dir" -type f -name "*.deb" -print0 2>/dev/null)
        
        if [ "$version_count" -eq 0 ]; then
            echo "    No .deb files found"
            continue
        fi
        
        # Get list of unique versions
        version_list=()
        for version in "${!version_map[@]}"; do
            version_list+=("$version")
        done
        
        if [ ${#version_list[@]} -le 1 ]; then
            echo "    Only one version found, nothing to clean"
            continue
        fi
        
        # Find the latest version using dpkg --compare-versions
        latest_version="${version_list[0]}"
        for version in "${version_list[@]}"; do
            if dpkg --compare-versions "$version" gt "$latest_version"; then
                latest_version="$version"
            fi
        done
        
        echo "    Found ${#version_list[@]} version(s)"
        echo "    Latest version: $latest_version"
        echo "    Versions to delete:"
        
        # Delete all versions except the latest
        package_deleted_count=0
        for version in "${version_list[@]}"; do
            if [ "$version" != "$latest_version" ]; then
                echo "      - $version"
                
                # Delete all .deb files for this version
                while IFS= read -r -d '' old_deb; do
                    echo "        Deleting: $(basename "$old_deb")"
                    rm -f "$old_deb"
                    package_deleted_count=$((package_deleted_count + 1))
                done < <(find "$package_dir" -type f -name "${package_name}_${version}_*.deb" -print0 2>/dev/null)
                
                # Delete associated changelog files
                CHANGELOG_DIR="$REPO_DIR/changelogs/main"
                first_letter=$(echo "$package_name" | cut -c1 | tr '[:upper:]' '[:lower:]')
                changelog_path="$CHANGELOG_DIR/$first_letter/$package_name/${package_name}_${version}"
                
                if [ -d "$changelog_path" ]; then
                    echo "        Deleting changelog: $changelog_path"
                    rm -rf "$changelog_path"
                fi
            fi
        done
        
        if [ "$package_deleted_count" -gt 0 ]; then
            echo "    Deleted $package_deleted_count old package file(s)"
            total_deleted=$((total_deleted + package_deleted_count))
        fi
    done
    
    echo ""
    echo "Completed processing distribution: $current_dist"
    echo "----------------------------------------------------------------"
done

echo ""
echo "================================================================"
echo "Pool Cleanup Completed!"
echo "================================================================"
echo "Total package files deleted: $total_deleted"
echo ""

if [ "$total_deleted" -eq 0 ]; then
    echo "No old versions found. All pools are clean!"
else
    echo "Successfully removed old package versions."
    echo "Only the latest version of each package has been retained."
fi
