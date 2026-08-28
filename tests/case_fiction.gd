extends RefCounted

## Does the paperwork say what the machinery does.
##
## Every puzzle in this game is solved by reading a number off a document and
## acting on it, which means each one is a fact written down in two places: once
## in a `.tres` somebody wrote in-world, and once as a constant somebody typed.
## Nothing checks that they agree, and nothing would notice if they stopped —
## the game would keep passing every other test while being unsolvable, because
## the only thing broken is the relationship between what the player is told and
## what is true.
##
## Change `SET 30.5 FT` on the label to 29 and Act 4 has no puzzle in it. Change
## the sump's plate and P2.3 has no answer. This is the case that fails.

var _index: DocumentIndex


func run(tree: SceneTree, main: Node, expect: RefCounted) -> void:
	_index = (main.get_node("Journal") as Journal).index
	expect.ok(_index != null, "there is an index to look documents up in")

	_the_gauge_and_the_label(expect)
	_the_cams(expect)
	_the_panel_schedule(main, expect)
	_the_photometer(expect)
	_the_reel(expect)
	await tree.process_frame


## By id, not by filename. The id is what the game uses and what a save records,
## and looking them up this way means a document that is missing from the index
## fails here as well as in `case_reading`.
func _body(id: StringName) -> String:
	var document := _index.find(id) if _index != null else null
	return "" if document == null else document.body


## P4.2. The label on the box, and the number the gauge repeats.
func _the_gauge_and_the_label(expect: RefCounted) -> void:
	var label := _body(&"d21_bench_label")
	expect.ok(
		label.contains("SET %s FT" % _feet(GateLogic.FABRICATED_FEET)),
		"the box says what it is set to, and it is what it feeds (%.1f)"
			% GateLogic.FABRICATED_FEET
	)

	var record := _body(&"d22_stage_record")
	expect.ok(
		record.contains(_feet(GateLogic.TRUE_FEET)),
		"the gauge book says what the pool actually reads (%.1f)" % GateLogic.TRUE_FEET
	)
	expect.ok(
		record.contains("EXCEEDS %s FT" % _feet(GateLogic.LATCH_FEET)),
		"and what the sequence holds above (%.1f)" % GateLogic.LATCH_FEET
	)
	expect.ok(
		GateLogic.FABRICATED_FEET > GateLogic.LATCH_FEET
			and GateLogic.TRUE_FEET < GateLogic.LATCH_FEET,
		"which is the whole of P4.2: the lie is over the line and the truth is under it"
	)


## P3.1. Emil's notes are the only place the cam relationship is written.
func _the_cams(expect: RefCounted) -> void:
	var notes := _body(&"d16_cam_notes")
	expect.ok(
		notes.contains("%d TOOTH" % Timeclock.TEETH),
		"the notes say how many teeth a cam blank has (%d)" % Timeclock.TEETH
	)
	expect.ok(notes.contains("24 HR DRUM"), "and that the drum is twenty-four hours")
	expect.ok(
		notes.contains("TOOTH N COVERS HOUR 2N AND 2N+1"),
		"and state the relationship the puzzle turns on"
	)
	# The worked example on the card has to be a worked example of the thing the
	# clock actually does, or it is a trap.
	expect.ok(
		notes.contains("0600 / 2 = 3"),
		"with a worked example, in his hand"
	)
	expect.eq(int(6 / 2), 3, "and the clock agrees with his arithmetic")


## P2.3. Nine loads, and the schedule in the panel door.
func _the_panel_schedule(main: Node, expect: RefCounted) -> void:
	var schedule := _body(&"d09b_shelter_schedule")
	var runner: ActRunner = main.get_node("Acts")
	var act: Node = runner.acts[1].instantiate()
	var breakers: Node = act.get_node("Panel/Breakers")

	var wrong := PackedStringArray()
	var total := 0.0
	for node in breakers.get_children():
		var breaker := node as DeviceToggle
		if breaker == null:
			continue
		total += breaker.load_kw
		if not schedule.contains("%.1f" % breaker.load_kw):
			wrong.append("%s is %.1f kW and the schedule does not say so"
				% [breaker.name, breaker.load_kw])
	expect.ok(wrong.is_empty(), "every load's plate is in the schedule (%s)" % " | ".join(wrong))
	expect.ok(
		schedule.contains("%.1f" % total),
		"and the connected total is the sum of them (%.1f)" % total
	)
	expect.ok(
		schedule.contains("30 KW") or _body(&"d09_generator_card").contains("30 KW"),
		"and the set's plate says what ShelterLoad thinks it is (%.0f)" % ShelterLoad.CAPACITY_KW
	)
	act.free()


## P3.2. The certification log is what tells the player what a reading means.
func _the_photometer(expect: RefCounted) -> void:
	var record := _body(&"d18_photometer_log")
	expect.ok(record.contains("2.0M"), "the log gives the standing distance")
	expect.ok(record.contains("120"), "and the reading a good lamp gives at it")

	# The instrument has to agree. A sodium bulkhead at two metres reads about
	# 120 lx, which is the constant the meter is calibrated with.
	var meter: Node3D = load("res://src/world/tools/photometer.tscn").instantiate()
	var instrument: Photometer = meter.get_node("Meter")
	var reading := 4.2 * instrument.calibration / (2.0 * 2.0)
	expect.near(reading, 120.0, 8.0, "and the meter reads it (%.0f lx)" % reading)
	meter.free()


## P3.4. Two documents and a boxing rule give one accession.
func _the_reel(expect: RefCounted) -> void:
	var index := _body(&"d19_reel_index")
	var admission := _body(&"d20_admission_sheet")
	expect.ok(index.contains("RF-0801 to 0840"), "the index gives Run 9's block")
	expect.ok(index.contains("BOX A"), "and the rule that names a reel by its box")
	expect.ok(admission.contains("40 DAYS") or admission.contains("40 days"),
		"the admission sheet's amendment gives the fortieth day")
	expect.ok(
		AnnexLogic.RUN_9_LAST == "RF-0840",
		"and the last of the block is what the act is looking for (%s)"
			% AnnexLogic.RUN_9_LAST
	)


## `30.5`, `21.4`, `30.0` -- the way a document writes a stage.
func _feet(value: float) -> String:
	return "%.1f" % value
