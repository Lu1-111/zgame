extends SceneTree
## 单实例、限帧离屏渲染所有正式UI，结束后自动关闭，不打开试玩窗口。
func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	service.config().save.directory = "user://qa_skin_preview/"
	root.get_node("GameState").reset()
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for frame in 10:
		await physics_frame
	root.size = Vector2i(1280,720)
	var actor := current_scene.get_node("Player")
	var ui := root.get_node("GameUI")
	actor.position = Vector2(384,527)
	for frame in 8:
		await physics_frame
	actor.set_physics_process(false)
	for entry: Dictionary in service.config().preview_items:
		service.add_item(entry.id,int(entry.count))
	service.register_hotbar("potion_small",0)
	service.register_hotbar("potion_mana",1)
	for mode in ["equipment","attributes","skills","inventory","pause","dialogue","rest","hud"]:
		ui._force_close()
		for npc in get_nodes_in_group(&"npc"):
			npc.close_interaction()
		actor.position = Vector2(384,527)
		actor.sprite.play(&"idle")
		if mode in ["equipment","attributes","skills"]:
			ui.open_character()
			ui._character.open(mode)
			if mode == "equipment":
				ui._character._activate("weapon_inventory",0)
			if mode == "skills":
				ui._character._activate("active_skill",5)
		elif mode == "inventory":
			ui.open_inventory()
			ui._slot_activated("hotbar",0)
		elif mode == "pause":
			ui._show_pause()
		elif mode == "dialogue":
			actor.position = Vector2(426,527)
			current_scene.get_node("MilkRabbit").interact()
		elif mode == "rest":
			actor.position = Vector2(340,527)
			ui.begin_rest()
		else:
			actor.position = Vector2(340,527)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://docs/previews/rpg_%s_v3.png" % mode)
		var error := root.get_texture().get_image().save_png(path)
		print("Skin preview %s: %d" % [mode,error])
	ui._force_close()
	quit()
