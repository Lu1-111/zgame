class_name WeaponAppearance
extends RefCounted
## 武器类型决定战斗模组，外观ID只决定逐帧武器层；不提供战斗参数接口。
static var _config: Dictionary = {}
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

## 读取外观定义，和伤害、时序、碰撞表保持独立。
static func config() -> Dictionary:
	if _config.is_empty():
		_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_appearances.json"))
	return _config

## 获取动作身体、握点及各具体武器的同尺寸逐帧层。
static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest=JSON.parse_string(FileAccess.get_file_as_string(str(config().manifest)))
	return _manifest

## 装备表的appearance_id仅选外观；未接入或类型不匹配时显示握点占位。
static func equipped_id(weapon: Dictionary) -> String:
	var id := str(weapon.get("appearance_id",config().default))
	if not config().skins.has(id):return "placeholder"
	var model: Dictionary=config().skins[id]
	if model.has("weapon_type") and str(model.weapon_type)!=str(weapon.get("weapon_type","")):return "placeholder"
	return id

## 同索引组合人物身体与独立武器帧，无缩放、转动插值或动作重置。
static func frame_texture(animation: String, index: int, fallback: Texture2D, appearance: String) -> Texture2D:
	var definition: Dictionary=manifest().animations.get(animation,{})
	if definition.is_empty() or index>=definition.frames.size():return fallback
	var key := "%s/%d/%s" % [animation,index,appearance]
	if _textures.has(key):return _textures[key]
	var frame: Dictionary=definition.frames[index]
	var image := Image.load_from_file(ProjectSettings.globalize_path(str(frame.body)))
	if appearance=="placeholder" or not frame.skins.has(appearance):
		var point: Array=frame.socket.position
		var marker: Dictionary=config().placeholder
		for delta in range(-int(marker.radius),int(marker.radius)+1):
			for pixel in [Vector2i(roundi(point[0])+delta,roundi(point[1])),Vector2i(roundi(point[0]),roundi(point[1])+delta)]:
				if Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel):image.set_pixelv(pixel,Color(str(marker.color)))
	else:
		var skin: Dictionary=frame.skins[appearance]
		var weapon := Image.load_from_file(ProjectSettings.globalize_path(str(skin.weapon)))
		if weapon.get_size()!=image.get_size():return fallback
		# 图层已按握点和遮挡离线对齐，运行时只按像素覆盖，保留原生alpha。
		for y in weapon.get_height():
			for x in weapon.get_width():
				var color := weapon.get_pixel(x,y)
				if color.a>0:image.set_pixel(x,y,color)
		var fingers := Image.load_from_file(ProjectSettings.globalize_path(str(frame.foreground)))
		for y in fingers.get_height():
			for x in fingers.get_width():
				var color := fingers.get_pixel(x,y)
				if color.a>0:image.set_pixel(x,y,color)
	var texture := ImageTexture.create_from_image(image)
	_textures[key]=texture
	return texture

## 更新独占SpriteFrames的外观缓存，保留动画时间、帧号、帧时长及播放状态。
static func sync_sprite(sprite: AnimatedSprite2D, appearance: String) -> void:
	var signature := appearance+"/"+str(sprite.sprite_frames.get_animation_names().size())
	if sprite.get_meta("weapon_appearance","")==signature:return
	sprite.set_meta("weapon_appearance",signature)
	for name: String in manifest().animations:
		if not sprite.sprite_frames.has_animation(name):continue
		var frames: Array=manifest().animations[name].frames
		for index in mini(frames.size(),sprite.sprite_frames.get_frame_count(name)):
			var source := sprite.sprite_frames.get_frame_texture(name,index)
			sprite.sprite_frames.set_frame(name,index,frame_texture(name,index,source,appearance),sprite.sprite_frames.get_frame_duration(name,index))

## 从独立模型表绘制枪械；原动作握点、枪口和弹道计算不读取此表。
static func draw_rifle(canvas: Node2D, grip: Vector2, direction: Vector2, appearance: String, origin: Vector2 = Vector2.ZERO) -> void:
	var normal := Vector2(-direction.y,direction.x)
	if appearance=="placeholder":
		var marker: Dictionary=config().placeholder
		canvas.draw_line((grip-direction*float(marker.radius)).round(),(grip+direction*float(marker.radius)).round(),Color(str(marker.color)),1,false)
		canvas.draw_line((grip-normal*float(marker.radius)).round(),(grip+normal*float(marker.radius)).round(),Color(str(marker.color)),1,false)
		return
	var skin: Dictionary=config().skins.get(appearance,{})
	if skin.has("rifle_texture"):
		var spec: Dictionary=skin.rifle_texture
		var path := str(spec.texture)
		if not _textures.has(path):_textures[path]=load(path)
		canvas.draw_set_transform(grip-origin,direction.angle()-deg_to_rad(float(spec.get("source_angle_degrees",0))))
		canvas.draw_texture(_textures[path],-Vector2(spec.grip[0],spec.grip[1]))
		canvas.draw_set_transform(-origin)
		return
	var model: Dictionary=config().rifle_model
	var palette: Dictionary=model.palette.duplicate()
	palette.merge(config().skins.get(appearance,{}).get("rifle",{}),true)
	for primitive: Dictionary in model.primitives:
		var points := PackedVector2Array()
		for point: Array in primitive.points:points.append((grip+direction*float(point[0])+normal*float(point[1])).round())
		if primitive.kind=="polygon":canvas.draw_colored_polygon(points,Color(str(palette[primitive.color])))
		else:canvas.draw_line(points[0],points[1],Color(str(palette[primitive.color])),float(primitive.width),false)
