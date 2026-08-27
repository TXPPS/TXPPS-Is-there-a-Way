extends RefCounted

## Assertion tally for the headless suites. Deliberately not a framework: every
## case is a plain method that pushes input and checks numbers, because the
## thing under test is a control scheme and the interesting failures are all
## arithmetic.

var failures := PackedStringArray()
var passes := 0


func ok(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("  ok    %s" % message)
		return
	failures.append(message)
	print(" FAIL   %s" % message)


func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	ok(
		absf(actual - expected) <= epsilon,
		"%s (%.4f vs %.4f +-%.4f)" % [message, actual, expected, epsilon]
	)


func same(actual: Vector2, expected: Vector2, message: String) -> void:
	ok(actual == expected, "%s (%s vs %s)" % [message, actual, expected])


func report(label: String) -> int:
	if failures.is_empty():
		print("\n%s: %d checks passed" % [label, passes])
		return 0
	print("\n%s: %d of %d checks FAILED" % [label, failures.size(), passes + failures.size()])
	for failure in failures:
		print("  - %s" % failure)
	return 1
