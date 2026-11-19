extends SceneTree
## 左列展示实际攻击武器，右三列展示由同源武器制作的格挡动作。
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	create_timer(30,true,false,true).timeout.connect(func() -> void: quit(2))
	var view := SubViewport.new()
	view.size = Vector2i(1200,800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bg := ColorRect.new()
	bg.size = Vector2(view.size)
	bg.color = Color("#22251f")
	view.add_child(bg)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_frames.json"))
	var animated: Array[Sprite2D] = []
	var captions: Array[Label] = []
	for row in 4:
		var kind: String = cfg.weapons[row]
		for column in 4:
			var base := Vector2(130+column*300,175+row*200)
			if column == 0 and kind == "rifle":
				var rig := PixelHeroRig.new()
				view.add_child(rig)
				rig.position = base
				rig.scale = Vector2.ONE*2.5
				rig.kind = "rifle"
				rig.progress = 0.4
				rig.aim = Vector2.RIGHT
				rig.apply_pose()
				rig.scale = Vector2.ONE*2.5
			else:
				var sprite := Sprite2D.new()
				sprite.centered = false
				sprite.position = base
				sprite.scale = Vector2.ONE*2.5
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var path := str(cfg.export_dir)+"guard_%s_%02d.png" % [kind,column-1]
				var anchor := Vector2(cfg.anchor[0],cfg.anchor[1])
				if column == 0:
					path = str(cfg.weapon_sources[kind].reference) if kind == "sword" else str(cfg.weapon_sources[kind].path)
					anchor = Vector2(48,84) if kind == "sword" else Vector2(48,90)
				sprite.texture = load(path)
				sprite.offset = -anchor
				view.add_child(sprite)
				if column == 1:
					animated.append(sprite)
			var label := Label.new()
			label.text = ["剑","枪","锤","杖"][row]+" · "+["攻击原素材","准备","举起","胸前就位"][column]
			label.position = Vector2(65+column*300,12+row*200)
			label.add_theme_font_override("font",RPGSkin.font())
			label.add_theme_font_size_override("font_size",18)
			view.add_child(label)
			if column == 1:
				captions.append(label)
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/guard_weapon_match.png"))
	view.size.x = 600
	var folder := ProjectSettings.globalize_path("res://work/guard_arm_fix/movie/")
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in 40:
		var pose := 0 if frame < 3 else (1 if frame < 6 else (2 if frame < 24 else (1 if frame < 27 else (0 if frame < 30 else -1))))
		for row in 4:
			var name: String = cfg.weapons[row]
			if pose >= 0:
				animated[row].texture = load(str(cfg.export_dir)+"guard_%s_%02d.png" % [name,pose])
				animated[row].offset = -Vector2(cfg.anchor[0],cfg.anchor[1])
			else:
				animated[row].texture = load("res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png")
				animated[row].offset = Vector2(-32,-58)
			var phase := "准备" if frame < 3 else ("举起" if frame < 6 else ("胸前维持" if frame < 24 else ("解除" if frame < 30 else "闲置")))
			captions[row].text = ["剑","枪","锤","杖"][row]+" · "+phase
		await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(folder+"frame_%02d.png" % frame)
	print("GUARD MATCH: original attack and three guard poses, four matched weapon types")
	quit()
