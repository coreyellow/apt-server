# Usage Guide for APT Server

## Quick Start

### 1. Adding this Repository to Your System

Replace `<username>` and `<repository>` with your GitHub username and repository name.

#### For Stable Distribution (Production Packages)

```bash
# Add the stable repository
echo "deb [trusted=yes] https://<username>.github.io/<repository> stable main" | sudo tee /etc/apt/sources.list.d/custom-repo.list

# Update package lists
sudo apt update
```

#### For Test Distribution (Testing Packages)

```bash
# Add the test repository
echo "deb [trusted=yes] https://<username>.github.io/<repository> test main" | sudo tee /etc/apt/sources.list.d/custom-repo-test.list

# Update package lists
sudo apt update
```

You can add both repositories if you want access to packages from both distributions.

**Security Note**: The `[trusted=yes]` option disables GPG signature verification. This is acceptable for testing but not recommended for production use.

### 2. Adding Packages to the Repository

#### Distribution Selection

This repository supports two distributions:
- **test**: For testing new packages or updates (recommended for development)
- **stable**: For production-ready packages

**Recommended Workflow**:
1. Upload new packages to the **test** distribution
2. Test the packages from the test repository
3. Use the **Transfer Package** workflow to promote tested packages to **stable**

#### Option A: Using GitHub Actions (Recommended for Package Promotion)

To transfer a tested package from test to stable:

1. Navigate to the repository on GitHub
2. Click on the "Actions" tab
3. Select "Transfer Package to Stable" from the workflow list
4. Click "Run workflow" button
5. Fill in the required information:
   - **Package name**: The name of the package (e.g., `myapp`)
   - **Version**: The version to transfer (e.g., `1.0.0`)
6. Click "Run workflow" to start the transfer

The workflow will automatically:
- Copy all architecture variants (amd64, arm64, etc.) from test to stable
- Update repository metadata for both distributions
- Extract and host changelog files
- Deploy the updated repository to GitHub Pages

**Note**: The package remains in the test distribution after transfer. You can use the Delete Package workflow if you want to remove it from test.

#### Option B: Using Git (Recommended for New Packages)

##### Adding to Test Distribution (Default)

```bash
# Clone the repository
git clone https://github.com/<username>/<repository>.git
cd <repository>

# Add your .deb file to the test distribution (organized by package name)
# Create package directory if it doesn't exist
mkdir -p pool/test/your-package
cp /path/to/your-package.deb pool/test/your-package/

# Commit and push
git add pool/test/your-package/your-package.deb
git commit -m "Add your-package to test"
git push
```

##### Adding to Stable Distribution

```bash
# Clone the repository
git clone https://github.com/<username>/<repository>.git
cd <repository>

# Add your .deb file to the stable distribution (organized by package name)
# Create package directory if it doesn't exist
mkdir -p pool/stable/your-package
cp /path/to/your-package.deb pool/stable/your-package/

# Commit and push
git add pool/stable/your-package/your-package.deb
git commit -m "Add your-package to stable"
git push
```

The GitHub Actions workflow will automatically:
1. Detect the new .deb file
2. Update the APT repository metadata for all distributions
3. Deploy to GitHub Pages

#### Option C: Using GitHub Web Interface

##### For Test Distribution

1. Navigate to the `pool/test/` directory in your repository
2. Create a new folder with your package name (e.g., `myapp`) if it doesn't exist
3. Navigate to the `pool/test/myapp/` directory
4. Click "Add file" → "Upload files"
5. Upload your .deb file(s)
6. Commit the changes

##### For Stable Distribution

1. Navigate to the `pool/stable/` directory in your repository
2. Create a new folder with your package name (e.g., `myapp`) if it doesn't exist
3. Navigate to the `pool/stable/myapp/` directory
4. Click "Add file" → "Upload files"
5. Upload your .deb file(s)
6. Commit the changes

### 3. Installing Packages

After the repository is updated (usually takes 1-2 minutes):

```bash
# Search for your package
apt search your-package

# Install your package
sudo apt install your-package

# View package changelog (if available)
apt changelog your-package
```

## Creating a .deb Package

If you need to create a .deb package from your software:

### Basic Structure

```
your-package/
├── DEBIAN/
│   └── control         # Package metadata
├── usr/
│   ├── bin/           # Executable files
│   └── share/
│       └── doc/       # Documentation
│           └── your-package/
│               ├── README
│               ├── copyright
│               └── changelog  # Package changelog (recommended)
```

### Example control File

```
Package: your-package
Version: 1.0.0
Architecture: amd64
Maintainer: Your Name <your.email@example.com>
Description: Short description
 Longer description that can span
 multiple lines.
Depends: libc6 (>= 2.27)
```

### Including a Changelog

Create a changelog file in Debian format at `usr/share/doc/your-package/changelog`:

```
your-package (1.0.0) stable; urgency=medium

  * Initial release
  * Added feature X
  * Fixed bug Y

 -- Your Name <your.email@example.com>  Mon, 07 Dec 2024 12:00:00 +0000
```

The changelog will be automatically extracted and hosted by the repository, making it accessible via `apt changelog`.

### Building the Package

```bash
dpkg-deb --build your-package
```

This creates `your-package.deb` which you can then add to the repository.

## Architecture Support

The repository supports three architectures:
- `amd64`: 64-bit x86 (Intel/AMD)
- `arm64`: 64-bit ARM (e.g., Raspberry Pi 4)
- `i386`: 32-bit x86 (legacy systems)

Use `Architecture: all` in your control file for architecture-independent packages (e.g., documentation, scripts).

## Troubleshooting

### Repository Not Found

If you get a "repository not found" error:
1. Verify GitHub Pages is enabled in repository Settings → Pages
2. Check that the URL matches your GitHub Pages URL
3. Wait a few minutes for GitHub Pages to deploy

### Package Not Found After Upload

1. Check the Actions tab to see if the workflow ran successfully
2. Verify the .deb file is in the appropriate pool directory (e.g., `pool/stable/package-name/` or `pool/test/package-name/`)
3. Check that the package architecture matches your system

### Permission Denied

The workflow needs write permissions. Ensure:
1. Actions have write permissions (Settings → Actions → General → Workflow permissions)
2. The repository has GitHub Pages enabled

## Advanced Configuration

### Manual Package Transfer

For advanced users, you can also transfer packages manually using the script:

```bash
# Transfer a specific version from test to stable
./scripts/transfer-package.sh package-name version

# Example: Transfer flask-app version 1.0.0
./scripts/transfer-package.sh flask-app 1.0.0

# After manual transfer, update the repository metadata
./scripts/update-repo.sh all

# Commit and push the changes
git add pool/ dists/ changelogs/
git commit -m "Transfer package to stable"
git push
```

### Adding Multiple Components

Edit `scripts/update-repo.sh` to add components beyond `main`:

```bash
COMPONENTS="main contrib non-free"
```

### Supporting Additional Architectures

Edit `scripts/update-repo.sh` to add more architectures:

```bash
ARCHITECTURES="amd64 arm64 armhf i386"
```

### GPG Signing (Production Use)

For production use, implement GPG signing:

1. Generate a GPG key
2. Sign the Release file with `gpg --clearsign`
3. Update the workflow to sign releases
4. Users can then add your repository without `[trusted=yes]`

## Testing Your Package

Before adding to the repository, test locally:

```bash
# Install locally
sudo dpkg -i your-package.deb

# Check for dependency issues
sudo apt --fix-broken install

# Test the package
your-package --version

# Remove for testing
sudo apt remove your-package
```

## Example: Complete Workflow

```bash
# 1. Create your software
echo '#!/bin/bash
echo "Hello from myapp!"' > myapp

# 2. Prepare package structure
mkdir -p myapp-1.0/DEBIAN myapp-1.0/usr/bin
mv myapp myapp-1.0/usr/bin/
chmod +x myapp-1.0/usr/bin/myapp

# 3. Create control file
cat > myapp-1.0/DEBIAN/control << EOF
Package: myapp
Version: 1.0
Architecture: all
Maintainer: Your Name <you@example.com>
Description: My example application
 A simple example application.
EOF

# 4. Build the package
dpkg-deb --build myapp-1.0

# 5. Add to repository (choose stable or test distribution)
# Create package directory if it doesn't exist
mkdir -p pool/stable/myapp
cp myapp-1.0.deb pool/stable/myapp/
git add pool/stable/myapp/myapp-1.0.deb
git commit -m "Add myapp version 1.0"
git push

# 6. Wait for GitHub Actions to complete (~1-2 minutes)

# 7. Install on any system with the repository configured
sudo apt update
sudo apt install myapp
```

## Resources

- [Debian Package Format](https://www.debian.org/doc/debian-policy/)
- [Creating .deb Packages](https://www.debian.org/doc/manuals/maint-guide/)
- [APT Repository Format](https://wiki.debian.org/DebianRepository/Format)
