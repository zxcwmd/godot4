#!/usr/bin/env bash
# Uses a locally installed Godot 4 editor; no package manager or plugins needed.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$GODOT" --headless --path . --editor --import --quit 2>&1 | tee "$log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:' "$log"; then exit 1; fi
"$GODOT" --headless --path . --script tests/smoke.gd 2>&1 | tee "$log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|FAIL:' "$log"; then exit 1; fi
