extends SceneTree
## Run with a real renderer to check the actual arc direction, color and score.

var _scene: Node
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Board feedback checks require a real renderer; omit --headless.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	_scene = load("res://game/main.tscn").instantiate()
	root.add_child(_scene)
	_scene.set_physics_process(false)
	_scene.audio.enabled = false
	_scene.start_game()
	_scene.next_wave_time = 1000.0
	await _capture("initial")
	var center: Label = _scene.board_view.get_node("CenterScore")
	_check(center.text == "0", "center starts at zero")
	var radius: float = _scene.board_view.get_buff_ring_radius()
	_check(is_equal_approx(radius, (48.0 + 10.0 * 17.0) / cos(PI / 6.0)), "ring follows the outer hexagon's circumcircle")
	for color_index: int in range(4):
		_scene.start_game()
		_scene.next_wave_time = 1000.0
		_clear(color_index)
		var screenshot: Image = await _capture("color_%d" % color_index)
		_check(center.text == "18", "center shows actual clear score")
		_check(_scene.board_view.last_clear_color_index == color_index, "ring remembers the most recent clear color")
		_check(is_equal_approx(_scene.board_view.get_buff_fraction(), 1.0), "clear fills the complete five-second ring")
		for angle: float in [45.0, 135.0, 225.0, 315.0]:
			_check(_has_color(screenshot, angle, color_index), "full ring uses clear color at every quadrant")
	_scene.start_game()
	_scene.next_wave_time = 1000.0
	_clear(0)
	_scene.step_game(1.25)
	var quarter: Image = await _capture("quarter_elapsed")
	_check(is_equal_approx(_scene.board_view.get_buff_fraction(), 0.75), "ring follows remaining buff time")
	_check(not _has_color(quarter, 45.0, 0), "clockwise consumption removes the upper-right quadrant first")
	for angle: float in [135.0, 225.0, 315.0]:
		_check(_has_color(quarter, angle, 0), "unconsumed arc remains colored after one quarter")
	_scene.step_game(1.25)
	var half: Image = await _capture("half_elapsed")
	_check(not _has_color(half, 45.0, 0) and not _has_color(half, 135.0, 0), "right semicircle is depleted halfway through")
	_check(_has_color(half, 225.0, 0) and _has_color(half, 315.0, 0), "left semicircle remains halfway through")
	_clear(3)
	var refreshed: Image = await _capture("refreshed_blue")
	_check(center.text == "54", "center adds the combo multiplier to total score")
	_check(is_equal_approx(_scene.board_view.get_buff_fraction(), 1.0), "follow-up refills the timer ring")
	_check(_has_color(refreshed, 45.0, 3), "follow-up switches the circle to the new clear color")
	_scene.toggle_pause()
	_scene.step_game(2.0)
	_check(is_equal_approx(_scene.board_view.get_buff_fraction(), 1.0), "pause freezes the same timer used by the ring")
	_scene.toggle_pause()
	_scene.step_game(5.0)
	var expired: Image = await _capture("expired")
	_check(_scene.scoring.consecutive_clear_count == 0 and _scene.board_view.get_buff_fraction() == 0.0, "buff and colored arc expire together")
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		_check(not _has_color(expired, angle, 3), "expired ring has no remaining colored segment")
	_check(center.text == "54", "buff expiry preserves the displayed total score")
	_scene.board.stacks[0] = PackedInt32Array([0, 0, 0])
	_scene.board.stacks[3] = PackedInt32Array([2, 2, 2])
	_scene._resolve_matches()
	var mixed: Image = await _capture("last_group_green")
	_check(center.text == "90", "simultaneous groups retain one scoring event")
	_check(_scene.board_view.last_clear_color_index == 2 and _has_color(mixed, 45.0, 2), "last connected group determines a multicolor batch's ring")
	_scene.rotate_board(1)
	_scene.step_game(0.07)
	await _capture("rotating")
	_check(absf(center.get_global_transform().get_rotation()) < 0.0001, "center score stays upright during rotation")
	_scene.scoring.total_score = 123456789
	await _capture("large_score")
	var font: Font = center.get_theme_font("font")
	var font_size: int = center.get_theme_font_size("font_size")
	_check(center.text == "123456789" and font.get_string_size(center.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= 64.0, "large scores fit inside the core")
	_scene.start_game()
	var reset: Image = await _capture("restart")
	_check(center.text == "0" and _scene.board_view.last_clear_color_index == -1, "restart resets center and last clear color")
	_check(not _has_color(reset, 45.0, 2), "restart removes the prior buff ring")
	if _failures == 0:
		print("PASS: rendered center score and clockwise buff ring (%d checks)." % _checks)
	else:
		printerr("FAIL: %d of %d board feedback checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _clear(color_index: int) -> void:
	_scene.board.stacks[0] = PackedInt32Array([color_index, color_index, color_index])
	_scene._resolve_matches()


func _capture(label: String) -> Image:
	_scene._update_hud()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	_check(screenshot.save_png("res://artifacts/board_feedback_%s.png" % label) == OK, "save rendered feedback state")
	return screenshot


func _has_color(screenshot: Image, angle: float, color_index: int) -> bool:
	var position: Vector2 = _scene.board_view.position + Vector2.UP.rotated(deg_to_rad(angle)) * _scene.board_view.get_buff_ring_radius()
	position = root.get_final_transform() * position
	var actual: Color = screenshot.get_pixelv(Vector2i(position.round()))
	var expected: Color = _scene.rules.block_colors[color_index]
	return Vector3(actual.r, actual.g, actual.b).distance_to(Vector3(expected.r, expected.g, expected.b)) < 0.12


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % description)
