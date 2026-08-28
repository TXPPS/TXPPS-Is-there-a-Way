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

echo "==> regenerating audio (must be byte-identical to what is committed)"
python3 tools/audio/make_audio.py >/dev/null
# Only the generated WAVs. The bus layout and the import settings live in the
# same directory and are hand-authored.
if ! git diff --quiet -- 'assets/audio/*.wav'; then
	echo "error: committed audio does not match tools/audio/make_audio.py output." >&2
	echo "       Either a generator changed and the output was not re-committed," >&2
	echo "       or a WAV was edited by hand. Run the generator and commit." >&2
	git --no-pager diff --stat -- 'assets/audio/*.wav' >&2
	exit 1
fi

echo "==> checking assets are imported the way they are meant to be"
python3 tools/ci/check_imports.py || exit 1

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

echo "==> headless suite: scenes load, input, pause, HUD layout, settings"
# This is also the "does the project boot without errors" check. It has to be:
# a plain `--quit-after` run opens a placeholder window a few dozen pixels wide,
# the canvas_items stretch then scales that up to the design width, and every
# HUD rect the layout computes is nonsense -- including the ones HudRects
# asserts on. The suite loads the same main scene at real device metrics and
# then drives it, which is strictly more than the old check did.
TEST_LOG="$(mktemp)"
"$GODOT" --headless --script res://tests/run_tests.gd 2>&1 | tee "$TEST_LOG"
grep -q "checks passed" "$TEST_LOG" || { echo "error: the headless suite did not pass." >&2; exit 1; }

# Only the part of the log produced while the suite was running counts. After
# the summary line comes teardown, and teardown races the audio server: it holds
# a playback for a moment after a player stops, so the engine intermittently
# reports "resources still in use at exit". Freeing the tree by hand first makes
# it intermittent; not freeing makes it certain; there is no third option from
# GDScript. It says nothing about the run, and the run is what this checks.
sed '/^headless: /q' "$TEST_LOG" > "$TEST_LOG.run"
if grep -qiE '(SCRIPT ERROR|Parse Error|ERROR:)' "$TEST_LOG.run"; then
	echo "error: the headless suite logged errors (see above)." >&2
	exit 1
fi

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
