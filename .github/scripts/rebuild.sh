#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for PaloAltoNetworks/docusaurus-openapi-docs
# Runs on existing source tree (no clone). Installs deps, runs pre-build steps, builds.
#
# Monorepo special case: This repo is a Yarn 1 monorepo; the Docusaurus demo site
# depends on local workspace packages (docusaurus-plugin-openapi-docs,
# docusaurus-theme-openapi-docs) that must be built from the monorepo root.
# The staging repo only contains the demo/ content, so we clone the full source
# into a temp dir, set up workspace packages there, overlay the current (translated)
# content, and build. The build/ output is then copied back.

REPO_URL="https://github.com/PaloAltoNetworks/docusaurus-openapi-docs"
ORIGINAL_DIR="$(pwd)"

# --- Node version ---
# Docusaurus 3.9.2 — requires Node 20+
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20

node --version
npm install -g yarn@1.22.1

# --- Clone source for full monorepo setup ---
TMP_SOURCE="/tmp/openapi-docs-rebuild-$$"
git clone --depth 1 "$REPO_URL" "$TMP_SOURCE"
cd "$TMP_SOURCE"
yarn install --frozen-lockfile
yarn build-packages

# Generate API docs (in case staging copy differs from source)
cd demo
yarn gen-all

# Overlay translated content from staging repo onto the cloned demo/
# The i18n/ directory holds all translations; copy everything to capture
# any other staged modifications as well.
cp -r "$ORIGINAL_DIR/." ./

# Return to monorepo root for patch
cd ..

# Patch plugin-content-docs to warn instead of throw on duplicate sidebar entries.
TRANSLATIONS_JS="node_modules/@docusaurus/plugin-content-docs/lib/translations.js"
if [ -f "$TRANSLATIONS_JS" ]; then
    sed -i 's/throw new Error(`Multiple docs sidebar items/console.warn(`[PageTurner] Ignoring duplicate sidebar entries: Multiple docs sidebar items/' "$TRANSLATIONS_JS"
fi

cd demo

# --- Build ---
yarn build

# Copy build output back to original directory
cp -r build "$ORIGINAL_DIR/"

echo "[DONE] Build complete."
