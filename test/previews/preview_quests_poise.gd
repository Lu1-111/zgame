extends SceneTree
## 单个隐藏实例输出任务、追踪和全界面样式截图，完成后自动结束。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280,720)
	var state := root.get_node("GameState")
	state.reset()
	change_scene_to_file("res://scenes/maps/camp_01.tscn")
	for frame in 12:
		await process_frame
	var actor := current_scene.get_node("Player")
	var ui := root.get_node("GameUI")
	var quests: GDScript = load("res://scripts/core/quest_service.gd")
	var inventory: GDScript = load("res://scripts/core/inventory_service.gd")
	for entry: Dictionary in inventory.config().preview_items:
		inventory.add_item(entry.id,int(entry.count))
	inventory.register_hotbar("potion_small",0)
	inventory.register_hotbar("potion_mana",1)
	quests.toggle_tracking(&"main_forest_fire")
	actor.set_physics_process(false)
	actor.position = Vector2(384,527)
	var requested := OS.get_cmdline_user_args()
	var modes: Array = Array(requested) if not requested.is_empty() else ["quests","hud","map","inventory","equipment","attributes","skills","pause","rest","dialogue"]
	for mode in modes:
		ui._force_close()
		actor.stop_presentation_animation()
		for npc in get_nodes_in_group(&"npc"):
			npc.close_interaction()
		actor.position = Vector2(384,527)
		match mode:
			"quests": ui.open_quests()
			"map": ui.open_world_map()
			"inventory": ui.open_inventory()
			"equipment","attributes","skills":
				ui.open_character()
				ui._character.open(mode)
			"pause": ui._show_pause()
			"rest":
				actor.position = Vector2(340,527)
				ui.begin_rest()
			"dialogue":
				actor.position = Vector2(426,527)
				current_scene.get_node("MilkRabbit").interact()
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/ui_%s_1031.png" % mode))
		print("UI 1031 %s: %d" % [mode,error])
	ui._force_close()
	quit()
