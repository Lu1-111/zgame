extends SceneTree
## 直接播放已接入游戏的完整 PNG，核对七关键姿势与左右连续连击。
var _view: SubViewport
var _manifest: Dictionary


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	create_timer(35,true,false,true).timeout.connect(func() -> void: quit(2))
	_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/sword_pixel_frames.json"))
	_create_view(Vector2i(2048,768))
	for index in _manifest.keyframes.size():
		var spec: Dictionary = _manifest.keyframes[index]
		var column: int = index%4
		var row: int = index/4
		var group := Node2D.new()
		group.position = Vector2(column*512+224,row*384+302)
		group.scale = Vector2.ONE*5
		group.z_index = 20
		_view.add_child(group)
		var rig := PixelHeroRig.new()
		group.add_child(rig)
		rig.sword_pose = "ready" if spec.clip == "ready" else "attack"
		rig.combo = int(str(spec.clip).trim_prefix("sword_")) if spec.clip != "ready" else 1
		rig.progress = float(spec.progress)
		rig.apply_pose()
		_floor(Vector2(column*512+24,row*384+303),464)
		_label(str(spec.name),Vector2(column*512+20,row*384+334))
	await _draw_frame()
	_view.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/sword_seven_v11.png"))
	if "--poses-only" in OS.get_cmdline_user_args():
		print("PIXEL SWORD PREVIEW: 7 native character poses")
		quit()
		return
	_view.queue_free()
	_create_view(Vector2i(768,400))
	var rigs: Array[PixelHeroRig] = []
	for side in 2:
		var group := Node2D.new()
		group.position = Vector2(side*384+192,310)
		group.scale = Vector2.ONE*4
		group.z_index = 20
		_view.add_child(group)
		var rig := PixelHeroRig.new()
		group.add_child(rig)
		rig.facing = 1 if side == 0 else -1
		rigs.append(rig)
		_floor(Vector2(side*384+24,311),336)
	var caption := _label("",Vector2(150,18))
	_label("双手持剑 · 左脚踏步 · 首尾同架势 · 三倍慢放",Vector2(156,366))
	var destination := ProjectSettings.globalize_path("res://work/sword_v11/movie/")
	DirAccess.make_dir_recursive_absolute(destination)
	for frame in 144:
		var combo := frame/48+1
		var progress := float(frame%48)/47
		caption.text = ["①肩扛 → ②下劈触地 → ③收剑压低","③收剑压低 → ④双臂前刺 → ⑤身后蓄势","⑤身后蓄势 → ⑥踏步挑斩 → ⑦收脚回肩"][combo-1]
		for rig in rigs:
			rig.combo = combo
			rig.progress = progress
			rig.apply_pose()
		await _draw_frame()
		_view.get_texture().get_image().save_png(destination+"frame_%03d.png" % frame)
	print("PIXEL SWORD PREVIEW: 7 poses, 144 chained frames, left/right")
	quit()


func _create_view(dimensions: Vector2i) -> void:
	_view = SubViewport.new()
	_view.size = dimensions
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var background := ColorRect.new()
	background.color = Color("#20251f")
	background.size = Vector2(dimensions)
	_view.add_child(background)


func _floor(point: Vector2, length: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([point,point+Vector2(length,0)])
	line.width = 1
	line.default_color = Color("#717669")
	_view.add_child(line)


func _label(caption: String, point: Vector2) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = point
	label.z_index = 50
	label.add_theme_font_override("font",RPGSkin.font())
	label.add_theme_font_size_override("font_size",17)
	_view.add_child(label)
	return label


func _draw_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
