extends SceneTree
## 单个离屏窗口检查三种剑光及真实接触轮廓，不改动人物素材。
class ContactOverlay extends Node2D:
	var polygons: Array[PackedVector2Array] = []
	func _draw() -> void:
		for polygon in polygons:
			draw_colored_polygon(polygon,Color(1,0.3,0.55,0.055))
			var edge := polygon.duplicate()
			edge.append(edge[0])
			draw_polyline(edge,Color(1,0.4,0.6,0.8),0.3,true)


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	create_timer(50,true,false,true).timeout.connect(func() -> void: quit(2))
	var view := SubViewport.new()
	view.size = Vector2i(960,740)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(view.size)
	background.color = Color("#20231f")
	view.add_child(background)
	var rigs: Array[PixelHeroRig] = []
	var effects: Array[SwordAttackEffect] = []
	var manifest := SwordAttackEffect.frame_manifest()
	for row in 2:
		for combo in 3:
			var group := Node2D.new()
			group.position = Vector2(combo*320+160,row*360+300)
			group.scale = Vector2.ONE*3
			view.add_child(group)
			var rig := PixelHeroRig.new()
			group.add_child(rig)
			rig.combo = combo+1
			var fx := SwordAttackEffect.new()
			fx.combo = combo+1
			group.add_child(fx)
			var index: int = [5,5,4][combo]
			var entries: Array = manifest.clips["sword_%d" % (combo+1)].frames
			var progress := (float(entries[index].progress)+float(entries[index+1].progress))/2
			rig.progress = progress
			rig.apply_pose()
			fx.sample_attack_progress(progress)
			rigs.append(rig)
			effects.append(fx)
			var floor_line := Line2D.new()
			floor_line.points = PackedVector2Array([Vector2(-50,0),Vector2(50,0)])
			floor_line.width = 0.35
			floor_line.default_color = Color("#7d837080")
			group.add_child(floor_line)
			if row == 1:
				var overlay := ContactOverlay.new()
				overlay.z_index = 2
				overlay.polygons = fx.get_contact_polygons()
				group.add_child(overlay)
			_label(view,["Ⅰ  下劈至地面","Ⅱ  从地面上挑","Ⅲ  向前突刺"][combo],Vector2(combo*320+90,row*360+16))
	_label(view,"粉线：剑身与剑光的实际接触范围，向外保留 2 像素",Vector2(211,710))
	await _draw_frame()
	var error := view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/sword_contact_bounds.png"))
	if error != OK:
		quit(error)
	view.size = Vector2i(960,370)
	var folder := ProjectSettings.globalize_path("res://work/sword_contact/movie/")
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in 48:
		for index in 3:
			rigs[index].progress = frame/47.0
			rigs[index].apply_pose()
			effects[index].sample_attack_progress(frame/47.0)
		await _draw_frame()
		if view.get_texture().get_image().save_png(folder+"frame_%02d.png" % frame) != OK:
			quit(1)
	print("SWORD CONTACT PREVIEW: collision overlay + 48 movie frames")
	quit()


func _draw_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _label(parent: Node, caption: String, point: Vector2) -> void:
	var label := Label.new()
	label.text = caption
	label.position = point
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("#ddd9c7"))
	parent.add_child(label)
