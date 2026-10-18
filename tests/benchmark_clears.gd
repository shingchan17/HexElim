extends SceneTree
## Real-window stress benchmark; timings are reported, not asserted across hardware.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The clear benchmark requires a real renderer; omit --headless.")
		quit(2)
		return
	var scene: Node = load("res://game/main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.audio.enabled = false
	scene.start_game()
	scene.next_wave_time = 1000.0
	scene.board.stacks[0] = PackedInt32Array([0, 0, 0, 1])
	scene.falling_blocks.append({"direction": 3, "color": 2, "distance": 250.0})
	scene._resolve_matches()
	var stalled_ticks: int = 0
	var previous_distance: float = 250.0
	for frame: int in range(16):
		scene.step_game(1.0 / 60.0)
		scene.board_view._process(1.0 / 60.0)
		var distance: float = scene.falling_blocks[0]["distance"]
		if is_equal_approx(distance, previous_distance):
			stalled_ticks += 1
		previous_distance = distance
	scene.start_game()
	scene.next_wave_time = 1000.0
	var process_ms: Array[float] = []
	var clear_ms: Array[float] = []
	var maximum_particles: int = 0
	for frame: int in range(420):
		await process_frame
		if frame >= 60:
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			if frame % 30 == 0:
				for side: int in range(6):
					scene.board.stacks[side] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
				var begin: int = Time.get_ticks_usec()
				scene._resolve_matches()
				clear_ms.append((Time.get_ticks_usec() - begin) / 1000.0)
			maximum_particles = maxi(maximum_particles, scene.board_view.particles.size())
			scene._update_hud()
	process_ms.sort()
	clear_ms.sort()
	var report := {
		"stalled_fall_ticks_after_clear": stalled_ticks,
		"fall_distance_after_16_ticks": 250.0 - previous_distance,
		"clear_60_blocks_ms_p95": clear_ms[int((clear_ms.size() - 1) * 0.95)],
		"engine_process_ms_p95": process_ms[int((process_ms.size() - 1) * 0.95)],
		"peak_particles": maximum_particles,
		"rendered_stress_frames": process_ms.size(),
	}
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = arguments[0].validate_filename() if not arguments.is_empty() else "current"
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output: FileAccess = FileAccess.open("res://artifacts/clear_profile_%s.json" % label, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("PROFILE %s: %s" % [label, JSON.stringify(report)])
	quit()
