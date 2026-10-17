class_name BoardView
extends Node2D

@export var rules: GameRules = preload("res://game/rules/default_rules.tres")

var model: BoardModel
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


func _process(delta: float) -> void:
	if not frozen:
		pulse += delta
		for cell: Vector2i in stack_offsets.keys():
			var collapse_speed: float = rules.block_thickness * rules.max_blocks_per_side / rules.clear_animation_duration
			stack_offsets[cell] = move_toward(float(stack_offsets[cell]), 0.0, delta * collapse_speed)
			if float(stack_offsets[cell]) <= 0.0:
				stack_offsets.erase(cell)
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
	particles.clear()
	bursts.clear()
	board_angle = 0.0
	danger_direction = -1
	pulse = 0.0


func emit_clear(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		var color: Color = rules.block_colors[model.stacks[cell.x][cell.y]]
		var points: PackedVector2Array = cell_polygon(cell.x, cell.y)
		for index: int in range(points.size()):
			points[index] = points[index].rotated(board_angle)
		bursts.append({"points": points, "color": color, "life": 0.3})
		var center: Vector2 = side_normal(cell.x).rotated(board_angle) * (
			rules.core_apothem + (cell.y + 0.5) * rules.block_thickness
		)
		for index: int in range(8):
			var angle: float = _effect_random.randf_range(0.0, TAU)
			particles.append({
				"position": center,
				"velocity": Vector2.from_angle(angle) * _effect_random.randf_range(35.0, 150.0),
				"color": color,
				"life": _effect_random.randf_range(0.3, 0.65),
			})


func _draw() -> void:
	if model == null:
		return
	draw_circle(Vector2.ZERO, 271.0, Color(0.04, 0.085, 0.12, 0.6))
	draw_arc(Vector2.ZERO, 269.0, 0.0, TAU, 128, Color(0.2, 0.45, 0.49, 0.2), 1.0, true)
	var limit: float = rules.core_apothem + rules.max_blocks_per_side * rules.block_thickness
	for side: int in range(GameRules.SIDE_COUNT):
		var normal: Vector2 = side_normal(side)
		var warning: bool = model.stacks[model.local_side(side)].size() >= rules.max_blocks_per_side - 2
		var guide_color := Color(0.3, 0.53, 0.58, 0.3)
		if warning:
			guide_color = Color(1.0, 0.4, 0.35, 0.55 + 0.2 * sin(pulse * 6.0))
		draw_dashed_line(normal * (limit + 12.0), normal * (rules.spawn_distance - 2.0), guide_color, 1.0, 4.0)
		var label_position: Vector2 = normal * (rules.spawn_distance + 18.0) + Vector2(-8.0, 5.0)
		label_position.y = clampf(label_position.y, -264.0, 252.0)
		draw_string(_font, label_position, "%02d" % (side + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, guide_color.lightened(0.15))
		if side == danger_direction:
			draw_circle(normal * (limit + 20.0), 7.0, Color("ef7772"))
	draw_set_transform(Vector2.ZERO, board_angle)
	for side: int in range(GameRules.SIDE_COUNT):
		for depth: int in range(rules.max_blocks_per_side):
			var grid: PackedVector2Array = cell_polygon(side, depth)
			draw_colored_polygon(grid, Color(0.07, 0.13, 0.18, 0.5))
			_stroke(grid, Color(0.22, 0.38, 0.44, 0.23), 0.7)
		for depth: int in range(model.stacks[side].size()):
			var offset: float = float(stack_offsets.get(Vector2i(side, depth), 0.0))
			var points: PackedVector2Array = cell_polygon(side, depth, offset)
			var color: Color = rules.block_colors[model.stacks[side][depth]]
			draw_colored_polygon(points, color)
			_stroke(points, color.lightened(0.3), 0.9)
			var marker: Vector2 = side_normal(side) * (rules.core_apothem + (depth + 0.5) * rules.block_thickness + offset)
			var tangent: Vector2 = side_normal(side).orthogonal()
			draw_line(marker - tangent * 4.0, marker + tangent * 4.0, Color(1, 1, 1, 0.38), 1.4, true)
	var core: PackedVector2Array = hexagon(rules.core_apothem - 3.0)
	draw_colored_polygon(core, Color("13313e"))
	_stroke(core, Color("75dac5"), 1.8)
	_stroke(hexagon(rules.core_apothem - 11.0), Color(0.45, 0.85, 0.77, 0.15), 1.0)
	draw_line(Vector2(-12.0, -rules.core_apothem + 3.0), Vector2(12.0, -rules.core_apothem + 3.0), Color("f1c475"), 4.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_string(_font, Vector2(-25, -2), "HEX", HORIZONTAL_ALIGNMENT_CENTER, 50, 17, Color("c2efe5"))
	draw_string(_font, Vector2(-25, 15), "ELIM", HORIZONTAL_ALIGNMENT_CENTER, 50, 11, Color("719ca4"))
	for block: Dictionary in falling_blocks:
		var radius: float = float(block["distance"])
		var side: int = int(block["direction"])
		var points: PackedVector2Array = _band_points(radius - 7.5, radius + 7.5, side)
		var color: Color = rules.block_colors[int(block["color"])]
		draw_colored_polygon(points, color)
		_stroke(points, color.lightened(0.4), 1.2)
	for burst: Dictionary in bursts:
		var color: Color = Color(burst["color"]).lightened(0.5)
		color.a = clampf(float(burst["life"]) / 0.3, 0.0, 1.0)
		draw_colored_polygon(burst["points"], color)
	for particle: Dictionary in particles:
		var color: Color = particle["color"]
		color.a = minf(float(particle["life"]) * 2.0, 1.0)
		draw_circle(particle["position"], 2.1, color, true, -1.0, true)


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
