#!/usr/bin/env bash
# Build the flashable module zip from ./module
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f module/module.prop ]; then
    echo "error: module/module.prop not found" >&2
    exit 1
fi

VER=$(sed -n 's/^version=//p' module/module.prop | head -n1)
NAME="Guardian-${VER}.zip"
mkdir -p dist
rm -f "dist/$NAME"

# The zip must have module.prop at its ROOT, so zip the *contents* of module/.
(
    cd module
    zip -r9 -q "../dist/$NAME" . \
        -x '*.DS_Store' '*/.git/*' '*.gitkeep'
)

echo "built dist/$NAME"
echo
unzip -l "dist/$NAME" | tail -n 6
echo
echo "size: $(du -h "dist/$NAME" | cut -f1)"
