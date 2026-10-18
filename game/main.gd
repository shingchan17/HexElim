extends Node2D

enum RunState { READY, PLAYING, PAUSED, GAME_OVER }

@export var rules: GameRules

@onready var scoring: ScoreManager = $ScoreManager
@onready var board_view: BoardView = $BoardView
@onready var hud: GameHUD = $HUD
@onready var audio: GameAudio = $GameAudio

var board: BoardModel
var wave_generator := WaveGenerator.new()
var state: RunState = RunState.READY
var falling_blocks: Array[Dictionary] = []
var next_wave_time: float = 0.0
var current_wave_interval: float = 0.0
var cleared_blocks: int = 0
var best_score: int = 0
var elapsed_time: float = 0.0
var _resolution_time: float = 0.0
var _rotation_time: float = 0.0
var _rotation_from: float = 0.0
var _rotation_target: float = 0.0
var _windowed_size := Vector2i(1600, 900)
var _windowed_position := Vector2i.ZERO
var _windowed_mode: Window.Mode = Window.MODE_WINDOWED


func _ready() -> void:
	assert(rules != null)
	current_wave_interval = rules.get_spawn_interval(0)
	next_wave_time = current_wave_interval
	board = BoardModel.new(rules)
	scoring.rules = rules
	# One simulation clock advances movement and scoring; pause freezes both.
	scoring.set_process(false)
	board_view.model = board
	board_view.rules = rules
	board_view.falling_blocks = falling_blocks
	hud.start_requested.connect(start_game)
	hud.restart_requested.connect(start_game)
	hud.pause_requested.connect(toggle_pause)
	hud.sound_requested.connect(toggle_sound)
	hud.fullscreen_requested.connect(toggle_fullscreen)
	get_window().size_changed.connect(_update_fullscreen_button)
	_remember_window()
	_update_fullscreen_button()
	hud.show_overlay("ready")
	_update_hud()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("0a1420"))
	for x: int in range(16, 1280, 32):
		for y: int in range(100, 640, 32):
			draw_circle(Vector2(x, y), 0.6, Color(0.4, 0.62, 0.7, 0.055))
	draw_line(Vector2(40, 84), Vector2(1240, 84), Color("1d3443"), 1.0, true)
	draw_line(Vector2(40, 637), Vector2(1240, 637), Color("1d3443"), 1.0, true)


func _input(event: InputEvent) -> void:
	# Handle Alt+Enter before the Enter shortcut can start or resume a game.
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("restart_game"):
		start_game()
	elif event.is_action_pressed("pause_game"):
		toggle_pause()
	elif event.is_action_pressed("start_game"):
		if state == RunState.READY or state == RunState.GAME_OVER:
			start_game()
		elif state == RunState.PAUSED:
			toggle_pause()
	elif event.is_action_pressed("rotate_clockwise"):
		rotate_board(1)
	elif event.is_action_pressed("rotate_counterclockwise"):
		rotate_board(-1)
	elif event.is_action_pressed("toggle_sound"):
		toggle_sound()


func _physics_process(delta: float) -> void:
	if state == RunState.PLAYING:
		step_game(delta, Input.is_action_pressed("accelerate_fall"))
	_update_hud()


func start_game() -> void:
	best_score = maxi(best_score, scoring.total_score)
	board.reset()
	scoring.reset()
	falling_blocks.clear()
	board_view.reset_effects()
	board_view.frozen = false
	cleared_blocks = 0
	elapsed_time = 0.0
	_resolution_time = 0.0
	_rotation_time = 0.0
	_rotation_from = 0.0
	_rotation_target = 0.0
	current_wave_interval = rules.get_spawn_interval(0)
	next_wave_time = current_wave_interval
	state = RunState.PLAYING
	hud.hide_overlay()
	_update_hud()


func toggle_pause() -> void:
	if state == RunState.PLAYING:
		state = RunState.PAUSED
		board_view.frozen = true
		hud.show_overlay("paused")
	elif state == RunState.PAUSED:
		state = RunState.PLAYING
		board_view.frozen = false
		hud.hide_overlay()


func toggle_sound() -> void:
	audio.enabled = not audio.enabled
	hud.set_sound(audio.enabled)


func toggle_fullscreen() -> void:
	var window: Window = get_window()
	if _is_fullscreen():
		window.mode = Window.MODE_WINDOWED
		window.size = _windowed_size
		window.position = _windowed_position
		window.mode = _windowed_mode
	else:
		_remember_window()
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	_update_fullscreen_button()


func _is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func _remember_window() -> void:
	if _is_fullscreen():
		return
	var window: Window = get_window()
	_windowed_size = window.size
	_windowed_position = window.position
	_windowed_mode = Window.MODE_MAXIMIZED if window.mode == Window.MODE_MAXIMIZED else Window.MODE_WINDOWED


func _update_fullscreen_button() -> void:
	hud.set_fullscreen(_is_fullscreen())


func rotate_board(step: int) -> void:
	if state != RunState.PLAYING or _rotation_time > 0.0:
		return
	board.rotate(step)
	_rotation_from = board_view.board_angle
	_rotation_target += step * TAU / GameRules.SIDE_COUNT
	_rotation_time = rules.rotation_duration
	audio.play_cue("turn", 1.1 if step > 0 else 0.9)


func step_game(delta: float, accelerated: bool = false) -> void:
	# Also used by deterministic integration tests; never advances while paused.
	if state != RunState.PLAYING:
		return
	elapsed_time += delta
	scoring.advance_time(delta)
	_update_rotation(delta)
	next_wave_time -= delta
	if next_wave_time <= 0.0:
		_spawn_wave()
		current_wave_interval = rules.get_spawn_interval(scoring.total_score)
		next_wave_time += current_wave_interval
	if _resolution_time > 0.0:
		_resolution_time = maxf(0.0, _resolution_time - delta)
		if _resolution_time <= 0.0:
			_resolve_matches()
		return
	_move_falling_blocks(delta, accelerated)


func _update_rotation(delta: float) -> void:
	if _rotation_time <= 0.0:
		return
	_rotation_time = maxf(0.0, _rotation_time - delta)
	var progress: float = 1.0 - _rotation_time / rules.rotation_duration
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	board_view.board_angle = lerpf(_rotation_from, _rotation_target, eased)


func _spawn_wave() -> void:
	for piece: Vector2i in wave_generator.create_wave(rules.block_colors.size()):
		falling_blocks.append({
			"direction": piece.x,
			"color": piece.y,
			"distance": rules.spawn_distance,
		})


func _move_falling_blocks(delta: float, accelerated: bool) -> void:
	var speed: float = rules.get_fall_speed(scoring.total_score)
	if accelerated:
		speed *= rules.fast_fall_multiplier
	var landed: bool = false
	var index: int = 0
	while index < falling_blocks.size():
		var block: Dictionary = falling_blocks[index]
		var side: int = board.local_side(int(block["direction"]))
		var target: float = rules.core_apothem + (board.stacks[side].size() + 0.5) * rules.block_thickness
		block["distance"] = maxf(target, float(block["distance"]) - speed * delta)
		if float(block["distance"]) <= target and _rotation_time <= 0.0:
			if not board.place(int(block["direction"]), int(block["color"])):
				_end_game(int(block["direction"]))
				return
			falling_blocks.remove_at(index)
			landed = true
		else:
			index += 1
	if landed:
		audio.play_cue("land")
		_resolve_matches()


func _resolve_matches() -> void:
	var matches: Array[Vector2i] = board.find_matches()
	if matches.is_empty():
		return
	board_view.emit_clear(matches)
	board_view.stack_offsets = board.remove_cells(matches)
	var points: int = scoring.register_clear(matches.size())
	cleared_blocks += matches.size()
	best_score = maxi(best_score, scoring.total_score)
	_resolution_time = rules.clear_animation_duration
	hud.show_gain(points, scoring.consecutive_clear_count)
	audio.play_cue("clear", minf(1.0 + (scoring.consecutive_clear_count - 1) * 0.08, 1.8))


func _end_game(direction: int) -> void:
	state = RunState.GAME_OVER
	best_score = maxi(best_score, scoring.total_score)
	board_view.danger_direction = direction
	audio.play_cue("end")
	hud.show_overlay("game_over", scoring.total_score, "第 %02d 边已满，无法接住下一块。" % (direction + 1))


func _update_hud() -> void:
	var loads := PackedInt32Array()
	for direction: int in range(GameRules.SIDE_COUNT):
		loads.append(board.stacks[board.local_side(direction)].size())
	var accelerated: bool = state == RunState.PLAYING and Input.is_action_pressed("accelerate_fall")
	var speed_scale: float = rules.get_fall_speed(scoring.total_score) / rules.base_fall_speed
	if accelerated:
		speed_scale *= rules.fast_fall_multiplier
	hud.update_display({
		"score": scoring.total_score,
		"best": maxi(best_score, scoring.total_score),
		"combo": scoring.consecutive_clear_count,
		"buff": scoring.buff_time_left,
		"buff_duration": rules.score_buff_duration,
		"points_per_block": rules.points_per_block,
		"wave_time": next_wave_time,
		"wave_interval": current_wave_interval,
		"cleared": cleared_blocks,
		"speed_scale": speed_scale,
		"loads": loads,
		"can_pause": state == RunState.PLAYING or state == RunState.PAUSED,
		"fast": accelerated,
	})
