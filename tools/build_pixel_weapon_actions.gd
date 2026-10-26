extends SceneTree
## 以正式 64×64 闲置帧原始像素组装动作；禁止重画头身和改变像素密度。
var cfg: Dictionary
var base: Image
var palette: Dictionary


func _initialize() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_presentation.json")).pixel_actions
	base = Image.load_from_file(ProjectSettings.globalize_path(cfg.source))
	base.convert(Image.FORMAT_RGBA8)
	palette = cfg.palette
	for combo in cfg.sword.size():
		for frame in cfg.sword[combo].size():
			var pose: Dictionary = cfg.sword[combo][frame]
			var image := _body()
			var weapon := Image.create(64,64,false,Image.FORMAT_RGBA8)
			weapon.fill(Color.TRANSPARENT)
			_sword(weapon,_vec(pose.hand),_vec(pose.tip))
			_blend_weapon(image,weapon)
			_arm(image,_vec(pose.hand))
			_save(image,"sword_%d_%02d.png" % [combo+1,frame])
	for frame in cfg.bow_rear_hands.size():
		var image := _body()
		var weapon := Image.create(64,64,false,Image.FORMAT_RGBA8)
		weapon.fill(Color.TRANSPARENT)
		var rear := _vec(cfg.bow_rear_hands[frame])
		_bow(weapon,rear,frame)
		_blend_weapon(image,weapon)
		_arm(image,Vector2i(42,38))
		_arm(image,rear)
		_save(image,"bow_shot_%02d.png" % frame)
	print("Pixel actions: source idle retained, 20 frames, canvas64, anchor32/58, scale1")
	quit()


func _body() -> Image:
	var image := base.duplicate() as Image
	var r: Array = cfg.clear_hand
	# 仅恢复被原手掌覆盖的腹部小块，颜色仍取自同一行原图的腹部像素。
	for y in range(int(r[1]),int(r[1])+int(r[3])):
		for x in range(int(r[0]),int(r[0])+int(r[2])):
			image.set_pixel(x,y,base.get_pixel(int(r[0])+int(r[2])+1,y))
	return image


func _arm(image: Image, hand: Vector2i) -> void:
	var shoulder := _vec(cfg.shoulder)
	var elbow := Vector2i(roundi((shoulder.x+hand.x)/2.0),roundi((shoulder.y+hand.y)/2.0)+2)
	var outline := base.get_pixel(31,43)
	var yellow := base.get_pixel(28,35)
	_line(image,shoulder,elbow,outline,1)
	_line(image,elbow,hand,outline,1)
	_line(image,shoulder,elbow,yellow,0)
	_line(image,elbow,hand,yellow,0)
	# 手掌直接复制正式闲置帧，不重新生成人物像素。
	var r: Array = cfg.hand_source
	image.blend_rect(base,Rect2i(r[0],r[1],r[2],r[3]),hand-Vector2i(2,2))


func _sword(image: Image, hand: Vector2i, tip: Vector2i) -> void:
	var dir := Vector2(tip-hand).normalized()
	var start := hand+Vector2i(roundi(dir.x*4),roundi(dir.y*4))
	_line(image,start,tip,Color(palette.steel_edge),1)
	_line(image,start,tip,Color(palette.steel),0)
	var perpendicular := Vector2(-dir.y,dir.x)*3
	_line(image,hand+Vector2i(perpendicular),hand-Vector2i(perpendicular),Color(palette.grip),1)
	_line(image,hand-Vector2i(dir*3),hand+Vector2i(dir*2),Color(palette.wood),0)


func _bow(image: Image, rear: Vector2i, frame: int) -> void:
	var bow := PackedVector2Array([Vector2(44,22),Vector2(48,25),Vector2(50,31),Vector2(51,38),Vector2(50,45),Vector2(47,51),Vector2(44,54)])
	for index in bow.size()-1:
		_line(image,Vector2i(bow[index]),Vector2i(bow[index+1]),Color(palette.outline),1)
		_line(image,Vector2i(bow[index]),Vector2i(bow[index+1]),Color(palette.wood),0)
	var pull := rear if frame < 5 else Vector2i(44,38)
	_line(image,Vector2i(44,22),pull,Color(palette.string),0)
	_line(image,pull,Vector2i(44,54),Color(palette.string),0)
	if frame in [1,2,3,4]:
		_line(image,Vector2i(rear.x,38),Vector2i(60,38),Color(palette.wood),0)
		_line(image,Vector2i(58,36),Vector2i(61,38),Color(palette.steel),0)
		_line(image,Vector2i(58,40),Vector2i(61,38),Color(palette.steel),0)


func _blend_weapon(image: Image, weapon: Image) -> void:
	var region: Array = cfg.arm_region
	var arms := Rect2i(region[0],region[1],region[2],region[3])
	for y in image.get_height():
		for x in image.get_width():
			var color := weapon.get_pixel(x,y)
			if color.a > 0 and (base.get_pixel(x,y).a == 0 or arms.has_point(Vector2i(x,y))):
				image.set_pixel(x,y,color)


func _line(image: Image, start: Vector2i, finish: Vector2i, color: Color, radius: int) -> void:
	var distance := maxi(absi(finish.x-start.x),absi(finish.y-start.y))
	for step in distance+1:
		var point := Vector2(start).lerp(Vector2(finish),float(step)/maxi(1,distance)).round()
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				var pixel := Vector2i(point)+Vector2i(dx,dy)
				if Rect2i(0,0,64,64).has_point(pixel):
					image.set_pixelv(pixel,color)


func _vec(array: Array) -> Vector2i:
	return Vector2i(array[0],array[1])


func _save(image: Image, name: String) -> void:
	var path := "res://assets/PROCESSED/characters/CHR-01/rpg_v2/"+name
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Cannot save pixel action: "+name)
