extends SceneTree
## 离屏渲染旅行页、坐火页和空血条死亡帧，隔离测试存档。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var ui := root.get_node("GameUI")
	var gs := root.get_node("GameState")
	gs.reset()
	change_scene_to_file("res://scenes/maps/forest_02.tscn")
	for frame in 10:
		await process_frame
	var actor := current_scene.get_node("Player") as Node2D
	actor.position = Vector2(304,1695)
	for frame in 8:
		await process_frame
	gs.hp = 37
	gs.sta = 63
	gs.mana = 28
	ui.begin_rest()
	await _save("rest_1030")
	gs.unlocked_campfires.append(&"cp_camp_01")
	ui.open_fast_travel()
	await _save("fast_travel_1030")
	ui._force_close()
	actor.call("stop_presentation_animation")
	var enemy := current_scene.get_node("Enemy_f02_upper_w1") as Node2D
	enemy.set_physics_process(false)
	actor.set_physics_process(false)
	actor.position = enemy.position+Vector2(-65,-17)
	var camera := actor.get_node("Camera") as Camera2D
	camera.global_position = enemy.position+Vector2(0,-60)
	camera.force_update_scroll()
	enemy.call("receive_hit",DamagePacket.new(999))
	await _save("enemy_empty_health_1030")
	quit()

func _save(name: String) -> void:
	for frame in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/%s.png" % name))
	if error != OK:
		push_error("Preview save failed: %s" % name)
