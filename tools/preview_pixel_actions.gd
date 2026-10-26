extends SceneTree
## 相同像素倍率下对照闲置、剑击、拉弓，直观看原角色形体和像素密度。
func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152,432)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("#14272b")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var paths := ["res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png","res://assets/PROCESSED/characters/CHR-01/rpg_v2/sword_1_02.png","res://assets/PROCESSED/characters/CHR-01/rpg_v2/bow_shot_04.png"]
	for index in 3:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = load(paths[index])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(index*384,0)
		sprite.scale = Vector2.ONE*6
		viewport.add_child(sprite)
		var label := Label.new()
		label.text = ["原闲置 · 64×64","剑击 · 64×64","拉弓 · 64×64"][index]
		label.position = Vector2(index*384+80,391)
		label.add_theme_font_size_override("font_size",20)
		viewport.add_child(label)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/rpg_pixel_identity.png"))
	print("Pixel identity preview: error=%d" % error)
	quit(error)
