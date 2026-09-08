# Releases (gh release)

## List Releases

```bash
# List releases
gh release list
```

## View Release

```bash
# View latest release
gh release view

# View specific release
gh release view v1.0.0

# View in browser
gh release view v1.0.0 --web
```

## Create Release

```bash
# Create release with notes
gh release create v1.0.0 --notes "Release notes here"

# Create release with notes from file
gh release create v1.0.0 --notes-file notes.md

# Create release with target commit/branch
gh release create v1.0.0 --target main

# Create release as draft
gh release create v1.0.0 --draft

# Create pre-release
gh release create v1.0.0 --prerelease

# Create release with title
gh release create v1.0.0 --title "Version 1.0.0"

# Create release with assets
gh release create v1.0.0 ./file1.tar.gz ./file2.zip --notes "Release"
```

## Upload Assets

```bash
# Upload asset to release
gh release upload v1.0.0 ./file.tar.gz

# Upload multiple assets
gh release upload v1.0.0 ./file1.tar.gz ./file2.tar.gz

# Overwrite existing asset
gh release upload v1.0.0 ./file.tar.gz --clobber
```

## Delete Release

```bash
# Delete release
gh release delete v1.0.0

# Delete with confirmation
gh release delete v1.0.0 --yes

# Delete specific asset
gh release delete-asset v1.0.0 file.tar.gz
```

## Download Release Assets

```bash
# Download all assets
gh release download v1.0.0

# Download specific asset by pattern
gh release download v1.0.0 --pattern "*.tar.gz"

# Download to directory
gh release download v1.0.0 --dir ./downloads

# Download source archive
gh release download v1.0.0 --archive zip
gh release download v1.0.0 --archive tar.gz
```

## Edit Release

```bash
# Edit release notes
gh release edit v1.0.0 --notes "Updated notes"

# Edit title
gh release edit v1.0.0 --title "New Title"

# Convert to prerelease
gh release edit v1.0.0 --prerelease

# Convert draft to published
gh release edit v1.0.0 --draft=false
```

## Verify Release

```bash
# Verify release signature
gh release verify v1.0.0

# Verify specific asset
gh release verify-asset v1.0.0 file.tar.gz
```
