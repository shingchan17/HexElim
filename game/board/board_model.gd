class_name BoardModel
extends RefCounted
## Six radial stacks. A cell touches radial neighbors and equal-depth cells
## on the two adjacent sides, including the wrap between sides 5 and 0.

var rules: GameRules
var stacks: Array[PackedInt32Array] = []
var orientation_steps: int = 0


func _init(game_rules: GameRules = null) -> void:
	rules = game_rules if game_rules != null else GameRules.new()
	reset()


func reset() -> void:
	stacks.clear()
	for side: int in range(GameRules.SIDE_COUNT):
		stacks.append(PackedInt32Array())
	orientation_steps = 0


func rotate(step: int) -> void:
	orientation_steps = posmod(orientation_steps + step, GameRules.SIDE_COUNT)


func local_side(world_direction: int) -> int:
	return posmod(world_direction - orientation_steps, GameRules.SIDE_COUNT)


func place(world_direction: int, color: int) -> bool:
	var side: int = local_side(world_direction)
	if color < 0 or color >= rules.block_colors.size():
		return false
	if stacks[side].size() >= rules.max_blocks_per_side:
		return false
	var stack: PackedInt32Array = stacks[side]
	stack.append(color)
	stacks[side] = stack
	return true


func find_matches() -> Array[Vector2i]:
	var matched: Array[Vector2i] = []
	var visited: Dictionary = {}
	for side: int in range(GameRules.SIDE_COUNT):
		for depth: int in range(stacks[side].size()):
			var origin := Vector2i(side, depth)
			if visited.has(origin):
				continue
			var color: int = stacks[side][depth]
			var group: Array[Vector2i] = [origin]
			visited[origin] = true
			var cursor: int = 0
			while cursor < group.size():
				var cell: Vector2i = group[cursor]
				cursor += 1
				for neighbor: Vector2i in _neighbors(cell):
					if not visited.has(neighbor) and stacks[neighbor.x][neighbor.y] == color:
						visited[neighbor] = true
						group.append(neighbor)
			if group.size() >= rules.minimum_match_size:
				matched.append_array(group)
	return matched


func remove_cells(cells: Array[Vector2i]) -> Dictionary:
	# Return how far each survivor moved so the view can animate compaction.
	var removed: Dictionary = {}
	for cell: Vector2i in cells:
		removed[cell] = true
	var offsets: Dictionary = {}
	for side: int in range(GameRules.SIDE_COUNT):
		var compacted := PackedInt32Array()
		for depth: int in range(stacks[side].size()):
			if removed.has(Vector2i(side, depth)):
				continue
			var new_depth: int = compacted.size()
			if depth != new_depth:
				offsets[Vector2i(side, new_depth)] = float(depth - new_depth) * rules.block_thickness
			compacted.append(stacks[side][depth])
		stacks[side] = compacted
	return offsets


func block_count() -> int:
	var count: int = 0
	for stack: PackedInt32Array in stacks:
		count += stack.size()
	return count


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [
		Vector2i(cell.x, cell.y - 1), Vector2i(cell.x, cell.y + 1),
		Vector2i(posmod(cell.x - 1, GameRules.SIDE_COUNT), cell.y),
		Vector2i(posmod(cell.x + 1, GameRules.SIDE_COUNT), cell.y),
	]
	for neighbor: Vector2i in candidates:
		if neighbor.y >= 0 and neighbor.y < stacks[neighbor.x].size():
			result.append(neighbor)
	return result
