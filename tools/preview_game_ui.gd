extends SceneTree
## 用 Godot 实际渲染 HUD / 行囊 / 坐火 / 天赋 / 仓库预览，测试数据不写入正式存档。

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() else "hud"
	root.size = Vector2i(1280,800) if args.size() > 1 and args[1] == "16_10" else Vector2i(1280,720)
	var gs := root.get_node("GameState")
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	gs.reset()
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	for frame in 8:
		await physics_frame
	# 窗口初始化会覆盖 _initialize 阶段尺寸；在首帧之后验证真实比例。
	root.size = Vector2i(1280,800) if args.size() > 1 and args[1] == "16_10" else Vector2i(1280,720)
	await process_frame
	var ui := root.get_node("GameUI")
	var actor := current_scene.get_node("Player") as CharacterBody2D
	actor.position = Vector2(1056,655)
	actor.velocity = Vector2.ZERO
	actor.cam.global_position = Vector2(960,600)
	for frame in 8:
		await physics_frame
	actor.set_physics_process(false)
	for item: Dictionary in service.config().preview_items:
		service.add_item(item.id,int(item.count))
	service.add_item("mushroom",12)
	service.register_hotbar("potion_small",0)
	service.register_hotbar("potion_mana",1)
	service.register_hotbar("potion_sta",2)
	service.register_hotbar("milk_bomb",3)
	gs.hp = 58
	gs.sta = 72
	gs.mana = 38
	gs.coin = 480
	gs.level = 4
	if mode == "inventory":
		ui.open_inventory()
		ui._slot_activated("inventory",0)
	elif mode in ["rest","talents","storage"]:
		ui.begin_rest()
		if mode == "talents":
			ui._show_talents()
		if mode == "storage":
			service.deposit(1)
			ui._show_storage()
	for frame in 55:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/previews/ui_%s%s.png" % [mode,"_16_10" if args.size() > 1 and args[1] == "16_10" else ""]
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("UI render: %s (%dx%d), error=%d" % [path,root.size.x,root.size.y,error])
	quit(error)
