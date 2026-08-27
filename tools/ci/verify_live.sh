#!/usr/bin/env bash
# Prove the published site is this build, and that it can actually load.
#
# A deploy job that reports success is not the same claim. The artifact can be
# right and the site still be serving last week's document, or 404 the payload,
# or hand back the wasm with a content type that stops the engine streaming it.
# So: fetch the URL the deploy just published, read the build stamp out of it,
# and pull every file index.html names.
#
#   bash tools/ci/verify_live.sh <url> [expected-commit-sha]
set -euo pipefail

URL="${1:?usage: verify_live.sh <url> [sha]}"
EXPECT_SHA="${2:-}"
URL="${URL%/}"

# GitHub Pages takes a moment to serve what it has just accepted.
TRIES=30
DELAY=6

fail() { echo "error: $*" >&2; exit 1; }

header() {  # header <url> <name>
	curl -sSI --max-time 30 "$1" | tr -d '\r' \
		| awk -v k="$(echo "$2" | tr 'A-Z' 'a-z')" 'BEGIN{IGNORECASE=1} tolower($1)==k":"{ $1=""; sub(/^ /,""); print }' \
		| tail -1
}

status() { curl -sS -o /dev/null -w '%{http_code}' --max-time 60 "$1"; }

echo "==> waiting for $URL"
for i in $(seq 1 "$TRIES"); do
	CODE="$(status "$URL/")"
	echo "    [$i/$TRIES] HTTP $CODE"
	[ "$CODE" = "200" ] && break
	[ "$i" = "$TRIES" ] && fail "$URL/ never returned 200 (last: $CODE)"
	sleep "$DELAY"
done

DOC="$(curl -sS --max-time 60 "$URL/")"

echo "==> the document is the shell"
case "$DOC" in
	*'id="begin"'*) ;;
	*) fail "the served document has no tap gate -- this is not our shell" ;;
esac
case "$DOC" in
	*'window.__itaw_checkForUpdate'*) ;;
	*) fail "the served document has no inlined boot script" ;;
esac

STAMP="$(printf '%s' "$DOC" | grep -o 'window.ITAW_BUILD = {[^}]*}' | head -1)"
[ -n "$STAMP" ] || fail "the served document carries no build stamp"
COMMIT="$(printf '%s' "$STAMP" | grep -o '"commit": "[0-9a-f]*"' | cut -d'"' -f4)"
VERSION="$(printf '%s' "$STAMP" | grep -o '"version": "[^"]*"' | cut -d'"' -f4)"
echo "    live stamp: v$VERSION ${COMMIT:0:7}"

if [ -n "$EXPECT_SHA" ] && [ "$COMMIT" != "$EXPECT_SHA" ]; then
	fail "the site is serving ${COMMIT:0:7}, not the commit that just deployed (${EXPECT_SHA:0:7})"
fi

EXE="$(printf '%s' "$DOC" | grep -o '"executable":"[^"]*"' | cut -d'"' -f4)"
[ -n "$EXE" ] || fail "the served document names no engine payload"
echo "==> the payload it names is actually there ($EXE)"

check() {  # check <path> <expected-content-type-or-empty> <label>
	local path="$1" want="$2" label="$3" code type
	code="$(status "$URL/$path")"
	type="$(header "$URL/$path" 'content-type')"
	printf '    %-46s %s  %s\n' "$path" "$code" "${type:-(none)}"
	[ "$code" = "200" ] || fail "$label: $path returned $code"
	if [ -n "$want" ]; then
		case "$type" in
			"$want"*) ;;
			*) fail "$label: $path is '$type', expected '$want'" ;;
		esac
		return 0
	fi
	# No expectation of its own, so the only thing worth catching is a host that
	# answers a missing file with its 404 page and a 200 status.
	case "$type" in
		text/html*) fail "$label: $path came back as HTML -- that is a 404 page wearing a 200" ;;
	esac
}

# The wasm content type is the one that matters functionally: without
# application/wasm the engine cannot use WebAssembly.instantiateStreaming and
# falls back to buffering the whole 37 MB first.
check "$EXE.wasm" "application/wasm" "engine"
check "$EXE.pck"  ""                 "data pack"
check "$EXE.js"   ""                 "engine loader"
check "index.service.worker.js" ""   "service worker"
check "index.manifest.json"     ""   "manifest"
check "index.offline.html" "text/html" "offline page"

{
	echo "### Live and verified"
	echo
	echo "- $URL/"
	echo "- stamp \`v$VERSION ${COMMIT:0:7}\`"
	echo "- payload \`$EXE\`"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

echo "==> $URL/ is live and is v$VERSION ${COMMIT:0:7}"
