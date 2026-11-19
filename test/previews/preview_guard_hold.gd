extends SceneTree
## 放大展示实际胸前维持帧，检查原生手臂、握柄、枪身和掌指遮挡。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280,380)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(view.size)
	background.color = Color("#22251f")
	view.add_child(background)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_frames.json"))
	for index in 4:
		var sprite := Sprite2D.new()
		sprite.texture = load(str(cfg.export_dir)+"guard_%s_02.png" % cfg.weapons[index])
		sprite.centered = false
		sprite.offset = -Vector2(cfg.anchor[0],cfg.anchor[1])
		sprite.scale = Vector2.ONE*5
		sprite.position = Vector2(138+index*320,330)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.add_child(sprite)
		var label := Label.new()
		label.text = ["剑","枪","锤","杖"][index]+" · 胸前格挡"
		label.position = Vector2(55+index*320,30)
		label.add_theme_font_override("font",RPGSkin.font())
		label.add_theme_font_size_override("font_size",22)
		view.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/guard_arms_chest.png"))
	print("GUARD HOLD: original arms and complete weapons at chest height")
	quit()
