class_name ScoreManager
extends Node
## Call register_clear once per resolved elimination, not once per removed block.
## The first clear starts a combo; every valid follow-up refreshes its window.

@export var rules: GameRules = preload("res://game/rules/default_rules.tres")

var total_score: int = 0
var consecutive_clear_count: int = 0
var buff_time_left: float = 0.0


func _process(delta: float) -> void:
	advance_time(delta)


func register_clear(cleared_block_count: int) -> int:
	if cleared_block_count < rules.minimum_match_size:
		return 0

	if buff_time_left > 0.0:
		consecutive_clear_count += 1
	else:
		consecutive_clear_count = 1

	var earned_score: int = rules.get_clear_score(
		cleared_block_count, consecutive_clear_count
	)
	total_score += earned_score
	buff_time_left = rules.score_buff_duration
	return earned_score


func advance_time(delta: float) -> void:
	# SceneTree advances this automatically; tests can advance game time explicitly.
	buff_time_left = maxf(0.0, buff_time_left - maxf(delta, 0.0))
	if buff_time_left <= 0.0:
		consecutive_clear_count = 0


func reset() -> void:
	total_score = 0
	consecutive_clear_count = 0
	buff_time_left = 0.0
