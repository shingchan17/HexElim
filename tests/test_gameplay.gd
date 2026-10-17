extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _scene: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_board_rotation()
	_test_matching_and_compaction()
	_test_capacity()
	_test_wave_generation()
	_scene = load("res://game/main.tscn").instantiate()
	root.add_child(_scene)
	_scene.set_physics_process(false)
	_scene.audio.enabled = false
	_test_inputs_and_pause()
	_test_fall_and_speed()
	_test_landing_and_scoring()
	_test_chain_reaction()
	_test_overflow_and_restart()
	_test_long_run()
	_scene.free()
	if _failures == 0:
		print("PASS: playable game (%d checks)." % _checks)
	else:
		printerr("FAIL: %d of %d gameplay checks failed." % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _test_board_rotation() -> void:
	var board := BoardModel.new()
	_check(board.stacks.size() == 6, "six sides")
	board.rotate(1)
	_check(board.local_side(0) == 5, "D clockwise exposes local side five to the top")
	_check(board.place(0, 2), "placement after clockwise rotation")
	_check(board.stacks[5] == PackedInt32Array([2]), "piece attaches to rotated side")
	board.rotate(-1)
	_check(board.local_side(0) == 0, "A restores orientation")
	for index: int in range(6):
		board.rotate(1)
	_check(board.orientation_steps == 0, "six turns wrap orientation")
	_check(board.stacks[5][0] == 2, "rotation preserves settled blocks")
	_check(not board.place(0, -1), "invalid color is rejected")


func _test_matching_and_compaction() -> void:
	var board := BoardModel.new()
	board.place(0, 0)
	board.place(0, 0)
	_check(board.find_matches().is_empty(), "two matching blocks stay")
	board.place(0, 0)
	_check(board.find_matches().size() == 3, "vertical triple matches")
	board.reset()
	for side: int in [5, 0, 1]:
		board.place(side, 3)
	_check(board.find_matches().size() == 3, "equal-depth match crosses side five/zero boundary")
	board.reset()
	board.stacks[0] = PackedInt32Array([0, 1])
	board.stacks[1] = PackedInt32Array([2, 0])
	board.stacks[2] = PackedInt32Array([3, 2])
	_check(board.find_matches().is_empty(), "corner-only diagonal contacts do not match")
	board.reset()
	board.stacks[0] = PackedInt32Array([0, 0, 0])
	board.stacks[3] = PackedInt32Array([2, 2, 2])
	var matches: Array[Vector2i] = board.find_matches()
	_check(matches.size() == 6, "two groups are returned as one elimination batch")
	var unique: Dictionary = {}
	for cell: Vector2i in matches:
		unique[cell] = true
	_check(unique.size() == 6, "matched cells are never counted twice")
	board.reset()
	board.stacks[0] = PackedInt32Array([1, 0, 0, 0, 1])
	board.stacks[1] = PackedInt32Array([1])
	matches = board.find_matches()
	_check(matches.size() == 3, "only the initial triple matches before compaction")
	var offsets: Dictionary = board.remove_cells(matches)
	_check(board.stacks[0] == PackedInt32Array([1, 1]), "survivors compact in stable order")
	_check(is_equal_approx(float(offsets[Vector2i(0, 1)]), 51.0), "view receives collapse distance")
	_check(board.find_matches().size() == 3, "compaction creates a second match")
	board.remove_cells(board.find_matches())
	_check(board.block_count() == 0, "cascade clears the entire prepared board")


func _test_capacity() -> void:
	var board := BoardModel.new()
	for depth: int in range(10):
		_check(board.place(0, depth % 4), "slot %d accepts a piece" % depth)
	_check(not board.place(0, 2), "eleventh piece is rejected")
	_check(board.stacks[0].size() == 10, "overflow never writes outside capacity")
	board.reset()
	_check(board.block_count() == 0 and board.orientation_steps == 0, "reset clears board and orientation")


func _test_wave_generation() -> void:
	var generator := WaveGenerator.new()
	generator.random.seed = 1628
	var seen_sizes: Dictionary = {}
	var seen_colors: Dictionary = {}
	for iteration: int in range(120):
		var wave: Array[Vector2i] = generator.create_wave()
		_check(wave.size() >= 1 and wave.size() <= 6, "wave size stays in one to six")
		seen_sizes[wave.size()] = true
		var directions: Dictionary = {}
		for piece: Vector2i in wave:
			_check(piece.x >= 0 and piece.x < 6 and not directions.has(piece.x), "wave directions are valid and unique")
			_check(piece.y >= 0 and piece.y < 4, "wave color is valid")
			directions[piece.x] = true
			seen_colors[piece.y] = true
	_check(seen_sizes.size() == 6, "random wave count reaches every permitted size")
	_check(seen_colors.size() == 4, "all four colors can be generated")
	var replay := WaveGenerator.new()
	generator.random.seed = 33
	replay.random.seed = 33
	for iteration: int in range(10):
		_check(generator.create_wave() == replay.create_wave(), "seeded waves can be reproduced")


func _test_inputs_and_pause() -> void:
	_check(_scene.state == _scene.RunState.READY, "project starts at the start screen")
	_check(not _scene.scoring.is_processing(), "controller is the single scoring clock")
	_key(KEY_SPACE)
	_check(_scene.state == _scene.RunState.PLAYING, "space starts the game")
	_key(KEY_A)
	_check(_scene.board.orientation_steps == 5, "A rotates counterclockwise")
	_scene.step_game(0.15)
	_check(is_equal_approx(_scene.board_view.board_angle, -PI / 3.0), "A animation reaches sixty degrees counterclockwise")
	_key(KEY_D)
	_scene.step_game(0.15)
	_check(_scene.board.orientation_steps == 0, "D rotates clockwise")
	_scene.scoring.register_clear(3)
	var remaining: float = _scene.next_wave_time
	var buff: float = _scene.scoring.buff_time_left
	_key(KEY_P)
	_scene.step_game(2.0)
	_check(_scene.state == _scene.RunState.PAUSED, "P pauses")
	_check(is_equal_approx(_scene.next_wave_time, remaining), "pause freezes wave timer")
	_check(is_equal_approx(_scene.scoring.buff_time_left, buff), "pause freezes scoring window")
	_key(KEY_A)
	_check(_scene.board.orientation_steps == 0, "pause ignores rotation")
	_key(KEY_ESCAPE)
	_scene.step_game(0.25)
	_check(_scene.state == _scene.RunState.PLAYING, "escape resumes")
	_check(is_equal_approx(_scene.scoring.buff_time_left, buff - 0.25), "scoring resumes on game clock")


func _test_fall_and_speed() -> void:
	_scene.start_game()
	_add_piece(0, 0, 250.0)
	_scene.step_game(0.1)
	var normal_travel: float = 250.0 - float(_scene.falling_blocks[0]["distance"])
	var normal_spawn_time: float = _scene.next_wave_time
	_scene.start_game()
	_add_piece(0, 0, 250.0)
	_scene.step_game(0.1, true)
	var fast_travel: float = 250.0 - float(_scene.falling_blocks[0]["distance"])
	_check(is_equal_approx(fast_travel, normal_travel * 4.0), "S accelerates movement fourfold")
	_check(is_equal_approx(_scene.next_wave_time, normal_spawn_time), "S does not accelerate wave clock")
	_scene.start_game()
	_scene.scoring.total_score = 1000
	_scene.next_wave_time = 0.01
	_scene.step_game(0.02)
	_check(is_equal_approx(_scene.current_wave_interval, 2.9), "next wave adopts the updated interval")
	_check(_scene.rules.get_fall_speed(1000) > _scene.rules.get_fall_speed(0), "score increases movement speed")
	_check(_scene.rules.get_fall_speed(1000000) <= 180.0, "movement speed has a configured cap")
	_check(not _scene.falling_blocks.is_empty(), "wave clock produces actual falling pieces")


func _test_landing_and_scoring() -> void:
	_scene.start_game()
	_add_piece(0, 2, 55.0)
	_scene.rotate_board(1)
	_scene.step_game(0.05)
	_check(_scene.board.block_count() == 0, "arrival waits for the visual turn to finish")
	_scene.step_game(0.1)
	_check(_scene.board.stacks[5] == PackedInt32Array([2]), "waiting arrival uses the final rotated side")
	_scene.start_game()
	_scene.rotate_board(1)
	_scene.step_game(0.15)
	_add_piece(0, 2, 55.0)
	_scene.step_game(0.02)
	_check(_scene.board.stacks[5] == PackedInt32Array([2]), "world-fixed piece lands on rotated local side")
	_scene.start_game()
	_scene.board.stacks[0] = PackedInt32Array([0, 0])
	_add_piece(0, 0, 90.0)
	_scene.step_game(0.02)
	_check(_scene.scoring.total_score == 18, "landed third block awards first clear points")
	_check(_scene.board.block_count() == 0, "matched blocks leave the board")
	_check(_scene.cleared_blocks == 3, "clear counter tracks removed pieces")
	_check(not _scene.board_view.bursts.is_empty(), "clearing emits visual feedback")
	_scene.step_game(0.23)
	_scene.board.stacks[1] = PackedInt32Array([1, 1])
	_add_piece(1, 1, 90.0)
	_scene.step_game(0.02)
	_check(_scene.scoring.total_score == 54, "second actual elimination earns 36")
	_check(_scene.scoring.consecutive_clear_count == 2, "actual clears advance combo")
	_scene.step_game(0.23)
	_scene.board.stacks[2] = PackedInt32Array([2, 2])
	_add_piece(2, 2, 90.0)
	_scene.step_game(0.02)
	_check(_scene.scoring.total_score == 108, "third actual elimination earns 54")
	_scene.start_game()
	_scene.board.stacks[0] = PackedInt32Array([0, 0])
	_scene.board.stacks[3] = PackedInt32Array([2, 2])
	_add_piece(0, 0, 90.0)
	_add_piece(3, 2, 90.0)
	_scene.step_game(0.02)
	_check(_scene.scoring.total_score == 36, "simultaneous separate groups share one scoring event")
	_check(_scene.scoring.consecutive_clear_count == 1, "simultaneous batch increments once")


func _test_chain_reaction() -> void:
	_scene.start_game()
	_scene.board.stacks[0] = PackedInt32Array([1, 0, 0, 0, 1])
	_scene.board.stacks[1] = PackedInt32Array([1])
	_scene._resolve_matches()
	_check(_scene.scoring.total_score == 18, "first cascade round scores eighteen")
	_scene.step_game(0.23)
	_check(_scene.scoring.total_score == 54, "second cascade round earns thirty-six")
	_check(_scene.board.block_count() == 0, "actual cascade resolves to an empty board")
	_check(_scene.scoring.consecutive_clear_count == 2, "cascade advances continuous clear count")


func _test_overflow_and_restart() -> void:
	_scene.start_game()
	_scene.board.stacks[0] = PackedInt32Array([0, 1, 0, 1, 0, 1, 0, 1, 1])
	_add_piece(0, 1, 210.0)
	_scene.step_game(0.02)
	_check(_scene.state == _scene.RunState.PLAYING, "tenth piece can clear and save its side")
	_check(_scene.board.stacks[0].size() == 7, "last three blocks are removed at capacity")
	_scene.start_game()
	_scene.board.stacks[0] = PackedInt32Array([0, 1, 2, 3, 0, 1, 2, 3, 0, 1])
	_check(_scene.state == _scene.RunState.PLAYING, "a full side can remain until another piece arrives")
	_add_piece(0, 2, 227.0)
	_scene.step_game(0.02)
	_check(_scene.state == _scene.RunState.GAME_OVER, "eleventh arriving piece ends the game")
	_check(_scene.board.stacks[0].size() == 10, "game-over board does not exceed ten")
	var remaining: float = _scene.next_wave_time
	_scene.step_game(1.0)
	_check(is_equal_approx(_scene.next_wave_time, remaining), "game over stops simulation")
	_key(KEY_R)
	_check(_scene.state == _scene.RunState.PLAYING, "R restarts after game over")
	_check(_scene.board.block_count() == 0, "restart empties board")
	_check(_scene.falling_blocks.is_empty(), "restart removes airborne pieces")
	_check(_scene.scoring.total_score == 0, "restart clears score")
	_check(_scene.scoring.consecutive_clear_count == 0, "restart clears combo")
	_check(is_equal_approx(_scene.next_wave_time, 3.0), "restart resets wave clock")
	_check(_scene.board_view.bursts.is_empty(), "restart clears old effects")


func _test_long_run() -> void:
	_scene.start_game()
	_scene.wave_generator.random.seed = 20261017
	for frame: int in range(36000):
		_scene.step_game(1.0 / 60.0)
		_scene.board_view._process(1.0 / 60.0)
		if _scene.state == _scene.RunState.GAME_OVER:
			break
	_check(_scene.state == _scene.RunState.GAME_OVER, "unattended game naturally reaches game over")
	for stack: PackedInt32Array in _scene.board.stacks:
		_check(stack.size() <= 10, "long run respects capacity")
	_check(_scene.elapsed_time >= 5.0, "long run advances the actual wave/fall loop")


func _add_piece(direction: int, color: int, distance: float) -> void:
	_scene.falling_blocks.append({"direction": direction, "color": color, "distance": distance})


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	_scene._unhandled_input(event)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
