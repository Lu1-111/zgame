class_name CombatEnemyVisual
extends Node2D
## 以资源包清单驱动敌人表现；共同语义根负责镜像，画布留白不影响落点。
signal action_completed(action: StringName)
var body := AnimatedSprite2D.new()
var effect := AnimatedSprite2D.new()
var entries: Dictionary = {}
var effects: Dictionary = {}
var current: Dictionary = {}
var effect_current: Dictionary = {}
var action: StringName = &""
var facing := 1.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.centered = false
	effect.centered = false
	add_child(body)
	add_child(effect)
	body.animation_finished.connect(_completed)
	effect.animation_finished.connect(effect.hide)
	effect.hide()

## 读取游戏编号对应的全动作；B03 catalog 与既有 SpriteFrames 资源使用同一语义根。
func configure(game_id: StringName, paths: Array, aliases: Dictionary, visual_scale: float, _resources: Dictionary = {}) -> bool:
	entries.clear()
	effects.clear()
	var wanted := str(aliases.get(String(game_id), String(game_id)))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var fx_frames := SpriteFrames.new()
	fx_frames.remove_animation(&"default")
	for catalog_path: String in paths:
		if not FileAccess.file_exists(catalog_path):
			continue
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if not catalog is Dictionary:
			continue
		for raw: Dictionary in catalog.get("effects", []):
			if str(raw.get("gameEnemyId", "")) not in [wanted, String(game_id)] and str(raw.get("enemyId", "")) not in [wanted, String(game_id)]:
				continue
			var entry: Dictionary = raw.duplicate(true)
			var name := StringName(str(entry.name))
			var target_frames := frames if entry.get("kind", "body") == "body" else fx_frames
			if target_frames.has_animation(name):
				target_frames.remove_animation(name)
			target_frames.add_animation(name)
			target_frames.set_animation_speed(name, float(entry.fps))
			target_frames.set_animation_loop(name, bool(entry.get("loop", false)))
			for relative: String in entry.frames:
				var path := catalog_path.get_base_dir().path_join(relative)
				if ResourceLoader.exists(path):
					target_frames.add_frame(name, load(path))
			if entry.get("kind", "body") == "body":
				entries[name] = entry
			else:
				effects[StringName(str(entry.get("triggerAction", "attack")))] = entry
	body.sprite_frames = frames
	effect.sprite_frames = fx_frames
	scale = Vector2.ONE * visual_scale
	return play_action(&"idle", false)

## 同动作不重复复位；一次性动作按游戏状态窗口等比播放完整帧序列。
func play_action(value: StringName, left: bool, duration: float = 0.0) -> bool:
	facing = -1.0 if left else 1.0
	scale.x = absf(scale.x) * facing
	if action == value:
		return entries.has(value)
	action = value
	if not entries.has(value):
		current = {}
		body.stop()
		body.hide()
		if value != &"recover":
			effect.stop()
			effect.hide()
		return false
	body.show()
	current = entries[value]
	body.offset = -Vector2(current.anchor[0], current.anchor[1])
	body.modulate.a = 1.0
	body.stop()
	body.speed_scale = 1.0
	if duration > 0.0:
		body.speed_scale = float(current.get("frame_count", current.get("frames", []).size())) / float(current.fps) / duration
	body.play(value)
	if value != &"recover":
		effect.stop()
		effect.hide()
	if effects.has(value):
		effect_current = effects[value]
		effect.offset = -Vector2(effect_current.anchor[0], effect_current.anchor[1])
		var offset: Array = effect_current.get("triggerOffset", [0, 0])
		effect.position = Vector2(offset[0], offset[1])
		effect.modulate.a = 1.0
		effect.stop()
		effect.show()
		effect.play(StringName(str(effect_current.name)))
	return true

func _process(_delta: float) -> void:
	_fade(body, current)
	if effect.visible:
		_fade(effect, effect_current)

func _fade(sprite: AnimatedSprite2D, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var fade_start := float(entry.get("fadeStartNormalized", 1.0))
	if fade_start < 1.0:
		var frame_count := int(entry.get("frame_count", entry.get("frames", []).size()))
		if frame_count > 0:
			var progress := (sprite.frame + sprite.frame_progress) / float(frame_count)
			sprite.modulate.a = 1.0 - smoothstep(fade_start, 1.0, progress)

func _completed() -> void:
	if current.is_empty():
		return
	var completed := StringName(str(current.name))
	if completed == &"death":
		body.modulate.a = 0.0
	action_completed.emit(completed)
