class_name Notify
extends RefCounted

## A line of text the player can read, on a device with no console.
##
## The HTML shell already owns the toast stack -- it has to, because it shows
## errors from before the engine exists -- so this is a doorway to it rather
## than a second implementation.

const CALL := "window.__itaw_note && window.__itaw_note(%s, %s)"


static func say(text: String, kind: String = "note") -> void:
	if not OS.has_feature("web"):
		# Deliberately not the word "error": tools/ci/build_web.sh greps the
		# suite's output for it, and a message about a failed save is not a
		# failure of the build.
		print("· %s (%s)" % [text, kind])
		return
	JavaScriptBridge.eval(CALL % [JSON.stringify(text), JSON.stringify(kind)], true)


static func problem(text: String) -> void:
	say(text, "error")
