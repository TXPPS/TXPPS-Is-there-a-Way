#!/usr/bin/env bash
# One command, identical locally and in CI: stamp -> import -> export -> harden
# -> budget check. If this passes, the build is shippable.
set -euo pipefail

GODOT="${GODOT:-godot}"
BUILD_DIR="${BUILD_DIR:-build}"
PRESET="${PRESET:-Web}"

cd "$(dirname "$0")/../.."

echo "==> stamping build"
python3 tools/ci/stamp_build.py

echo "==> regenerating art (must be byte-identical to what is committed)"
python3 tools/gen/make_icons.py
if ! git diff --quiet -- assets/icons; then
	echo "error: committed art does not match tools/gen/make_icons.py output." >&2
	echo "       Either the generator changed and the output was not re-committed," >&2
	echo "       or the art was hand-edited. Run the generator and commit the result." >&2
	git --no-pager diff --stat -- assets/icons >&2
	exit 1
fi

echo "==> fencing the output directory off from the resource scanner"
# A .gdignore keeps Godot from importing the previous build (a 37 MB wasm) back
# into the next one. It must exist before any --import runs.
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
: > "$BUILD_DIR/.gdignore"

echo "==> importing resources"
# Import twice: the first pass creates .godot/, the second resolves anything
# that needed the class cache the first pass was still building.
"$GODOT" --headless --import >/dev/null
"$GODOT" --headless --import >/dev/null

echo "==> checking scripts and scenes load cleanly"
LOG="$(mktemp)"
"$GODOT" --headless --quit-after 120 2>&1 | tee "$LOG"
if grep -qiE '(SCRIPT ERROR|SCRIPT_ERROR|Parse Error|ERROR:|Failed to load)' "$LOG"; then
	echo "error: the project logged errors on startup (see above)." >&2
	exit 1
fi

echo "==> headless suite: input, pause, HUD layout, settings"
# Everything a browser cannot see: multi-touch ownership, the reserved rect
# contract, pause, and settings persistence. See docs/TESTING.md.
TEST_LOG="$(mktemp)"
"$GODOT" --headless --script res://tests/run_tests.gd 2>&1 | tee "$TEST_LOG"
if grep -qiE '(SCRIPT ERROR|Parse Error|ERROR:)' "$TEST_LOG"; then
	echo "error: the headless suite logged errors (see above)." >&2
	exit 1
fi
grep -q "checks passed" "$TEST_LOG" || { echo "error: the headless suite did not pass." >&2; exit 1; }

echo "==> exporting $PRESET"
EXPORT_LOG="$(mktemp)"
if ! "$GODOT" --headless --export-release "$PRESET" "$BUILD_DIR/index.html" 2>&1 | tee "$EXPORT_LOG"; then
	echo "error: godot exited non-zero during export." >&2
	exit 1
fi
if grep -qiE '(ERROR:|Failed to load|Could not find template|export template)' "$EXPORT_LOG"; then
	echo "error: the export logged errors (see above)." >&2
	exit 1
fi
test -f "$BUILD_DIR/index.wasm" || { echo "error: export produced no wasm" >&2; exit 1; }

echo "==> hardening for cache + verifying the export variant"
python3 tools/ci/postprocess_web.py --build "$BUILD_DIR"

rm -f "$BUILD_DIR/.gdignore"

echo "==> budgets"
python3 tools/ci/check_budgets.py --build "$BUILD_DIR"

echo "==> done: $BUILD_DIR"
