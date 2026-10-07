#!/usr/bin/env bash
# Release a version of Dynamic Island.
#
# The version stamp lives in VERSION at the repo root, and the bundle's
# Info.plist reads it at build time — so the git tag, the bundle, and the
# running app always agree on the version. The script enforces that
# invariant end-to-end.
#
# Two phases, separated on purpose:
#
#   ./scripts/release.sh                # phase 1: bump (optional), build, install, relaunch, report
#   ./scripts/release.sh --push         # phase 2: tag, push main + tag
#
# Phase 1 is the build-and-verify loop. The user runs it, looks at the
# running app, and only then runs phase 2. That gap is the review — the
# script does not auto-confirm; the user does, by re-running with --push.
#
# Flags:
#   --bump patch|minor|major   Edit VERSION before building.
#                              The bump is a one-line change and lands as
#                              its own commit on main, ahead of the tag.
#   --push                     After verifying, create an annotated tag
#                              (opens $EDITOR for the message) and push
#                              main + the tag to origin.
#
# Exit codes:
#   0  success (or "ready to release" in phase 1)
#   1  pre-flight failure or build/launch failure
#   2  bad CLI argument
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

BUMP=""
PUSH=0

usage() {
    sed -n '2,/^set -euo/p' "$0" | sed '$d'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bump)
            [[ $# -ge 2 ]] || { echo "❌ --bump requires an argument (patch|minor|major)" >&2; exit 2; }
            BUMP="$2"; shift 2;;
        --bump=*)
            BUMP="${1#--bump=}"; shift;;
        --push)
            PUSH=1; shift;;
        -h|--help)
            usage 0;;
        *)
            echo "❌ unknown flag: $1" >&2
            usage 2;;
    esac
done

# ---------- pre-flight ----------

# VERSION is the single source of truth. The build script reads it when
# stamping Info.plist, and the tag name is derived from it. A missing or
# malformed file means the release machinery is broken, not the build.
if [[ ! -f VERSION ]]; then
    echo "❌ VERSION is missing at the repo root." >&2
    exit 1
fi
VERSION=$(tr -d '[:space:]' < VERSION)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ VERSION is not semver: '$VERSION' (expected MAJOR.MINOR.PATCH)" >&2
    exit 1
fi

# Refuse to release on a dirty tree: a partial release with uncommitted
# changes is unreviewable, because the tag would point at a state the
# next checkout can't reproduce without the uncommitted edits.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ working tree is dirty — commit or stash before releasing:" >&2
    git status --short >&2
    exit 1
fi

# Release only from main. Tags on a feature branch obscure where the
# canonical build came from, and a release from a branch other than
# main means the branch ref has to be coordinated with whoever else
# ships from main.
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "main" ]]; then
    echo "❌ releases happen on main, not on '$BRANCH'" >&2
    exit 1
fi

# Local main must be ahead of (or equal to) origin/main. A release that
# leaves main behind origin is a release of stale code.
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse --verify --quiet origin/main || true)
if [[ -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
    AHEAD=$(git rev-list --count origin/main..HEAD)
    BEHIND=$(git rev-list --count HEAD..origin/main)
    if [[ "$BEHIND" -gt 0 ]]; then
        echo "❌ local main is $BEHIND commit(s) behind origin/main — pull first" >&2
        exit 1
    fi
fi

# ---------- bump (optional) ----------

if [[ -n "$BUMP" ]]; then
    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
    case "$BUMP" in
        major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0;;
        minor) MINOR=$((MINOR+1)); PATCH=0;;
        patch) PATCH=$((PATCH+1));;
        *)
            echo "❌ unknown bump: '$BUMP' (use major|minor|patch)" >&2
            exit 2;;
    esac
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
    echo "📝 Bumping VERSION: $VERSION → $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    git add VERSION
    git commit -m "release: bump version to v$NEW_VERSION"
    echo "   committed: $(git rev-parse --short HEAD)"
    VERSION="$NEW_VERSION"
fi

TAG="v$VERSION"

# Refuse to double-tag. A tag that already exists is either the previous
# release (and the user means a different version) or a re-cut (which
# silently rewrites history).
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "❌ $TAG already exists locally — refusing to overwrite" >&2
    exit 1
fi
if git ls-remote --tags origin "$TAG" 2>/dev/null | grep -q "$TAG"; then
    echo "❌ $TAG already exists on origin — refusing to overwrite" >&2
    exit 1
fi

# ---------- build, install, relaunch ----------

echo ""
echo "🔨 Building $TAG..."
./scripts/build_app.sh

# The script-installed bundle is the binary on disk. Its version stamp
# is the contract with the user — the running app must say what the
# tag says, otherwise the release is shipping a stale binary.
INSTALLED=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Applications/DynamicIsland.app/Contents/Info.plist 2>/dev/null || echo "")
if [[ -z "$INSTALLED" ]]; then
    echo "❌ could not read CFBundleShortVersionString from the installed bundle" >&2
    exit 1
fi
if [[ "$INSTALLED" != "$VERSION" ]]; then
    echo "❌ bundle version mismatch: VERSION=$VERSION but Info.plist says $INSTALLED" >&2
    exit 1
fi
echo "📦 Installed bundle reports version: $INSTALLED"

# Relaunch so the running app matches the build. A stale process would
# still pass the bundle check (the .app on disk is correct) but report
# behaviour from the previous build — exactly the case §6.2 warns about.
pkill -f DynamicIsland >/dev/null 2>&1 || true
sleep 0.4
open /Applications/DynamicIsland.app
sleep 1
if ! pgrep -f DynamicIsland >/dev/null; then
    echo "❌ app failed to relaunch — investigate before tagging" >&2
    exit 1
fi
PID=$(pgrep -f DynamicIsland | head -1)
echo "✅ App is running (PID $PID)"

# ---------- ready to release ----------

echo ""
echo "Ready to release $TAG"
echo "  HEAD:    $(git rev-parse --short HEAD)"
echo "  Bundle:  $INSTALLED"
echo "  Tag:     (not yet created — local only)"
echo ""
echo "The running app is the review. Verify it behaves like a release,"
echo "then run with --push to tag and push."

if [[ $PUSH -eq 0 ]]; then
    exit 0
fi

# ---------- push ----------

# Annotated tag, message written in the user's editor. The release notes
# live in the tag, not in the bump commit, so the commit history stays
# a clean changelog and the human-curated summary sits on the tag.
git tag -a "$TAG"

git push origin main
git push origin "$TAG"

echo ""
echo "✅ Released $TAG"
echo "   https://github.com/Vuhuydiet/DynamicIsland/releases/tag/$TAG"
