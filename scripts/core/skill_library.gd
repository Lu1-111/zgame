class_name SkillLibrary
extends RefCounted
## 十二技能素材索引：按清单读取原生逐帧、独立特效与各自锚点，按需缓存。
static var _presentation: Dictionary = {}
static var _runtime: Dictionary = {}
static var _aliases: Dictionary = {}
static var _ids: Dictionary = {}
static var _textures: Dictionary = {}

## 获取素材清单，避免启动时解码全部技能特效。
static func presentation() -> Dictionary:
	if _presentation.is_empty():
		_presentation = JSON.parse_string(FileAccess.get_file_as_string("res://data/skill_presentations.json"))
	return _presentation

## 获取指定技能的玩法时序，临时数值也统一由数据表提供。
static func runtime(id: StringName) -> Dictionary:
	if _runtime.is_empty():
		_runtime = JSON.parse_string(FileAccess.get_file_as_string("res://data/skill_runtime.json"))
	return _runtime.skills.get(str(canonical(id)),{})

## 旧技能 ID 仅用于存档和旧奖励兼容；技能库只展示正式十二招。
static func canonical(id: StringName) -> StringName:
	if _aliases.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
		_aliases = data.legacy_aliases
		for row: Dictionary in data.skills:
			_ids[str(row.id)] = true
	return StringName(_aliases.get(str(id),str(id)))

## 获取一组逐帧的元数据。
static func animation(id: String) -> Dictionary:
	return presentation().animations.get(id,{})

## 原图按路径缓存，不缩放、不重新绘制像素。
static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]

## 仅在首次施放时将所需动作注入现有角色精灵。
static func ensure_actor(frames: SpriteFrames, id: StringName) -> void:
	if frames.has_animation(id):
		return
	var cfg := animation(str(id))
	if cfg.is_empty():
		return
	frames.add_animation(id)
	frames.set_animation_speed(id,float(cfg.fps))
	frames.set_animation_loop(id,bool(cfg.loop))
	for path: String in cfg.frames:
		frames.add_frame(id,texture(path))

## 技能逐帧脚底各读各自锚点，与普通攻击共用同一人物尺寸。
static func sync_actor(sprite: AnimatedSprite2D) -> bool:
	var cfg := animation(str(sprite.animation))
	if cfg.is_empty() or str(cfg.kind) != "actor":
		return false
	var root: Array = cfg.root
	sprite.offset = -Vector2(root[0],root[1])
	sprite.scale = Vector2.ONE
	return true

## 保留槽位顺序迁移旧档，并清除映射后重复和失效的技能。
static func migrate_state(state: Node) -> void:
	for collection: Array in [state.get("learned_skills"),state.get("equipped_skills")]:
		var seen := {}
		for index in collection.size():
			var id := canonical(StringName(collection[index]))
			if not _ids.has(str(id)) or seen.has(id):
				id = &""
			collection[index] = id
			if id != &"":
				seen[id] = true
	while state.get("learned_skills").has(&""):
		state.get("learned_skills").erase(&"")
