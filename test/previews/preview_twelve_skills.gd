extends SceneTree
## 离屏渲染合作者十二招及实际技能菜单，不启动持续运行的游戏窗口。

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	create_timer(45,true,false,true).timeout.connect(func() -> void: quit(2))
	var view := SubViewport.new()
	view.size = Vector2i(1200,960)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.color = Color("#222723")
	background.size = Vector2(view.size)
	view.add_child(background)
	var poses := ["skill_omni_slash__finisher","skill_giga_milk_beam__release","skill_comet_dash__dash","skill_star_milk_prison__cast","skill_mirror_milk_guard__guard_loop","skill_milk_spring__cast","SKL-N01_counter_slash","SKL-N02_laugh_loop","SKL-N03_slam","SKL-N04_brace_recover","SKL-N05_release","SKL-N06_rise"]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	for index in 12:
		var definition: Dictionary = data.skills[index]
		var spec := SkillLibrary.runtime(StringName(definition.id))
		var tile := Control.new()
		tile.position = Vector2(index%3*400,floorf(index/3.0)*240)
		tile.size = Vector2(400,240)
		tile.clip_contents = true
		view.add_child(tile)
		var line := ColorRect.new()
		line.position = Vector2(10,220)
		line.size = Vector2(380,1)
		line.color = Color("#535e50")
		tile.add_child(line)
		_label(tile,str(definition.name),Vector2(18,12),18)
		var icon := TextureRect.new()
		icon.position = Vector2(345,12)
		icon.size = Vector2(36,36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = load(str(definition.icon))
		tile.add_child(icon)
		var body := Node2D.new()
		body.position = Vector2(100,208)
		body.scale = Vector2.ONE*2
		tile.add_child(body)
		var pose := SkillLibrary.animation(str(poses[index]))
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = SkillLibrary.texture(str(pose.frames[mini(1,pose.frames.size()-1)]))
		sprite.offset = -Vector2(pose.root[0],pose.root[1])
		body.add_child(sprite)
		if index == 1:
			var beam: Node2D = load("res://scripts/player/skill_entity.gd").new()
			beam.mode = "beam"
			beam.specification = spec
			beam.beam_length = 125
			beam.beam_height = 24
			beam.position = Vector2(14,-30)
			body.add_child(beam)
			beam.set_physics_process(false)
		else:
			var fx := str(spec.get("aura",spec.get("fx","")))
			var point := Vector2.ZERO
			if str(spec.behavior) == "buff":
				point = Vector2(0,-20)
			elif index == 6:
				fx = str(spec.counter_fx)
				point = Vector2(34,-24)
			elif index == 10:
				point = Vector2(55,-24)
			else:
				var raw: Array = SkillLibrary.animation(fx).attachment
				point = Vector2(raw[0],raw[1])
			var art := SkillArt.spawn(body,fx,point,99)
			art.frame_override = 1
			art.set_physics_process(false)
		_label(tile,"体力 %d / 奶力 %d · 冷却 %ds" % [definition.stamina_cost,definition.mana_cost,definition.cooldown],Vector2(18,223),11)
	await _draw_frame()
	view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/twelve_skills_imported.png"))
	view.queue_free()
	var gs := root.get_node("GameState")
	var ui := root.get_node("GameUI")
	gs.reset()
	change_scene_to_file("res://scenes/maps/camp_01.tscn")
	for step in 6:
		await process_frame
	while ui.player == null:
		await process_frame
	ui.open_character()
	ui._character.selected_skill = &"skill_nb_void_milk"
	ui._character.open("skills")
	await _draw_frame()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/twelve_skills_menu.png"))
	ui._force_close()
	print("SKILL PREVIEW: twelve_skills_imported.png, twelve_skills_menu.png")
	quit()

func _draw_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func _label(parent: Node, caption: String, pos: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = caption
	label.position = pos
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("#dfdbc0"))
	parent.add_child(label)
