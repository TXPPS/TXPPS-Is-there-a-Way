extends RefCounted

## The reserved rect contract: the controls own their area, they do not overlap
## each other, and they are inside the safe rect and big enough to hit.

const MIN_TOUCH_POINTS := 44.0
const PROBE_SIZE := Vector2(120.0, 60.0)


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	var hud: Hud = main.get_node("Hud")
	var rects: HudRects = hud.get_node("HudRects")
	var safe: SafeArea = hud.get_node("SafeArea")
	var layout: HudLayout = hud.layout
	await tree.process_frame

	var live: Dictionary = rects.rects()
	expect.ok(live.size() >= 4, "the sticks, the pause button and the action arc are all reserved")
	_no_overlaps(live, expect)
	_on_screen(live, tree.root.get_visible_rect(), expect)
	_drawn_inside_safe(hud, layout, safe.rect(), expect)

	var scale := safe.points_to_units()
	for id in live:
		var area: Rect2 = live[id]

		expect.ok(
			minf(area.size.x, area.size.y) >= MIN_TOUCH_POINTS * scale - 0.5,
			"'%s' is at least %d points across (%.0f units, scale %.2f)"
				% [id, int(MIN_TOUCH_POINTS), minf(area.size.x, area.size.y), scale]
		)

	var middle := Rect2(
		tree.root.get_visible_rect().get_center() - PROBE_SIZE * 0.5, PROBE_SIZE
	)
	expect.ok(rects.is_clear(middle), "the middle of the screen is free for a prompt")
	var over_stick := Rect2(live[Hud.MOVE].get_center() - PROBE_SIZE * 0.5, PROBE_SIZE)
	expect.ok(
		not rects.is_clear(over_stick),
		"a prompt placed on the movement stick is refused"
	)
	expect.ok(
		rects.blocks_point(live[Hud.LOOK].get_center()),
		"world targeting is blocked through a reserved rect"
	)
	expect.ok(
		layout.action_centre(safe.rect(), Vector2.ZERO, 0).y < live[Hud.LOOK].get_center().y,
		"the action arc sits above the look stick, in the same thumb's reach"
	)


func _no_overlaps(live: Dictionary, expect: RefCounted) -> void:
	var ids: Array = live.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Rect2 = live[ids[i]]
			var b: Rect2 = live[ids[j]]
			expect.ok(not a.intersects(b), "'%s' and '%s' do not overlap" % [ids[i], ids[j]])


## A claim region is allowed to run out to the screen edge -- a thumb that lands
## just short of the stick should still find it -- but it may never run off the
## screen, which would be area the player cannot reach.
func _on_screen(live: Dictionary, screen: Rect2, expect: RefCounted) -> void:
	for id in live:
		var area: Rect2 = live[id]
		expect.ok(
			screen.intersection(area).get_area() > area.get_area() * 0.5,
			"'%s' is mostly on screen (%s within %s)" % [id, area, screen]
		)


## What is *drawn* is what has to clear the notch and the home indicator.
func _drawn_inside_safe(
	hud: Hud, layout: HudLayout, safe: Rect2, expect: RefCounted
) -> void:
	var drawn: Dictionary = {
		"move stick": _around(hud.get_node("Controls/MoveStick").position, layout.stick_radius),
		"look stick": _around(hud.get_node("Controls/LookStick").position, layout.stick_radius),
		"pause button": _around(hud.get_node("Controls/PauseButton").position, layout.pause_radius),
	}
	for slot in Hud.ACTION_SLOTS:
		drawn["action button %d" % slot] = _around(
			layout.action_centre(safe, Vector2.ZERO, slot), layout.action_button_radius
		)
	for what in drawn:
		expect.ok(
			safe.encloses(drawn[what]),
			"the %s is drawn inside the safe area (%s within %s)" % [what, drawn[what], safe]
		)


func _around(centre: Vector2, radius: float) -> Rect2:
	return Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
