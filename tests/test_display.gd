extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _scene: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Display checks require a real window; omit --headless.")
		quit(2)
		return
	_scene = load("res://game/main.tscn").instantiate()
	root.add_child(_scene)
	_scene.set_physics_process(false)
	_scene.audio.enabled = false
	await _settle()
	print("Display: %s; screen: %s; initial window: %s" % [DisplayServer.get_name(), DisplayServer.screen_get_size(), root.size])
	_check(root.size == Vector2i(1600, 900), "default window is 1600 by 900")
	await _capture("default")
	# Alt+Enter also contains Enter: toggling must leave the ready screen intact.
	await _key(KEY_ENTER, true)
	_check(_fullscreen(), "Alt+Enter enters fullscreen from ready screen")
	_check(_scene.state == _scene.RunState.READY, "Alt+Enter does not also start play")
	await _capture("fullscreen_ready")
	await _key(KEY_F11)
	_check(not _fullscreen() and root.size == Vector2i(1600, 900), "F11 restores the default window")
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1600, 1000), Vector2i(1920, 720)]:
		root.size = size
		await _settle()
		_check_scaling()
		await _key(KEY_R)
		await _key(KEY_P)
		_check(_scene.state == _scene.RunState.PAUSED, "pause before scaled mouse check at %s" % size)
		await _click(Vector2(640, 445))
		_check(_scene.state == _scene.RunState.PLAYING, "scaled resume button hit at %s" % size)
		await _click(Vector2(1087, 45))
		_check(_scene.state == _scene.RunState.PAUSED, "scaled toolbar button hit at %s" % size)
		await _capture("%dx%d" % [size.x, size.y])
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.position = Vector2i(80, 80)
	await _settle()
	await _key(KEY_R)
	_scene.wave_generator.random.seed = 20261017
	for frame: int in range(1080):
		if frame % 137 == 0:
			_scene.rotate_board(1 if frame % 274 == 0 else -1)
		_scene.step_game(1.0 / 60.0)
		_scene.board_view._process(1.0 / 60.0)
	_scene._update_hud()
	await _capture("playing")
	var window_size: Vector2i = root.size
	var window_position: Vector2i = root.position
	var score: int = _scene.scoring.total_score
	var wave_time: float = _scene.next_wave_time
	await _click(Vector2(975, 45))
	_check(_fullscreen(), "toolbar enters fullscreen")
	_check_scaling()
	_check(_scene.scoring.total_score == score and _scene.next_wave_time == wave_time, "fullscreen preserves game progress")
	_check(_scene.hud._fullscreen.text == "F11 窗口", "fullscreen button offers window mode")
	await _capture("fullscreen_playing")
	await _key(KEY_F11, false, true)
	_check(_fullscreen(), "key repeat does not toggle fullscreen")
	await _key(KEY_F11)
	_check(not _fullscreen(), "F11 exits fullscreen during play")
	_check(root.size == window_size and root.position == window_position, "window size and position restored")
	await _click(Vector2(1087, 45))
	await _key(KEY_F11)
	_check(_fullscreen() and _scene.state == _scene.RunState.PAUSED, "fullscreen toggle preserves pause")
	await _key(KEY_ENTER, true)
	_check(not _fullscreen() and _scene.state == _scene.RunState.PAUSED, "Alt+Enter exits without resuming pause")
	root.mode = Window.MODE_MAXIMIZED
	await _settle()
	_check_scaling()
	_check(root.get_final_transform().x.length() > 1.25, "maximizing enlarges the actual game canvas")
	await _capture("maximized")
	await _key(KEY_F11)
	await _key(KEY_F11)
	_check(root.mode == Window.MODE_MAXIMIZED, "maximized window mode restored")
	root.mode = Window.MODE_WINDOWED
	if _failures == 0:
		print("PASS: display scaling, mouse alignment and fullscreen (%d checks)." % _checks)
	else:
		printerr("FAIL: %d of %d display checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _check_scaling() -> void:
	var transform: Transform2D = root.get_final_transform()
	var scale: float = minf(root.size.x / 1280.0, root.size.y / 720.0)
	var expected_origin: Vector2 = (Vector2(root.size) - Vector2(1280, 720) * scale) / 2.0
	_check(absf(transform.x.length() - scale) < 0.002, "canvas fills the available width or height")
	_check(absf(transform.y.length() - scale) < 0.002, "board and HUD keep uniform scale")
	_check(transform.origin.distance_to(expected_origin) < 1.5, "letterboxing stays centered")
	_check((_scene.board_view.get_global_transform_with_canvas().origin - Vector2(640, 360)).length() < 0.1, "board remains at the logical center")


func _fullscreen() -> bool:
	return root.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func _settle() -> void:
	for frame: int in range(12):
		await process_frame


func _key(code: Key, alt: bool = false, echo: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.alt_pressed = alt
		event.pressed = pressed
		event.echo = echo and pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _click(logical_position: Vector2) -> void:
	var position: Vector2 = root.get_final_transform() * logical_position
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://artifacts/display_%s.png" % label) == OK, "capture %s" % label)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % description)
