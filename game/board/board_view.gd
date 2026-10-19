class_name BoardView
extends Node2D

const MAX_PARTICLES: int = 96
const PARTICLES_PER_CELL: int = 4
const CLEAR_FLASH_DURATION: float = 0.14
const BUFF_RING_WIDTH: float = 4.0
const BUFF_RING_SEGMENTS: int = 180
const Backdrop = preload("res://game/board/board_backdrop.gd")

@export var rules: GameRules = preload("res://game/rules/default_rules.tres")

var model: BoardModel
var scoring: ScoreManager
var last_clear_color_index: int = -1
var falling_blocks: Array[Dictionary] = []
var board_angle: float = 0.0
var stack_offsets: Dictionary = {}
var frozen: bool = false
var danger_direction: int = -1
var particles: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var pulse: float = 0.0
var _effect_random := RandomNumberGenerator.new()
var _font: Font = ThemeDB.fallback_font
var _compaction_origins: Dictionary = {}
var _compaction_elapsed: float = 0.0
var _backdrop: Backdrop
var _grid_geometry := Vector3.ZERO
var _center_score: Label
var _displayed_score: int = -1


func _ready() -> void:
	_backdrop = Backdrop.new()
	_backdrop.name = "GridBackdrop"
	_backdrop.show_behind_parent = true
	add_child(_backdrop)
	_update_grid_geometry()
	_center_score = Label.new()
	_center_score.name = "CenterScore"
	_center_score.position = Vector2(-34, -20)
	_center_score.size = Vector2(68, 40)
	_center_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_score.clip_text = true
	_center_score.add_theme_font_override("font", _font)
	_center_score.add_theme_color_override("font_color", Color("e3eeef"))
	add_child(_center_score)
	_update_center_score()


func _update_grid_geometry() -> void:
	var geometry := Vector3(rules.core_apothem, rules.block_thickness, rules.max_blocks_per_side)
	if geometry == _grid_geometry:
		return
	_grid_geometry = geometry
	var polygons: Array[PackedVector2Array] = []
	for side: int in range(GameRules.SIDE_COUNT):
		for depth: int in range(rules.max_blocks_per_side):
			polygons.append(cell_polygon(side, depth))
	_backdrop.configure(polygons, get_buff_ring_radius())


func _process(delta: float) -> void:
	_update_grid_geometry()
	_backdrop.rotation = board_angle
	_update_center_score()
	if not frozen:
		pulse += delta
		for index: int in range(particles.size() - 1, -1, -1):
			particles[index]["life"] -= delta
			particles[index]["position"] += particles[index]["velocity"] * delta
			particles[index]["velocity"] *= exp(-delta * 3.0)
			if float(particles[index]["life"]) <= 0.0:
				particles.remove_at(index)
		for index: int in range(bursts.size() - 1, -1, -1):
			bursts[index]["life"] -= delta
			if float(bursts[index]["life"]) <= 0.0:
				bursts.remove_at(index)
	queue_redraw()


func reset_effects() -> void:
	stack_offsets.clear()
	_compaction_origins.clear()
	_compaction_elapsed = 0.0
	particles.clear()
	bursts.clear()
	board_angle = 0.0
	danger_direction = -1
	pulse = 0.0
	last_clear_color_index = -1
	_update_center_score()


func _update_center_score() -> void:
	var score: int = scoring.total_score if scoring != null else 0
	if score == _displayed_score:
		return
	_displayed_score = score
	var text: String = str(score)
	var font_size: int = 26
	while font_size > 8 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 64.0:
		font_size -= 1
	_center_score.text = text
	_center_score.add_theme_font_size_override("font_size", font_size)


func get_buff_ring_radius() -> float:
	var outer_apothem: float = rules.core_apothem + rules.max_blocks_per_side * rules.block_thickness
	return outer_apothem / cos(PI / 6.0)


func get_buff_fraction() -> float:
	if scoring == null:
		return 0.0
	return clampf(scoring.buff_time_left / maxf(rules.score_buff_duration, 0.001), 0.0, 1.0)


func begin_compaction(offsets: Dictionary) -> void:
	_compaction_origins = offsets
	stack_offsets = offsets.duplicate()
	_compaction_elapsed = 0.0


func advance_compaction(delta: float) -> void:
	if _compaction_origins.is_empty():
		return
	_compaction_elapsed += delta
	var progress: float = minf(_compaction_elapsed / maxf(rules.clear_animation_duration, 0.001), 1.0)
	if progress >= 1.0:
		stack_offsets.clear()
		_compaction_origins.clear()
		return
	var remaining: float = pow(1.0 - progress, 3.0)
	for cell: Vector2i in _compaction_origins:
		stack_offsets[cell] = float(_compaction_origins[cell]) * remaining


func emit_clear(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	# find_matches appends each connected group in order; the final group wins.
	var last_cell: Vector2i = cells[cells.size() - 1]
	last_clear_color_index = model.stacks[last_cell.x][last_cell.y]
	var budget: int = mini(maxi(0, MAX_PARTICLES - particles.size()), cells.size() * PARTICLES_PER_CELL)
	var per_cell: int = floori(float(budget) / cells.size())
	var extra: int = budget % cells.size()
	for cell_index: int in range(cells.size()):
		var cell: Vector2i = cells[cell_index]
		var color: Color = rules.block_colors[model.stacks[cell.x][cell.y]]
		var points: PackedVector2Array = cell_polygon(cell.x, cell.y)
		for index: int in range(points.size()):
			points[index] = points[index].rotated(board_angle)
		bursts.append({"points": points, "color": color, "life": CLEAR_FLASH_DURATION})
		var center: Vector2 = side_normal(cell.x).rotated(board_angle) * (
			rules.core_apothem + (cell.y + 0.5) * rules.block_thickness
		)
		for index: int in range(per_cell + (1 if cell_index < extra else 0)):
			var angle: float = _effect_random.randf_range(0.0, TAU)
			particles.append({
				"position": center,
				"velocity": Vector2.from_angle(angle) * _effect_random.randf_range(35.0, 150.0),
				"color": color,
				"life": _effect_random.randf_range(0.2, 0.4),
			})


func _draw() -> void:
	if model == null:
		return
	var limit: float = rules.core_apothem + rules.max_blocks_per_side * rules.block_thickness
	for side: int in range(GameRules.SIDE_COUNT):
		var normal: Vector2 = side_normal(side)
		var warning: bool = model.stacks[model.local_side(side)].size() >= rules.max_blocks_per_side - 2
		var guide_color := Color(0.3, 0.53, 0.58, 0.3)
		if warning:
			guide_color = Color(1.0, 0.4, 0.35, 0.55 + 0.2 * sin(pulse * 6.0))
		draw_dashed_line(normal * (limit + 12.0), normal * (rules.spawn_distance - 2.0), guide_color, 1.0, 4.0)
		var label_position: Vector2 = normal * (rules.spawn_distance + 18.0) + Vector2(-8.0, 5.0)
		label_position.y = clampf(label_position.y, -264.0, 266.0)
		draw_string(_font, label_position, "%02d" % (side + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, guide_color.lightened(0.15))
		if side == danger_direction:
			draw_circle(normal * (limit + 20.0), 7.0, Color("ef7772"))
	draw_set_transform(Vector2.ZERO, board_angle)
	for side: int in range(GameRules.SIDE_COUNT):
		for depth: int in range(model.stacks[side].size()):
			var offset: float = float(stack_offsets.get(Vector2i(side, depth), 0.0))
			var points: PackedVector2Array = cell_polygon(side, depth, offset)
			var color: Color = rules.block_colors[model.stacks[side][depth]]
			draw_colored_polygon(points, color)
	var core: PackedVector2Array = hexagon(rules.core_apothem - 3.0)
	draw_colored_polygon(core, Color("13313e"))
	_stroke(core, Color("75dac5"), 1.8)
	_stroke(hexagon(rules.core_apothem - 11.0), Color(0.45, 0.85, 0.77, 0.15), 1.0)
	draw_line(Vector2(-12.0, -rules.core_apothem + 3.0), Vector2(12.0, -rules.core_apothem + 3.0), Color("f1c475"), 4.0, true)
	draw_set_transform(Vector2.ZERO)
	for block: Dictionary in falling_blocks:
		var radius: float = float(block["distance"])
		var side: int = int(block["direction"])
		var points: PackedVector2Array = _band_points(radius - 7.5, radius + 7.5, side)
		var color: Color = rules.block_colors[int(block["color"])]
		draw_colored_polygon(points, color)
	for burst: Dictionary in bursts:
		var color: Color = Color(burst["color"]).lightened(0.5)
		color.a = clampf(float(burst["life"]) / CLEAR_FLASH_DURATION, 0.0, 1.0)
		draw_colored_polygon(burst["points"], color)
	for particle: Dictionary in particles:
		var color: Color = particle["color"]
		color.a = minf(float(particle["life"]) * 2.0, 1.0)
		draw_circle(particle["position"], 2.1, color, true, -1.0, true)
	_draw_buff_ring()


func _draw_buff_ring() -> void:
	var fraction: float = get_buff_fraction()
	if fraction <= 0.0 or last_clear_color_index < 0 or last_clear_color_index >= rules.block_colors.size():
		return
	var radius: float = get_buff_ring_radius()
	var color: Color = rules.block_colors[last_clear_color_index]
	# The empty portion travels clockwise from 12 o'clock. The remaining arc
	# starts at that moving boundary and ends back at the top of the circle.
	var start: float = -PI * 0.5 + TAU * (1.0 - fraction)
	var end: float = PI * 1.5
	var segments: int = maxi(2, ceili(BUFF_RING_SEGMENTS * fraction) + 1)
	draw_arc(Vector2.ZERO, radius, start, end, segments, color, BUFF_RING_WIDTH, true)
	draw_circle(Vector2.from_angle(start) * radius, BUFF_RING_WIDTH * 0.5, color, true, -1.0, true)
	draw_circle(Vector2.from_angle(end) * radius, BUFF_RING_WIDTH * 0.5, color, true, -1.0, true)


func cell_polygon(side: int, depth: int, offset: float = 0.0) -> PackedVector2Array:
	var inner: float = rules.core_apothem + depth * rules.block_thickness + offset
	return _band_points(inner + 1.1, inner + rules.block_thickness - 1.1, side)


static func side_normal(side: int) -> Vector2:
	return Vector2.UP.rotated(side * TAU / GameRules.SIDE_COUNT)


static func hexagon(apothem: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius: float = apothem / cos(PI / 6.0)
	for vertex: int in range(6):
		points.append(Vector2.from_angle(vertex * TAU / 6.0) * radius)
	return points


func _band_points(inner: float, outer: float, side: int) -> PackedVector2Array:
	var points := PackedVector2Array([
		Vector2(-inner / sqrt(3.0) + 1.0, -inner),
		Vector2(inner / sqrt(3.0) - 1.0, -inner),
		Vector2(outer / sqrt(3.0) - 1.0, -outer),
		Vector2(-outer / sqrt(3.0) + 1.0, -outer),
	])
	for index: int in range(points.size()):
		points[index] = points[index].rotated(side * TAU / 6.0)
	return points


func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, width, true)
