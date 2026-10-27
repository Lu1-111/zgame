extends SceneTree
## 原锤/新纵斩、原射击/新步枪的同像素密度慢放对照。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(960,340)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.color = Color("#20231f")
	background.size = Vector2(view.size)
	view.add_child(background)
	var reference: Array[Sprite2D] = []
	for column in [0,2]:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		sprite.offset = Vector2(-32,-58)
		sprite.position = Vector2(column*240+110,290)
		sprite.scale = Vector2.ONE*4
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.add_child(sprite)
		reference.append(sprite)
	var sword := PixelHeroRig.new()
	var rifle := PixelHeroRig.new()
	for entry in [[sword,350],[rifle,830]]:
		view.add_child(entry[0])
		entry[0].position = Vector2(entry[1],290)
		entry[0].scale = Vector2.ONE*4
	rifle.kind = "rifle"
	for column in 4:
		_label(view,["原锤动作","重做纵斩","原射击动作","重做步枪"][column],Vector2(column*240+52,17),18)
		var floor := ColorRect.new()
		floor.position = Vector2(column*240+28,292)
		floor.size = Vector2(184,1)
		floor.color = Color("#6d746259")
		view.add_child(floor)
	_label(view,"慢放对照 · 保持原像素密度与正式动作的手臂画法",Vector2(252,318),15)
	var output := ProjectSettings.globalize_path("res://work/actions_v6/gif/")
	DirAccess.make_dir_recursive_absolute(output)
	for frame in 24:
		var native_index := mini(frame/6+1,4)
		reference[0].texture = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_hammer_3_right_v001_f%02d.png" % native_index)
		reference[0].region_rect = Rect2(16,32,64,64)
		var shot_index := 1 if frame < 6 or frame >= 15 else mini(2+(frame-6)/3,4)
		reference[1].texture = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_blaster_fire_right_v001_f%02d.png" % shot_index)
		reference[1].region_rect = Rect2(0,0,64,64)
		sword.progress = float(frame)/23
		sword.apply_pose()
		sword.scale = Vector2.ONE*4
		rifle.progress = float(frame)/23
		rifle.release_time = -1.0 if frame < 6 else float(frame-6)/30
		rifle.apply_pose()
		rifle.scale = Vector2.ONE*4
		for tick in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(output+"frame_%02d.png" % frame)
	print("Native motion comparison: 24 frames")
	quit()

func _label(parent: Node, text: String, point: Vector2, length: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",length)
	label.add_theme_color_override("font_color",Color("#d8d5c2"))
	parent.add_child(label)
