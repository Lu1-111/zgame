extends SceneTree
## 捕获正常/破韧/恢复血条，使用真实运行控件和实际削韧入口。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_file("res://test/scenes/previews/corrumpt_arena.tscn")
	for index in 8:await process_frame
	var boss: Node = current_scene.boss
	var player: Node = current_scene.player
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.position = Vector2(900,400)
	player.cam.set_physics_process(false)
	player.cam.position_smoothing_enabled = false
	player.cam.global_position = Vector2(840,330)
	player.cam.force_update_scroll()
	boss.begin_phase_two()
	boss.phase_two.entry_left = 0
	boss.position = Vector2(700,240)
	var bar: Control
	for layer in boss.get_children():
		for node in layer.get_children():
			if node.get_script() != null and node.get_script().get_global_name() == "CorrumptHealthBar":bar = node
	bar.set_process(false)
	boss.hp = 650
	bar._process(1)
	await _save("normal")
	var packet := DamagePacket.new(1)
	packet.poise_key = &"normal:hammer_01:1"
	for index in 7:boss.receive_hit(packet)
	bar._process(0.3)
	await _save("broken")
	boss._physics_process(5.001)
	bar._process(0.1)
	await _save("recover")
	print("POISE PREVIEW: normal, broken, recover; actual gameplay UI")
	quit()

func _save(state: String) -> void:
	for index in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/corrumpt_bar_%s.png" % state))
