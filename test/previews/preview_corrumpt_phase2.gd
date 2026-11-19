extends SceneTree
## 实际Godot二阶段演练捕获，先闲置，再完整展示三次旋刃冲撞。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	for frame in 8:await process_frame
	var boss: Node = current_scene.boss
	var player: Node = current_scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.position = Vector2(840,400)
	player.cam.set_physics_process(false)
	player.cam.position_smoothing_enabled = false
	player.cam.global_position = Vector2(840,330)
	boss.begin_phase_two()
	boss.position = Vector2(600,220)
	var motion: CorrumptPhaseTwo = boss.phase_two
	motion.entry_left = 0
	var output := "res://work/corrumpt_phase2/capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var index := 0
	for frame in 4:
		boss.visual.flower_pose(&"phase_2_idle",float(frame)/4)
		await _save(output,index)
		index += 1
	motion.start_skill(&"blade")
	motion.cycles_left = 3
	var sim := 0.0
	for step in 900:
		motion.tick(1.0/60)
		sim += 1.0/60
		if step%12 == 0 or motion.skill == &"":
			if boss.visual.animation == &"phase_2_spin":
				boss.visual.pause()
				boss.visual.frame = int(sim*float(boss.profile.art.phase2.spin_fps))%8
			await _save(output,index)
			if motion.stage == &"dash":
				get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_phase2_dash.png"))
			index += 1
		if motion.skill == &"":break
	print("PHASE2 PREVIEW: %d actual Godot frames / three blade charges" % index)
	quit()

func _save(output: String, index: int) -> void:
	for frame in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output+"/%03d.png" % index))
