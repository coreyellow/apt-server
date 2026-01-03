# APT Server

A fully automated APT (Debian package) repository hosted on GitHub Pages.

## Overview

This repository acts as an APT server that automatically processes uploaded Debian packages (.deb files) and makes them available through GitHub Pages. When you upload a .deb file to the repository, a GitHub Actions workflow automatically updates the APT repository metadata, making the package immediately available for installation.

## Features

- 🚀 **Automatic package indexing**: Upload a .deb file and the repository is updated automatically
- 📦 **Multi-architecture support**: Supports amd64, arm64, and i386 architectures
- 🎯 **Multiple distributions**: Support for both stable and test distributions
- 📝 **Changelog hosting**: Automatically extracts and hosts package changelogs
- 🌐 **GitHub Pages integration**: Packages are served directly from GitHub Pages
- 🔄 **Zero maintenance**: All metadata generation is handled by GitHub Actions
- 🎭 **Package promotion**: Easy workflow to promote tested packages from test to stable

## Package Lifecycle

The recommended workflow for managing packages is:

1. **Development**: Upload new packages or versions to the **test** distribution
2. **Testing**: Install and test packages from the test repository
3. **Promotion**: Use the Transfer Package workflow to move tested versions to **stable**
4. **Production**: End users install stable, production-ready packages

## How to Add Packages

### Choosing a Distribution

Packages can be uploaded to one of two distributions:
- **test**: For testing new packages or updates (default)
- **stable**: For production-ready packages

### Transferring Packages from Test to Stable

Once a package has been tested in the test distribution, you can promote it to stable using the Transfer Package workflow:

1. Go to the "Actions" tab in your repository
2. Select "Transfer Package to Stable" workflow
3. Click "Run workflow"
4. Enter the package name (e.g., `flask-app`)
5. Enter the version to transfer (e.g., `1.0.0`)
6. Click "Run workflow"

The workflow will:
- Copy the package files from `pool/test/` to `pool/stable/`
- Update repository metadata for both distributions
- Extract and host changelog files
- Deploy the updated repository to GitHub Pages

**Note**: This workflow only copies packages; it does not remove them from the test distribution.

### Cleaning Up Old Package Versions

Over time, as you upload multiple versions of packages, the repository can accumulate old versions. You can use the Pool Cleanup workflow to automatically remove old versions and keep only the latest:

1. Go to the "Actions" tab in your repository
2. Select "Clean Up Pool - Keep Latest Versions Only" workflow
3. Click "Run workflow"
4. Select which distribution to clean:
   - **all**: Clean up both stable and test distributions (default)
   - **stable**: Clean up only the stable distribution
   - **test**: Clean up only the test distribution
5. Click "Run workflow"

The workflow will:
- Scan all packages in the selected distribution(s)
- Identify the latest version of each package
- Remove all older versions while keeping the latest
- Clean up associated changelog files for deleted versions
- Update repository metadata
- Deploy the updated repository to GitHub Pages

**Note**: This operation is permanent. Make sure you want to remove old versions before running this workflow.

### Upload Methods

#### Option A: Upload to Test Distribution (Default)

1. Place your .deb file in the `pool/test/PACKAGE_NAME/` directory (organized by package name)
2. Commit and push your changes:
   ```bash
   # Example for a package named "myapp"
   git add pool/test/myapp/myapp_1.0.0_amd64.deb
   git commit -m "Add myapp to test"
   git push
   ```

#### Option B: Upload to Stable Distribution

1. Place your .deb file in the `pool/stable/PACKAGE_NAME/` directory (organized by package name)
2. Commit and push your changes:
   ```bash
   # Example for a package named "myapp"
   git add pool/stable/myapp/myapp_1.0.0_amd64.deb
   git commit -m "Add myapp to stable"
   git push
   ```

The GitHub Actions workflow will automatically update the repository metadata for all distributions.

## How to Use This Repository

### Adding the Repository

Add this APT repository to your system. You can choose between the stable and test distributions:

#### For Stable Packages (Production)

```bash
echo "deb [trusted=yes] https://mlmdevs.github.io/apt-server stable main" | sudo tee /etc/apt/sources.list.d/custom-repo.list
sudo apt update
```

#### For Test Packages (Testing)

```bash
echo "deb [trusted=yes] https://mlmdevs.github.io/apt-server test main" | sudo tee /etc/apt/sources.list.d/custom-repo-test.list
sudo apt update
```

You can also add both distributions if you want access to both stable and test packages.

**Note**: The `[trusted=yes]` option is used because packages are not GPG-signed by default. For production use, consider implementing GPG signing.

### Installing Packages

Once the repository is added, install packages normally:

```bash
sudo apt install your-package-name
```

### Viewing Changelogs

If your package includes changelog files, they are automatically extracted and hosted by the repository:

```bash
# View changelog for an installed package
apt changelog your-package-name

# Or access directly via URL
# https://<username>.github.io/<repository>/changelogs/main/FIRST_LETTER/PACKAGE/PACKAGE_VERSION/changelog
```

## Repository Structure

```
.
├── pool/               # Contains all .deb packages
│   ├── stable/        # Stable distribution packages
│   │   ├── package1/  # Organized by package name
│   │   ├── package2/
│   │   └── main/      # Legacy location (kept for backward compatibility)
│   └── test/          # Test distribution packages
│       ├── package1/  # Organized by package name
│       ├── package2/
│       └── main/      # Legacy location (kept for backward compatibility)
├── dists/             # APT repository metadata (auto-generated)
│   ├── stable/        # Stable distribution
│   │   └── main/      # Component
│   │       ├── binary-amd64/
│   │       ├── binary-arm64/
│   │       └── binary-i386/
│   └── test/          # Test distribution
│       └── main/      # Component
│           ├── binary-amd64/
│           ├── binary-arm64/
│           └── binary-i386/
├── changelogs/        # Package changelog files (auto-extracted)
│   └── main/          # Organized by component
│       └── FIRST_LETTER/
│           └── PACKAGE/
│               └── PACKAGE_VERSION/
│                   ├── changelog
│                   └── changelog.gz
├── scripts/              # Maintenance scripts
│   ├── update-repo.sh    # Script to regenerate repository metadata
│   ├── delete-package.sh # Script to delete packages
│   ├── transfer-package.sh # Script to transfer packages from test to stable
│   └── cleanup-pool.sh   # Script to clean up old package versions
└── .github/
    └── workflows/
        ├── update-repo.yml       # Automation workflow
        ├── upload-package.yml    # Package upload workflow
        ├── delete-package.yml    # Package deletion workflow
        ├── transfer-package.yml  # Package transfer workflow (test → stable)
        └── cleanup-pool.yml      # Pool cleanup workflow (keep latest versions only)
```

## Configuration

### GitHub Pages

To enable GitHub Pages for this repository:

1. Go to your repository Settings
2. Navigate to "Pages" in the left sidebar
3. Under "Build and deployment", select "GitHub Actions" as the source
4. The workflow will automatically deploy the repository

### Supported Architectures

The repository supports the following architectures:
- `amd64` (64-bit x86)
- `arm64` (64-bit ARM)
- `i386` (32-bit x86)

Packages marked as `Architecture: all` will be available for all architectures.

## Manual Repository Update

If you need to manually regenerate the repository metadata:

```bash
# Update all distributions
./scripts/update-repo.sh all

# Update only stable distribution
./scripts/update-repo.sh stable

# Update only test distribution
./scripts/update-repo.sh test
```

## Manual Pool Cleanup

If you need to manually clean up old package versions:

```bash
# Clean up all distributions (keep only latest versions)
./scripts/cleanup-pool.sh all

# Clean up only stable distribution
./scripts/cleanup-pool.sh stable

# Clean up only test distribution
./scripts/cleanup-pool.sh test
```

## Technical Details

The repository uses standard Debian repository format with:
- **Packages** files listing all available packages
- **Release** files with checksums and metadata
- **Changelog** files extracted from packages and hosted separately
- Compressed variants (.gz and .xz) for bandwidth efficiency

The metadata is automatically regenerated whenever .deb files are added or modified in the `pool/` directory.

### Changelog Extraction

When packages are added to the repository:
1. The script checks for changelog files at `/usr/share/doc/PACKAGE/changelog` inside each .deb
2. Changelogs are extracted and placed in `changelogs/main/FIRST_LETTER/PACKAGE/PACKAGE_VERSION/`
3. Both plain text and gzip-compressed versions are created
4. Changelogs can be accessed via `apt changelog PACKAGE` or directly through the repository URL

## Requirements

- Packages must be valid Debian packages (.deb format)
- Package architecture must be specified in the package metadata
- GitHub Pages must be enabled for the repository

## License

This repository structure and automation scripts are provided as-is for hosting APT repositories on GitHub.
