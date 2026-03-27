#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/PaloAltoNetworks/docusaurus-openapi-docs"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Node version ---
# Docusaurus 3.9.2, Yarn 1 monorepo — requires Node 20+
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20

node --version
npm --version

# --- Package manager + dependencies ---
# Yarn 1 (classic) monorepo with lerna and yarn workspaces
npm install -g yarn@1.22.1
yarn install --frozen-lockfile

# --- Pre-build steps ---
# Build local workspace packages (docusaurus-plugin-openapi-docs, docusaurus-theme-openapi-docs)
# These must be compiled before Docusaurus commands can run in demo/
yarn build-packages

# Generate API docs (required by sidebars.ts which imports generated files)
cd demo
yarn gen-all

# Return to repo root for patch
cd ..

# Patch plugin-content-docs to warn instead of throw on duplicate sidebar entries.
# The httpbin OpenAPI spec generates duplicate labels (same summary for multiple HTTP methods),
# which causes write-translations to fail in Docusaurus 3.9.2+.
TRANSLATIONS_JS="node_modules/@docusaurus/plugin-content-docs/lib/translations.js"
sed -i 's/throw new Error(`Multiple docs sidebar items/console.warn(`[PageTurner] Ignoring duplicate sidebar entries: Multiple docs sidebar items/' "$TRANSLATIONS_JS"

echo "[DONE] Repository is ready for docusaurus commands."
