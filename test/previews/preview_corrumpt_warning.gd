extends SceneTree
## 捕获真实Boss预警、冲撞和玩家轻/重受击画面，用于视觉核验。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	for index in 8:await process_frame
	var boss: Node = current_scene.boss
	var player: Node = current_scene.player
	var ui: Node = root.get_node("GameUI")
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.cam.set_physics_process(false)
	player.cam.position_smoothing_enabled = false
	player.position = Vector2(900,400)
	player.cam.global_position = Vector2(840,330)
	player.cam.force_update_scroll()
	boss.begin_phase_two()
	boss.position = Vector2(700,240)
	var motion: CorrumptPhaseTwo = boss.phase_two
	motion.entry_left = 0
	motion.mode = &"close"
	motion.skill = &"blade"
	motion.cycles_left = 1
	motion._set_stage(&"hover")
	motion.elapsed = 1.29
	var output := "res://work/corrumpt_refine/capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for index in 13:
		motion.tick(1.0/60)
		await _save(output+"/warning_%02d.png" % index)
		if index == 5:
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_warning_ingame.png"))
	ui.set_process(false)
	player._invuln = 0
	player.apply_hit(DamagePacket.new(4))
	await _save("res://docs/previews/player_light_hit.png")
	player._invuln = 0
	player.apply_hit(DamagePacket.new(5))
	await _save("res://docs/previews/player_heavy_hit.png")
	print("WARNING PREVIEW: 13 rendered frames; light/heavy damage captures")
	quit()

func _save(path: String) -> void:
	for index in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
