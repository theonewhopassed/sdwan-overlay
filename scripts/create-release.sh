#!/bin/bash

# SD-WAN Overlay Release Creator
# Creates GitHub releases with proper versioning and documentation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "SD-WAN Overlay Release Creator"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION   Version to release (e.g., 1.0.0)"
    echo "  -t, --type TYPE         Release type: patch, minor, major (default: patch)"
    echo "  -m, --message MESSAGE   Release message"
    echo "  -d, --draft             Create as draft release"
    echo "  -p, --prerelease        Create as prerelease"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --version 1.0.0 --message 'Initial release'"
    echo "  $0 --type minor --message 'Add new features'"
    echo "  $0 --type patch --message 'Bug fixes' --draft"
}

# Parse command line arguments
VERSION=""
RELEASE_TYPE="patch"
MESSAGE=""
DRAFT=false
PRERELEASE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--type)
            RELEASE_TYPE="$2"
            shift 2
            ;;
        -m|--message)
            MESSAGE="$2"
            shift 2
            ;;
        -d|--draft)
            DRAFT=true
            shift
            ;;
        -p|--prerelease)
            PRERELEASE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Auto-generate version if not provided
if [ -z "$VERSION" ]; then
    CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    CURRENT_VERSION=${CURRENT_VERSION#v}
    
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    
    case $RELEASE_TYPE in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid release type: $RELEASE_TYPE"
            exit 1
            ;;
    esac
    
    VERSION="${major}.${minor}.${patch}"
fi

# Validate version format
if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $VERSION (expected: X.Y.Z)"
    exit 1
fi

# Generate release message if not provided
if [ -z "$MESSAGE" ]; then
    case $RELEASE_TYPE in
        major)
            MESSAGE="🚀 Major release with breaking changes"
            ;;
        minor)
            MESSAGE="✨ Minor release with new features"
            ;;
        patch)
            MESSAGE="🐛 Patch release with bug fixes"
            ;;
    esac
fi

log_info "Creating release v$VERSION..."

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    log_warning "Not on main branch (current: $CURRENT_BRANCH)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    log_error "There are uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

# Build release packages
log_info "Building release packages..."
VERSION=$VERSION ./scripts/build-release.sh

# Check if packages were created
if [ ! -d "dist" ] || [ -z "$(ls -A dist/*.tar.gz 2>/dev/null)" ]; then
    log_error "No release packages found in dist/ directory"
    exit 1
fi

# Generate checksums
log_info "Generating checksums..."
cd dist
sha256sum *.tar.gz > SHA256SUMS
cd ..

# Create release notes
log_info "Generating release notes..."
RELEASE_NOTES_FILE="release-notes-v$VERSION.md"

# Read template and replace placeholders
sed "s/{{VERSION}}/$VERSION/g" .github/release-template.md > "$RELEASE_NOTES_FILE"

# Get SHA256 checksum for the main package
MAIN_PACKAGE="sdwan-overlay-$VERSION-linux-amd64.tar.gz"
if [ -f "dist/$MAIN_PACKAGE" ]; then
    SHA256=$(sha256sum "dist/$MAIN_PACKAGE" | cut -d' ' -f1)
    sed -i "s/{{SHA256}}/$SHA256/g" "$RELEASE_NOTES_FILE"
else
    log_warning "Main package not found: $MAIN_PACKAGE"
    sed -i "s/{{SHA256}}/unknown/g" "$RELEASE_NOTES_FILE"
fi

# Create git tag
log_info "Creating git tag v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION

$MESSAGE

Packages:
- sdwan-overlay-$VERSION-linux-amd64.tar.gz
- sdwan-overlay-$VERSION-linux-arm64.tar.gz
- sdwan-overlay-$VERSION-docker.tar.gz

SHA256: $SHA256"

# Push tag to remote
log_info "Pushing tag to remote..."
git push origin "v$VERSION"

# Create GitHub release
log_info "Creating GitHub release..."

# Prepare release files
RELEASE_FILES=""
for file in dist/*.tar.gz dist/SHA256SUMS; do
    if [ -f "$file" ]; then
        RELEASE_FILES="$RELEASE_FILES $file"
    fi
done

# Create release using GitHub CLI if available
if command -v gh &> /dev/null; then
    log_info "Using GitHub CLI to create release..."
    
    GH_ARGS=""
    if [ "$DRAFT" = true ]; then
        GH_ARGS="$GH_ARGS --draft"
    fi
    if [ "$PRERELEASE" = true ]; then
        GH_ARGS="$GH_ARGS --prerelease"
    fi
    
    gh release create "v$VERSION" \
        --title "SD-WAN Overlay v$VERSION" \
        --notes-file "$RELEASE_NOTES_FILE" \
        $RELEASE_FILES \
        $GH_ARGS
    
    log_success "GitHub release created successfully!"
else
    log_warning "GitHub CLI not found. Please create the release manually:"
    echo ""
    echo "1. Go to: https://github.com/theonewhopassed/sdwan-overlay/releases/new"
    echo "2. Tag version: v$VERSION"
    echo "3. Title: SD-WAN Overlay v$VERSION"
    echo "4. Description: Copy content from $RELEASE_NOTES_FILE"
    echo "5. Upload files: $RELEASE_FILES"
    if [ "$DRAFT" = true ]; then
        echo "6. Mark as draft"
    fi
    if [ "$PRERELEASE" = true ]; then
        echo "7. Mark as prerelease"
    fi
    echo ""
fi

# Cleanup
rm -f "$RELEASE_NOTES_FILE"

log_success "Release v$VERSION created successfully!"
log_info "Release files:"
ls -la dist/

log_info "Next steps:"
echo "1. Verify the release on GitHub"
echo "2. Test the packages on a clean VM"
echo "3. Update documentation if needed"
echo "4. Announce the release to users"

