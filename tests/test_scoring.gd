extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_scoring.gd

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_score_formula()
	_test_refreshed_window_and_expiry()
	_test_varying_clear_sizes()
	_test_invalid_clears()
	_test_reset()
	_test_scene_integration()
	if _failures == 0:
		print("PASS: scoring (%d checks)." % _checks)
	else:
		printerr("FAIL: %d of %d scoring checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _test_score_formula() -> void:
	var rules := GameRules.new()
	_check(rules.get_clear_score(3, 1) == 18, "opening clear: 18")
	_check(rules.get_clear_score(3, 2) == 36, "second clear: 36")
	_check(rules.get_clear_score(3, 3) == 54, "third clear: 54")
	_check(rules.get_clear_score(5, 4) == 120, "five blocks on fourth clear: 120")
	_check(rules.get_clear_score(3, 12) == 216, "combo is not capped at two")
	_check(rules.get_clear_score(2, 1) == 0, "too few blocks cannot score")
	_check(rules.get_clear_score(3, 0) == 0, "zero clear count cannot score")
	_check(is_equal_approx(rules.get_spawn_interval(999), 2.0), "999-point interval")
	_check(is_equal_approx(rules.get_spawn_interval(1000), 1.9), "1000-point interval")
	_check(is_equal_approx(rules.get_spawn_interval(9999), 1.1), "last interval above minimum")
	_check(is_equal_approx(rules.get_spawn_interval(10000), 1.0), "interval minimum")
	_check(is_equal_approx(rules.get_spawn_interval(100000), 1.0), "interval stays at minimum")


func _test_refreshed_window_and_expiry() -> void:
	var scoring := ScoreManager.new()
	_check(scoring.register_clear(3) == 18, "first elimination")
	_check(scoring.consecutive_clear_count == 1, "opening clear counts as one")
	_check(is_equal_approx(scoring.buff_time_left, 5.0), "opening window is five seconds")
	scoring.advance_time(4.5)
	_check(scoring.register_clear(3) == 36, "follow-up within window")
	_check(is_equal_approx(scoring.buff_time_left, 5.0), "follow-up refreshes to five seconds")
	scoring.advance_time(4.5)
	_check(scoring.register_clear(3) == 54, "combo survives past original expiry after refresh")
	_check(scoring.total_score == 108, "18 + 36 + 54 = 108")
	scoring.advance_time(5.0)
	_check(scoring.consecutive_clear_count == 0, "exact expiry clears combo count")
	_check(scoring.buff_time_left == 0.0, "exact expiry clears timer")
	_check(scoring.total_score == 108, "expiry preserves total score")
	_check(scoring.register_clear(3) == 18, "exact expiry starts again at one")
	scoring.advance_time(10.0)
	_check(scoring.buff_time_left == 0.0, "long frame clamps timer to zero")
	_check(scoring.register_clear(3) == 18, "after expiry scores base points")
	scoring.free()


func _test_varying_clear_sizes() -> void:
	var scoring := ScoreManager.new()
	_check(scoring.register_clear(3) == 18, "three blocks at multiplier one")
	_check(scoring.register_clear(4) == 48, "four blocks at multiplier two")
	_check(scoring.register_clear(5) == 90, "five blocks at multiplier three")
	_check(scoring.consecutive_clear_count == 3, "count is eliminations, not blocks")
	_check(scoring.total_score == 156, "mixed-size eliminations add correctly")
	scoring.free()


func _test_invalid_clears() -> void:
	var scoring := ScoreManager.new()
	for count: int in [-1, 0, 1, 2]:
		_check(scoring.register_clear(count) == 0, "invalid opening size %d" % count)
	_check(scoring.total_score == 0, "invalid clears do not add points")
	_check(scoring.consecutive_clear_count == 0, "invalid clears do not start combo")
	_check(scoring.buff_time_left == 0.0, "invalid clears do not start window")
	scoring.register_clear(3)
	scoring.advance_time(4.5)
	_check(scoring.register_clear(2) == 0, "invalid follow-up cannot score")
	_check(scoring.consecutive_clear_count == 1, "invalid follow-up cannot increment combo")
	_check(is_equal_approx(scoring.buff_time_left, 0.5), "invalid follow-up cannot refresh window")
	scoring.advance_time(0.5)
	_check(scoring.register_clear(3) == 18, "invalid follow-up cannot extend combo")
	scoring.free()


func _test_reset() -> void:
	var scoring := ScoreManager.new()
	scoring.register_clear(3)
	scoring.register_clear(3)
	scoring.reset()
	_check(scoring.total_score == 0, "restart clears score")
	_check(scoring.consecutive_clear_count == 0, "restart clears combo")
	_check(scoring.buff_time_left == 0.0, "restart clears timer")
	_check(scoring.register_clear(3) == 18, "new run starts with base points")
	scoring.free()


func _test_scene_integration() -> void:
	var packed_scene := load("res://game/main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	var scoring := scene.get_node("ScoreManager") as ScoreManager
	_check(scoring != null, "main scene contains score manager")
	_check(scoring.rules == scene.rules, "scene shares its configured rules")
	_check(scoring.register_clear(3) == 18, "scene component can score an opening clear")
	scoring._process(5.0)
	_check(scoring.consecutive_clear_count == 0, "frame processing expires the combo")
	scene.free()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
