#!/usr/bin/env bash
# Install git aliases by symlinking bin/ scripts onto PATH
# Usage: ./install.sh

set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")/bin" && pwd)"
TARGET="${1:-$HOME/.local/bin}"

mkdir -p "$TARGET"

for script in "$BIN_DIR"/git-*; do
  name=$(basename "$script")
  ln -sf "$script" "$TARGET/$name"
  echo "  $name → $TARGET/$name"
done

echo ""
echo "Ensure $TARGET is on your PATH:"
echo "  export PATH=\"$TARGET:\$PATH\""
echo ""

# Set required git config
git config --global rebase.autoSquash true
git config --global rebase.updateRefs true
echo "Set rebase.autoSquash=true and rebase.updateRefs=true"

# Register global git aliases pointing to the scripts
for script in "$BIN_DIR"/git-*; do
  name=$(basename "$script")
  alias_name="${name#git-}"
  git config --global alias."$alias_name" "!$script"
  echo "  git $alias_name → $script"
done

echo ""
echo "Installed: git amd, git cmt, git fix, git fp, git rb"
