class_name WeaponRuntime
extends RefCounted
## 武器动作、逐帧脚底锚点与独立特效的表现配置。
static var _data := {}


## 读取四种普攻模组的时序与挂点。
static func config() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_presentation.json"))
	return _data


## 按武器类别查询动作与判定时序。
static func module(kind: String) -> Dictionary:
	return config().weapon_modules.get(kind,{})


## 非破坏读取新直剑/步枪图集，补充到角色精灵帧。
static func inject_animations(frames: SpriteFrames) -> void:
	for name: String in config().animations:
		var definition: Dictionary = config().animations[name]
		if frames.has_animation(StringName(name)):
			continue
		frames.add_animation(StringName(name))
		frames.set_animation_speed(StringName(name),float(definition.fps))
		frames.set_animation_loop(StringName(name),false)
		for path: String in definition.frame_paths:
			frames.add_frame(StringName(name),load(path))


## 同步新动作每一帧的实际脚底与人物比例；旧动作仍用正式包锚点。
static func sync_sprite(sprite: AnimatedSprite2D) -> void:
	var definition: Dictionary = config().animations.get(str(sprite.animation),{})
	if definition.is_empty():
		sprite.scale = Vector2.ONE
		return
	var root: Array = definition.anchors[mini(sprite.frame,definition.anchors.size()-1)]
	sprite.offset = -Vector2(root[0],root[1])
	sprite.scale = Vector2.ONE * float(definition.scale)


## 读取生成的武器特效帧；UI 与投射物不改变源图。
static func effect_frames(kind: String, loop: bool = false) -> SpriteFrames:
	if config().independent_fx.has(kind):
		var item: Dictionary = config().independent_fx[kind]
		var frames := SpriteFrames.new()
		frames.set_animation_loop(&"default",loop)
		frames.set_animation_speed(&"default",float(item.fps))
		var source: Texture2D = load(str(item.texture))
		var cell := source.get_size()/Vector2(item.grid[0],item.grid[1])
		for index in int(item.frames):
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			atlas.region = Rect2(Vector2(index%int(item.grid[0]),floorf(float(index)/float(item.grid[0])))*cell,cell)
			atlas.filter_clip = true
			frames.add_frame(&"default",atlas)
		return frames
	var cfg: Dictionary = config().fx
	var row: Dictionary = cfg.rows.get(kind,cfg.rows.staff)
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default",loop)
	frames.set_animation_speed(&"default",float(cfg.fps))
	var texture := load(cfg.texture) as Texture2D
	for index in row.xs.size()-1:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(row.xs[index],row.y,float(row.xs[index+1])-float(row.xs[index]),row.h)
		atlas.filter_clip = true
		frames.add_frame(&"default",atlas)
	return frames


## 返回特效在世界中的缩放比例。
static func effect_scale(kind: String) -> Vector2:
	if config().independent_fx.has(kind):
		var item: Dictionary = config().independent_fx[kind]
		var source: Texture2D = load(str(item.texture))
		var cell := source.get_size()/Vector2(item.grid[0],item.grid[1])
		return Vector2(item.world_size[0]/cell.x,item.world_size[1]/cell.y)
	var row: Dictionary = config().fx.rows[kind]
	return Vector2(row.world_size[0]/(float(config().fx.source_size[0])/float(config().fx.columns)),row.world_size[1]/float(row.h))
