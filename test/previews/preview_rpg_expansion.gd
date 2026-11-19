extends SceneTree
## 离屏检查格挡三帧、点数页、属性页与仓库；由看护进程限制内存和时长。

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	create_timer(45,true,false,true).timeout.connect(func() -> void: quit(2))
	var view := SubViewport.new()
	view.size = Vector2i(960,800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(view.size)
	background.color = Color("#22251f")
	view.add_child(background)
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_frames.json"))
	for row in 4:
		for col in 3:
			var name := "guard_%s_%02d" % [art.weapons[row],col]
			var sprite := Sprite2D.new()
			sprite.texture = load(str(art.export_dir)+name+".png")
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(195+col*290,112+row*200)
			sprite.offset = Vector2(0,-12)
			sprite.scale = Vector2.ONE*2.5
			view.add_child(sprite)
			_label(view,["剑","枪","锤","杖"][row]+" · "+["准备","举起","维持"][col],Vector2(125+col*290,12+row*200))
	await _draw_frame()
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/guard_four_weapons.png"))
	view.queue_free()
	var gs := root.get_node("GameState")
	var ui := root.get_node("GameUI")
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	var progression: GDScript = load("res://scripts/core/progression_service.gd")
	gs.reset()
	change_scene_to_file("res://scenes/maps/camp_01.tscn")
	for step in 5:
		await process_frame
	while ui.player == null:
		await process_frame
	gs.milk_energy = 8
	gs.level = 3
	gs.exp = 160
	gs.coin = 250
	gs.attribute_points = {"vitality":2,"endurance":1,"strength":1,"intellect":1,"perception":1}
	gs.permanent_bonuses = {"hp_max":20}
	progression.refresh_limits()
	service.add_item("potion_small",3)
	service.add_item("potion_mana",2)
	service.add_item("mushroom",8)
	ui.open_character()
	ui._character.open("attributes")
	await _save_root("attributes_two_columns")
	ui._resting = true
	ui._show_talents()
	await _save_root("fire_attributes")
	gs.storage = [{"id":"potion_sta","count":3},{"id":"sword_01","count":1},{"id":"milk_staff","count":1}]
	ui._show_storage()
	await _save_root("storage_categories")
	ui._force_close()
	gs.coin += 50
	await _save_root("hud_level_coin")
	print("RPG PREVIEW: four weapon guards and four UI captures")
	quit()

func _save_root(name: String) -> void:
	await _draw_frame()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/"+name+".png"))

func _draw_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func _label(parent: Node, caption: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = caption
	label.position = pos
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",18)
	parent.add_child(label)
