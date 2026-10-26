extends SceneTree
## 渲染新人物面板、暂停、对话与攻击校准帧，测试数据隔离存放。
func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[0]) if args.size() else "equipment"
	var gs := root.get_node("GameState")
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	var rpg: GDScript = load("res://scripts/core/rpg_service.gd")
	service.config().save.directory = "user://qa_rpg_previews/"
	gs.reset()
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	for frame in 10:
		await physics_frame
	root.size = Vector2i(1280,800) if args.size()>1 and args[1] == "16_10" else Vector2i(1280,720)
	var ui := root.get_node("GameUI")
	var actor := current_scene.get_node("Player")
	actor.position = Vector2(384,527)
	actor.velocity = Vector2.ZERO
	for frame in 8:
		await physics_frame
	if mode in ["equipment","attributes","skills"]:
		ui.open_character()
		if mode == "equipment":
			ui._character._activate("weapon_inventory",0)
		else:
			rpg.equip_skill(&"passive_01",0,true)
			ui._character.open(mode)
			if mode == "skills":
				ui._character._activate("active_skill",5)
	elif mode == "pause":
		ui._show_pause()
	elif mode == "inventory":
		for entry: Dictionary in service.config().preview_items:
			service.add_item(entry.id,int(entry.count))
		service.register_hotbar("potion_small",0)
		service.register_hotbar("potion_mana",1)
		service.register_hotbar("potion_sta",2)
		service.register_hotbar("milk_bomb",3)
		ui.open_inventory()
		ui._slot_activated("hotbar",0)
	elif mode == "dialogue":
		actor.position = Vector2(426,527)
		actor.velocity = Vector2.ZERO
		for frame in 12:
			await physics_frame
		current_scene.get_node("MilkRabbit").interact()
	elif mode.begins_with("combat_"):
		actor.position = Vector2(520,527)
		actor.velocity = Vector2.ZERO
		actor.cam.zoom = Vector2(2,2)
		actor.cam.global_position = actor.position
		var kind := mode.trim_prefix("combat_")
		gs.weapon_id = &"sword_01" if kind == "sword" else (&"bow_01" if kind == "bow" else (&"milk_staff" if kind == "staff" else &"hammer_01"))
		for frame in 8:
			await physics_frame
		if kind == "bow":
			Input.action_press("attack")
		actor.sm.to(&"Attack",{"combo":3 if kind == "hammer3" else (2 if kind == "hammer2" else 1)})
		var frames := 53 if kind == "bow" else (18 if kind.begins_with("hammer") else 13)
		for frame in frames:
			await physics_frame
		paused = true
	for frame in 48:
		await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "_16_10" if args.size()>1 and args[1] == "16_10" else ""
	var path := "res://docs/previews/rpg_%s%s.png" % [mode,suffix]
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("RPG render: %s, error=%d" % [path,error])
	quit(error)
