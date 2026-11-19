extends SceneTree
## 捕获真实转阶段与虚空湮灭演出，固定60Hz推进、10fps保存，摄像机仍运行正式跟随逻辑。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	for index in 8:await process_frame
	var boss: Node = current_scene.boss
	var player: Node = current_scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.cam.set_physics_process(false)
	player.cam.position_smoothing_enabled = false
	var output := "res://work/corrumpt_sequences/capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var index := 0
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	for step in 500:
		player._physics_process(1.0/60)
		boss.sequence.tick(1.0/60)
		player.cam._physics_process(1.0/60)
		player.cam.force_update_scroll()
		if step%6 == 0:
			await _save(output,index)
			index += 1
			if boss.sequence.stage == &"hover":
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_transition.png"))
		if not boss.sequence.active:break
	player.position = Vector2(400,543)
	boss.hp = 1
	boss.receive_hit(DamagePacket.new(10))
	for step in 650:
		player._physics_process(1.0/60)
		boss.sequence.tick(1.0/60)
		player.cam._physics_process(1.0/60)
		player.cam.force_update_scroll()
		if step%6 == 0:
			await _save(output,index)
			index += 1
			if boss.sequence.stage == &"grow" and boss.sequence.elapsed > 4.0:
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_void_annihilation.png"))
		if not boss.sequence.active:break
	print("SEQUENCE PREVIEW: %d rendered gameplay frames" % index)
	quit()

func _save(folder: String, index: int) -> void:
	for frame in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+"/%03d.png" % index))
