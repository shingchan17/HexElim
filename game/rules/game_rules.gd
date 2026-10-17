class_name GameRules
extends Resource
## Gameplay rules and tunable values for the first playable version.
## Score and combo state belong to ScoreManager, not to this resource.

const SIDE_COUNT: int = 6

enum BlockColor { RED, YELLOW, GREEN, BLUE }

@export_category("Board and matching")
@export_range(1, 20, 1) var max_blocks_per_side: int = 10
@export_range(3, 60, 1) var minimum_match_size: int = 3
@export var block_colors: Array[Color] = [
	Color("ef5350"),
	Color("ffd54f"),
	Color("66bb6a"),
	Color("42a5f5"),
]

@export_category("Scoring")
@export_range(1, 100, 1) var points_per_block: int = 6
@export_range(0.1, 30.0, 0.1) var score_buff_duration: float = 4.0

@export_category("Spawn interval")
@export_range(0.1, 30.0, 0.1) var initial_spawn_interval: float = 3.0
@export_range(0.1, 30.0, 0.1) var minimum_spawn_interval: float = 1.0
@export_range(1, 10000, 1) var score_per_difficulty_step: int = 1000
@export_range(0.01, 1.0, 0.01) var interval_decrease_per_step: float = 0.1

@export_category("Prototype movement")
@export var core_apothem: float = 48.0
@export var block_thickness: float = 17.0
@export var spawn_distance: float = 282.0
@export var base_fall_speed: float = 72.0
@export var fall_speed_per_step: float = 6.0
@export var maximum_fall_speed: float = 180.0
@export var fast_fall_multiplier: float = 4.0
@export var rotation_duration: float = 0.14
@export var clear_animation_duration: float = 0.22


func get_fall_speed(score: int) -> float:
	var steps: int = floori(float(maxi(score, 0)) / float(score_per_difficulty_step))
	return minf(maximum_fall_speed, base_fall_speed + steps * fall_speed_per_step)


func get_spawn_interval(score: int) -> float:
	var steps: int = floori(float(maxi(score, 0)) / float(score_per_difficulty_step))
	return maxf(
		minimum_spawn_interval,
		initial_spawn_interval - steps * interval_decrease_per_step
	)


func get_clear_score(cleared_block_count: int, consecutive_clear_count: int) -> int:
	# The opening clear counts as 1; each clear within the refreshed window adds 1.
	if cleared_block_count < minimum_match_size or consecutive_clear_count < 1:
		return 0
	return cleared_block_count * points_per_block * consecutive_clear_count
