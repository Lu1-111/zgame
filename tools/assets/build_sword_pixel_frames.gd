extends SceneTree
## 原版逐帧人物像素修帧：保留原头身，局部修补双臂与持剑，独立导出整张 PNG。
## 仅读取既有逐帧素材，按原像素密度导出完整角色动作帧。
const CONFIG := "res://data/sword_pixel_frames.json"
var _cfg: Dictionary
var _native: Dictionary
var _body_cache: Dictionary = {}
var _offset: Vector2i
var _repair: Image
var _palm: Image


func _initialize() -> void:
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	_native = JSON.parse_string(FileAccess.get_file_as_string(_cfg.source_manifest))
	_offset = Vector2i(_cfg.anchor[0]-_cfg.native_anchor[0],_cfg.anchor[1]-_cfg.native_anchor[1])
	_repair = _body(str(_cfg.repair_source))
	_palm = _body(str(_cfg.palm_source))
	for name: String in _cfg.poses:
		_render_pose(name,_cfg.poses[name])
	for clip: String in _cfg.clips:
		for frame: Dictionary in _cfg.clips[clip].frames:
			frame.path = str(_cfg.export_dir)+str(frame.pose)+".png"
	var output := FileAccess.open(CONFIG,FileAccess.WRITE)
	output.store_string(JSON.stringify(_cfg,"  ",false)+"\n")
	output.close()
	var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_presentation.json"))
	for clip: String in ["sword_1","sword_2","sword_3"]:
		var paths: Array = []
		var anchors: Array = []
		for frame: Dictionary in _cfg.clips[clip].frames:
			paths.append(frame.path)
			anchors.append(_cfg.anchor)
		combat.animations[clip].frame_paths = paths
		combat.animations[clip].anchors = anchors
		combat.animations[clip].fps = paths.size()/float(_cfg.clips[clip].duration)
	var file := FileAccess.open("res://data/combat_presentation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(combat,"  ",false)+"\n")
	file.close()
	print("NATIVE SWORD FRAMES: %d full-frame PNGs, original face/body pixels retained" % _cfg.poses.size())
	quit()


func _body(id: String) -> Image:
	if _body_cache.has(id):
		return _body_cache[id]
	var spec: Dictionary = _native.native_motion.frames[id]
	var raw := Image.load_from_file(ProjectSettings.globalize_path(spec.path))
	raw.convert(Image.FORMAT_RGBA8)
	var image := raw.get_region(Rect2i(spec.origin[0],spec.origin[1],64,64))
	for y in 64:
		for x in 64:
			var color := image.get_pixel(x,y)
			if color.b > color.r*1.015 and color.b > color.g*1.005:
				image.set_pixel(x,y,Color.TRANSPARENT)
	for region: Array in spec.masks:
		image.fill_rect(_rect(region),Color.TRANSPARENT)
	_body_cache[id] = image
	return image


func _render_pose(name: String, pose: Dictionary) -> void:
	var body := (_body(str(pose.source)).duplicate() as Image)
	var clear := _rect(_cfg.arm_clear)
	var protected := _rect(_cfg.protected_head)
	for y in range(clear.position.y,clear.end.y):
		for x in range(clear.position.x,clear.end.x):
			if not protected.has_point(Vector2i(x,y)) and body.get_pixel(x,y).a > 0:
				body.set_pixel(x,y,_repair.get_pixel(x,y))
	var step := int(pose.front_step)
	if step != 0:
		var region := _rect(_cfg.front_leg_rect)
		var leg := body.get_region(region)
		body.fill_rect(region,Color.TRANSPARENT)
		body.blend_rect(leg,Rect2i(Vector2i.ZERO,leg.get_size()),region.position+Vector2i(step,0))
	var image := Image.create(_cfg.canvas[0],_cfg.canvas[1],false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.blit_rect(body,Rect2i(0,0,64,64),_offset)
	_stroke(image,pose.back_stroke,true)
	var hand := _vec(pose.hand)
	var direction := Vector2.from_angle(deg_to_rad(float(pose.angle_degrees)))
	var grip := hand+direction*float(_native.sword.hand_to_guard)
	_sword(image,grip,direction)
	_stroke(image,pose.front_stroke,false)
	var rear_spacing := float(_cfg.get("rear_hand_spacing",4))
	_stamp_palm(image,hand-direction*rear_spacing)
	_stamp_palm(image,hand)
	# 原有头部像素置于持剑手臂前方，避免修帧改变眼睛、嘴部和头部轮廓。
	var original := _body(str(pose.source))
	for y in range(protected.position.y,protected.end.y):
		for x in range(protected.position.x,protected.end.x):
			var pixel := original.get_pixel(x,y)
			if pixel.a > 0:
				image.set_pixelv(Vector2i(x,y)+_offset,pixel)
	var path := str(_cfg.export_dir)+name+".png"
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("导出原版剑动作失败："+path)
	pose.path = path
	pose.grip = _array(grip)
	pose.tip = _array(grip+direction*float(_native.sword.length))
	pose.offhand = _array(hand-direction*rear_spacing)


func _stroke(image: Image, path: Array, rear: bool) -> void:
	for index in path.size()-1:
		var start := _vec(path[index])+Vector2(_offset)
		var finish := _vec(path[index+1])+Vector2(_offset)
		_line(image,start,finish,Color(_cfg.palette.outline),2)
		_line(image,start,finish,Color(_cfg.palette.shadow),1)
		_line(image,start+Vector2(-0.4,-0.7),finish+Vector2(-0.4,-0.7),Color(_cfg.palette.yellow).darkened(0.06 if rear else 0),1)
		_line(image,start+Vector2(-0.5,-1),finish+Vector2(-0.5,-1),Color(_cfg.palette.highlight).darkened(0.08 if rear else 0),0)


func _stamp_palm(image: Image, hand: Vector2) -> void:
	image.blend_rect(_palm,_rect(_cfg.palm_rect),Vector2i((hand+Vector2(_offset)).round())-Vector2i(2,2))


func _sword(image: Image, grip: Vector2, direction: Vector2) -> void:
	var s: Dictionary = _native.sword
	grip += Vector2(_offset)
	var n := Vector2(-direction.y,direction.x)
	var root := grip+direction*2
	var base := grip+direction*5
	var tip := grip+direction*float(s.length)
	_poly(image,[root-n*2,base-n*2,tip,base+n*2,root+n*2],Color(s.shadow))
	_poly(image,[root,base-n,tip,base+n],Color(s.steel))
	_line(image,root-n*2,tip,Color(s.edge),0)
	_line(image,grip-n*float(s.guard),grip+n*float(s.guard),Color(s.shadow),1)
	_line(image,grip-n*float(s.guard),grip+n*float(s.guard),Color(s.gold),0)
	_line(image,grip-direction*float(s.hilt),grip,Color(s.grip),1)
	image.fill_rect(Rect2i(Vector2i((grip-direction*(float(s.hilt)+1)).round())-Vector2i.ONE,Vector2i(3,3)),Color(s.gold))


func _line(image: Image, start: Vector2, finish: Vector2, color: Color, radius: int) -> void:
	var count := maxi(1,ceili(start.distance_to(finish)*2))
	for index in count+1:
		var point := Vector2i(start.lerp(finish,float(index)/count).round())
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if x*x+y*y <= radius*radius and Rect2i(Vector2i.ZERO,image.get_size()).has_point(point+Vector2i(x,y)):
					image.set_pixelv(point+Vector2i(x,y),color)


func _poly(image: Image, vertices: Array, color: Color) -> void:
	var points := PackedVector2Array(vertices)
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	for y in range(floori(bounds.position.y),ceili(bounds.end.y)+1):
		for x in range(floori(bounds.position.x),ceili(bounds.end.x)+1):
			if Rect2i(Vector2i.ZERO,image.get_size()).has_point(Vector2i(x,y)) and Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),points):
				image.set_pixel(x,y,color)


func _rect(values: Array) -> Rect2i:
	return Rect2i(values[0],values[1],values[2],values[3])


func _vec(values: Array) -> Vector2:
	return Vector2(values[0],values[1])


func _array(point: Vector2) -> Array:
	return [point.x,point.y]
