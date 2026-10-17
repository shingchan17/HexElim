class_name WaveGenerator
extends RefCounted

var random := RandomNumberGenerator.new()


func _init() -> void:
	random.randomize()


func create_wave(color_count: int = 4) -> Array[Vector2i]:
	var directions := PackedInt32Array([0, 1, 2, 3, 4, 5])
	for index: int in range(directions.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var previous: int = directions[index]
		directions[index] = directions[other]
		directions[other] = previous
	var wave: Array[Vector2i] = []
	for index: int in range(random.randi_range(1, GameRules.SIDE_COUNT)):
		wave.append(Vector2i(directions[index], random.randi_range(0, color_count - 1)))
	return wave
