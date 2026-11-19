extends SceneTree
## 直接复用正式攻击帧的完整身体和原生双臂，不擦除或重画手臂。
## 离屏对齐既有武器后生成完整逐帧 PNG，运行时不拆分角色。
var _cfg: Dictionary
var _native: Dictionary
var _offset: Vector2i
var _kind := ""
var _weapon_image: Image
var _view: SubViewport
var _sources := {}

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	create_timer(45,true,false,true).timeout.connect(func() -> void: quit(2))
	_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_frames.json"))
	_native = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_motion.json"))
	_offset = Vector2i(_cfg.anchor[0]-_cfg.native_anchor[0],_cfg.anchor[1]-_cfg.native_anchor[1])
	var folder := ProjectSettings.globalize_path(_cfg.export_dir)
	DirAccess.make_dir_recursive_absolute(folder+"weapons/")
	DirAccess.make_dir_recursive_absolute(folder+"bodies/")
	for index in _cfg.poses.size():
		var pose: Dictionary = _cfg.poses[index]
		var source: Dictionary = _native.native_motion.frames[pose.source]
		pose.source_path = source.path
		pose.source_sha256 = FileAccess.get_sha256(source.path)
		pose.source_origin = source.origin
		pose.weapon_masks = source.masks
		pose.body_path = str(_cfg.export_dir)+"bodies/body_%02d.png" % index
		_native_body(pose).save_png(ProjectSettings.globalize_path(pose.body_path))
		pose.body_sha256 = FileAccess.get_sha256(pose.body_path)
	_view = SubViewport.new()
	_view.size = Vector2i(_cfg.canvas[0],_cfg.canvas[1])
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_presentation.json"))
	for kind: String in _cfg.weapons:
		_kind = kind
		var paths: Array = []
		var anchors: Array = []
		var provenance: Dictionary = _cfg.weapon_sources[kind].duplicate(true)
		if kind in ["hammer","staff"]:
			var source: Dictionary = _native.native_motion.frames[provenance.frame]
			provenance.path = source.path
			provenance.sha256 = FileAccess.get_sha256(source.path)
			if provenance.has("complete_handle"):
				provenance.complete_handle.reference_sha256 = FileAccess.get_sha256(provenance.complete_handle.reference)
			_sources[kind] = _extract_weapon(provenance)
		else:
			provenance.sha256 = FileAccess.get_sha256(provenance.renderer)
			provenance.motion_sha256 = FileAccess.get_sha256("res://data/hero_motion.json")
		provenance.frames = []
		for index in _cfg.poses.size():
			var name := "guard_%s_%02d" % [kind,index]
			_weapon_image = await _capture_weapon(_cfg.poses[index])
			var layer_path := str(_cfg.export_dir)+"weapons/"+name+".png"
			_weapon_image.save_png(ProjectSettings.globalize_path(layer_path))
			var frame_path := str(_cfg.export_dir)+name+".png"
			_render_native_pose(frame_path,_cfg.poses[index])
			paths.append(frame_path)
			anchors.append(_cfg.anchor)
			provenance.frames.append({"path":frame_path,"weapon_path":layer_path,"weapon_sha256":FileAccess.get_sha256(layer_path)})
		_cfg.weapon_sources[kind] = provenance
		combat.animations["guard_"+kind] = {"fps":1.0/float(_native.guard.raise_frame_seconds),"frame_paths":paths,"anchors":anchors,"scale":1.0}
	_write_json("res://data/combat_presentation.json",combat)
	_write_json("res://data/guard_frames.json",_cfg)
	_view.queue_free()
	print("GUARD V3: 12 complete frames, original attack arms, chest-height hold, shared weapon sources")
	quit()

func _capture_weapon(pose: Dictionary) -> Image:
	var angle := deg_to_rad(float(pose.angle_degrees))
	var direction := Vector2.from_angle(angle)
	var hand := _vec(pose.hand)+Vector2(_offset)
	var node: Node2D
	if _kind in ["sword","rifle"]:
		# 直接使用攻击模组本身的绘制方法，避免第二份外形定义。
		var rig := PixelHeroRig.new()
		_view.add_child(rig)
		rig.kind = _kind
		rig._frame_data = {}
		rig._whole_body.hide()
		rig._upper_body.hide()
		rig._native_hands.hide()
		rig.position = rig._anchor
		rig._sword_angle = angle
		rig._local_aim = direction
		rig._depth = 1.0
		var normal := Vector2(-direction.y,direction.x)
		rig._grip = hand+direction*float(_native.sword.hand_to_guard) if _kind == "sword" else hand-direction*3-normal*3
		rig.queue_redraw()
		node = rig
	else:
		var spec: Dictionary = _cfg.weapon_sources[_kind]
		var sprite := Sprite2D.new()
		sprite.texture = _sources[_kind]
		sprite.centered = false
		sprite.offset = -_vec(spec.source_hand)-_vec(spec.source_origin)
		sprite.position = hand
		sprite.rotation = angle-deg_to_rad(float(spec.source_angle_degrees))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_view.add_child(sprite)
		node = sprite
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _view.get_texture().get_image()
	node.free()
	return image

func _extract_weapon(spec: Dictionary) -> ImageTexture:
	var original := Image.load_from_file(ProjectSettings.globalize_path(spec.path))
	original.convert(Image.FORMAT_RGBA8)
	var image := Image.create(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	if spec.has("complete_handle"):
		# 攻击帧中被手掌遮住的短柄，按同源握柄的尺寸与原像素色板补全。
		var shaft: Dictionary = spec.complete_handle
		var reference := Image.load_from_file(ProjectSettings.globalize_path(shaft.reference))
		var hand := Vector2i(spec.source_hand[0]+spec.source_origin[0],spec.source_hand[1]+spec.source_origin[1])
		for row in range(-int(shaft.half_width),int(shaft.half_width)+1):
			var point: Array = shaft.color_samples[row+int(shaft.half_width)]
			var color := reference.get_pixel(int(point[0]+shaft.reference_origin[0]),int(point[1]+shaft.reference_origin[1]))
			image.fill_rect(Rect2i(hand.x-int(shaft.back_length),hand.y+row,int(shaft.back_length+shaft.front_length)+1,1),color)
	for region: Array in spec.regions:
		var rect := _rect(region)
		rect.position += Vector2i(spec.source_origin[0],spec.source_origin[1])
		image.blit_rect(original,rect,rect.position)
	return ImageTexture.create_from_image(image)

func _native_body(pose: Dictionary) -> Image:
	var raw := Image.load_from_file(ProjectSettings.globalize_path(pose.source_path))
	raw.convert(Image.FORMAT_RGBA8)
	var size := Vector2i(_native.canvas[0],_native.canvas[1])
	var origin := Vector2i(pose.source_origin[0],pose.source_origin[1])
	var source := raw.get_region(Rect2i(origin,size))
	# 与攻击素材的去武器规则一致；保留原图的肩臂、掌形、阴影和轮廓。
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x,y)
			if color.b > color.r*1.015 and color.b > color.g*1.005:
				source.set_pixel(x,y,Color.TRANSPARENT)
	for region: Array in pose.weapon_masks:
		source.fill_rect(_rect(region),Color.TRANSPARENT)
	var body := Image.create(_cfg.canvas[0],_cfg.canvas[1],false,Image.FORMAT_RGBA8)
	body.fill(Color.TRANSPARENT)
	body.blit_rect(source,Rect2i(Vector2i.ZERO,size),_offset)
	return body

func _render_native_pose(path: String, pose: Dictionary) -> void:
	var body := _native_body(pose)
	var image := body.duplicate() as Image
	image.blend_rect(_weapon_image,Rect2i(Vector2i.ZERO,_weapon_image.get_size()),Vector2i.ZERO)
	# 肩臂保留在武器后方，仅原图中实际握持的掌指遮挡少量握柄。
	for region: Array in pose.palm_regions:
		var rect := _rect(region)
		rect.position += _offset
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var color := body.get_pixel(x,y)
				var limits: Array = _cfg.palm_occlusion.belly_rgb_min
				var belly := color.r > float(limits[0]) and color.g > float(limits[1]) and color.b > float(limits[2])
				if color.a > float(_cfg.palm_occlusion.alpha_min) and not belly:
					image.set_pixel(x,y,color)
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("导出原生肩臂格挡帧失败："+path)

func _rect(values: Array) -> Rect2i:
	return Rect2i(values[0],values[1],values[2],values[3])

func _vec(values: Array) -> Vector2:
	return Vector2(values[0],values[1])

func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"  ",false)+"\n")
	file.close()
