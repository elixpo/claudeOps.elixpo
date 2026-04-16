#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

# ── Load .env ─────────────────────────────────────────────
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo -e "${RED}[-]${NC} .env file not found. Create one with NPM_TOKEN=your_token"
  exit 1
fi

if [ -z "${NPM_TOKEN:-}" ]; then
  echo -e "${RED}[-]${NC} NPM_TOKEN not set in .env"
  exit 1
fi

# ── Preflight checks ─────────────────────────────────────
echo ""
echo -e "${BOLD}ClaudeOps Deploy${NC}"
echo "────────────────"
echo ""

# Validate package
node -c cli.js 2>/dev/null || { echo -e "${RED}[-]${NC} cli.js has syntax errors"; exit 1; }
for f in lib/*.js; do
  node -c "$f" 2>/dev/null || { echo -e "${RED}[-]${NC} $f has syntax errors"; exit 1; }
done
echo -e "${GREEN}[+]${NC} All JS files valid"

# Get version from package.json
VERSION=$(node -p "require('./package.json').version")
NAME=$(node -p "require('./package.json').name")
echo -e "${CYAN}[*]${NC} Package: ${NAME}@${VERSION}"

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo -e "${YELLOW}[!]${NC} Uncommitted changes detected"
  echo -ne "${CYAN}[?]${NC} Continue anyway? (y/n): "
  read -r ans
  [[ "$ans" =~ ^[Yy] ]] || exit 0
fi

# Check if version already published
if npm view "${NAME}@${VERSION}" version 2>/dev/null; then
  echo -e "${RED}[-]${NC} ${NAME}@${VERSION} already published"
  echo -e "${YELLOW}[!]${NC} Bump version in package.json first"
  exit 1
fi

# ── Publish ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}[*]${NC} Publishing to npm..."

# Set auth token for this publish
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc

npm publish --access public

# Clean up .npmrc
rm -f .npmrc

echo ""
echo -e "${GREEN}[+]${NC} Published ${NAME}@${VERSION}"
echo -e "${CYAN}[*]${NC} https://www.npmjs.com/package/${NAME}"
echo ""

# ── Tag the release ───────────────────────────────────────
if ! git tag -l "v${VERSION}" | grep -q .; then
  git tag "v${VERSION}"
  echo -e "${GREEN}[+]${NC} Tagged v${VERSION}"
  echo -ne "${CYAN}[?]${NC} Push tag to remote? (y/n): "
  read -r ans
  if [[ "$ans" =~ ^[Yy] ]]; then
    git push origin "v${VERSION}"
    echo -e "${GREEN}[+]${NC} Pushed tag v${VERSION}"
  fi
fi
