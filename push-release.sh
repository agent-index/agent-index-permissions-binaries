#!/usr/bin/env bash
# push-release.sh — Cut a release of agent-index-show-plan binaries.
#
# What it does:
#   1. Commits any pending README/LICENSE changes and pushes main.
#   2. Creates the git tag for the release version.
#   3. Pushes the tag.
#   4. Creates the GitHub Release and uploads the 6 platform binaries
#      from the agent-index-core build output as release assets.
#
# Prereqs:
#   - This script lives in the cloned binaries repo at:
#       /c/Users/Bill-AgentIndex/agent-index/dev_source/agent-index-permissions-binaries
#   - The 6 platform binaries have been built and exist at:
#       /c/Users/Bill-AgentIndex/agent-index/dev_source/agent-index-core/lib/permission-helper-go/dist/
#   - `gh` CLI is installed and authenticated (`gh auth status` succeeds).
#     If `gh` is missing, install it: https://cli.github.com/
#   - You're on the main branch of the binaries repo.
#
# Usage:
#   bash push-release.sh                # uses version from binaries' filenames in dist/
#   bash push-release.sh 0.2.0          # explicit version

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DIST_DIR="/c/Users/Bill-AgentIndex/agent-index/dev_source/agent-index-core/lib/permission-helper-go/dist"

cd "$SCRIPT_DIR"

# Verify we're in the right repo
if [[ "$(basename "$SCRIPT_DIR")" != "agent-index-permissions-binaries" ]]; then
    echo "✗ this script must be run from the agent-index-permissions-binaries repo root"
    exit 1
fi
if [[ ! -d .git ]]; then
    echo "✗ not a git repo: $SCRIPT_DIR"
    exit 1
fi

# Verify gh
if ! command -v gh >/dev/null 2>&1; then
    echo "✗ gh CLI not found. Install from https://cli.github.com/ and run 'gh auth login'."
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh CLI not authenticated. Run 'gh auth login' first."
    exit 1
fi

# Verify dist
if [[ ! -d "$DIST_DIR" ]]; then
    echo "✗ build output not found at $DIST_DIR"
    echo "  Run: cd /c/Users/Bill-AgentIndex/agent-index/dev_source/agent-index-core/lib/permission-helper-go && bash build-all.sh"
    exit 1
fi

# Derive version
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    # Discover from the dist filenames: agent-index-show-plan-X.Y.Z-...
    VERSION=$(ls "$DIST_DIR"/agent-index-show-plan-*-windows-amd64.exe 2>/dev/null | head -1 | sed -E 's|.*agent-index-show-plan-([0-9.]+)-windows-amd64.exe|\1|')
    if [[ -z "$VERSION" ]]; then
        echo "✗ could not derive version from dist/ contents and no arg passed"
        exit 1
    fi
fi
TAG="v${VERSION}"

echo "→ Releasing ${TAG} from $DIST_DIR"
echo ""

# Verify all 6 expected binaries are present
EXPECTED=(
    "agent-index-show-plan-${VERSION}-windows-amd64.exe"
    "agent-index-show-plan-${VERSION}-windows-arm64.exe"
    "agent-index-show-plan-${VERSION}-darwin-amd64"
    "agent-index-show-plan-${VERSION}-darwin-arm64"
    "agent-index-show-plan-${VERSION}-linux-amd64"
    "agent-index-show-plan-${VERSION}-linux-arm64"
)
MISSING=()
for f in "${EXPECTED[@]}"; do
    if [[ ! -f "$DIST_DIR/$f" ]]; then
        MISSING+=("$f")
    fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "✗ missing expected artifacts in dist/:"
    for m in "${MISSING[@]}"; do echo "    $m"; done
    exit 1
fi
echo "✓ all 6 platform binaries present"

# 1. Commit + push any pending README/LICENSE changes
if [[ -n $(git status --porcelain) ]]; then
    echo ""
    echo "→ Committing pending repo metadata changes..."
    git add -A
    git commit -m "Update repo metadata for ${TAG}"
fi

CURRENT_BRANCH=$(git branch --show-current)
echo "→ Pushing branch ${CURRENT_BRANCH}..."
git push origin "${CURRENT_BRANCH}"

# 2. Create + push the tag (skip if it already exists)
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "✓ tag ${TAG} already exists locally"
else
    echo "→ Creating tag ${TAG}..."
    git tag -a "$TAG" -m "agent-index-show-plan ${VERSION}"
fi

if git ls-remote --tags origin "refs/tags/${TAG}" | grep -q .; then
    echo "✓ tag ${TAG} already at origin"
else
    echo "→ Pushing tag ${TAG}..."
    git push origin "$TAG"
fi

# 3. Create the GitHub Release with all 6 assets
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "✓ GitHub Release ${TAG} already exists; uploading any missing assets..."
    for f in "${EXPECTED[@]}"; do
        if gh release view "$TAG" --json assets --jq ".assets[].name" | grep -qx "$f"; then
            echo "    ✓ $f already attached"
        else
            echo "    → uploading $f"
            gh release upload "$TAG" "$DIST_DIR/$f"
        fi
    done
else
    echo "→ Creating GitHub Release ${TAG}..."
    NOTES_FILE=$(mktemp)
    cat > "$NOTES_FILE" <<EOF
agent-index-show-plan ${VERSION}

First public release of the native Go permission-helper binary. See the agent-index-core ${VERSION%.*}.0 CHANGELOG for the full feature list and integration story:
https://github.com/agent-index/agent-index-core/blob/main/CHANGELOG.md

Verify downloads against SHA256s published in agent-index's infrastructure-directory.json.
EOF
    gh release create "$TAG" \
        --title "agent-index-show-plan ${VERSION}" \
        --notes-file "$NOTES_FILE" \
        "${EXPECTED[@]/#/$DIST_DIR/}"
    rm -f "$NOTES_FILE"
fi

echo ""
echo "✓ Release ${TAG} published."
echo "  https://github.com/agent-index/agent-index-permissions-binaries/releases/tag/${TAG}"
echo ""
echo "Verify one URL works (smoke test):"
echo "  curl -sLI https://github.com/agent-index/agent-index-permissions-binaries/releases/download/${TAG}/agent-index-show-plan-${VERSION}-darwin-arm64 | head -1"
echo "  Expected: HTTP/2 302 (then a 200 from the redirect target)"
