class_name Haptics
extends RefCounted

## A short tap, where the platform allows one.
##
## iOS Safari does not implement navigator.vibrate, so on the device this is
## currently a no-op and the setting is honest about that. It exists now so the
## call sites are already right on Android and in a future wrapper, rather than
## being retrofitted into every button later.

const DEFAULT_MS := 12

static var enabled := true


static func tap(milliseconds: int = DEFAULT_MS) -> void:
	if not enabled:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"navigator.vibrate && navigator.vibrate(%d)" % milliseconds, true
		)
		return
	Input.vibrate_handheld(milliseconds)
