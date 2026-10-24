extends Node2D
## 只播放视觉反馈的可复用组件；攻击、伤害和无敌时长由调用方决定。

signal effect_completed(effect_name: StringName)

const GENERATED_CATALOG = preload("EffectCatalog.gd")

@export_file("*.json") var manifest_path: String = ""
@export var speed_multiplier: float = 1.0
@export var hide_on_finish: bool = true

@onready var _visual_root: Node2D = $VisualRoot
@onready var _sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

var _effects: Dictionary = {}
var _active_effect: StringName = &""


func _ready() -> void:
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.animation_finished.connect(_on_animation_finished)
	_load_manifest()
	hide()


func _process(_delta: float) -> void:
	if _active_effect != &"":
		_update_visual_alpha()


## 淡出只读取真实帧时长与帧内进度；暂停、倍率和重复触发不会与独立计时器漂移。
func _update_visual_alpha() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	var item: Dictionary = _effects.get(_active_effect, {})
	var opacity: Array = item.get("opacityByFrame", [])
	if opacity.is_empty():
		_sprite.modulate.a = 1.0
	else:
		var current_index: int = mini(_sprite.frame, opacity.size() - 1)
		var next_index: int = mini(current_index + 1, opacity.size() - 1)
		if frames.get_animation_loop(_sprite.animation):
			next_index = (current_index + 1) % opacity.size()
		_sprite.modulate.a = lerpf(float(opacity[current_index]), float(opacity[next_index]), smoothstep(0.0, 1.0, _sprite.frame_progress))
	if frames.get_animation_loop(_sprite.animation):
		_visual_root.modulate.a = 1.0
		return
	var fade_start: float = float(item.get("fadeStartNormalized", 1.0))
	if fade_start >= 1.0:
		_visual_root.modulate.a = 1.0
		return
	var total_duration: float = 0.0
	var elapsed_duration: float = 0.0
	for frame_index: int in range(frames.get_frame_count(_sprite.animation)):
		var duration: float = frames.get_frame_duration(_sprite.animation, frame_index)
		total_duration += duration
		if frame_index < _sprite.frame:
			elapsed_duration += duration
		elif frame_index == _sprite.frame:
			elapsed_duration += duration * _sprite.frame_progress
	var lifetime: float = clampf(elapsed_duration / total_duration, 0.0, 1.0) if total_duration > 0.0 else 0.0
	_visual_root.modulate.a = 1.0 - smoothstep(fade_start, 1.0, lifetime)


## 默认使用随资源预载的生成目录；可指定 manifest 路径进行运行时覆写。
func _load_manifest() -> void:
	_effects = GENERATED_CATALOG.EFFECTS.duplicate(true)
	if manifest_path.is_empty():
		return
	var resolved_path: String = manifest_path
	if not FileAccess.file_exists(resolved_path):
		push_warning("EffectPlayer manifest 不存在：" + resolved_path)
		return
	var json: JSON = JSON.new()
	var result: Error = json.parse(FileAccess.get_file_as_string(resolved_path))
	if result != OK or not json.data is Dictionary:
		push_warning("EffectPlayer manifest 解析失败：" + resolved_path)
		return
	var document: Dictionary = json.data
	for value: Variant in document.get("effects", []):
		if value is Dictionary:
			var item: Dictionary = value
			_effects[StringName(str(item.get("name", "")))] = item


## 从首帧触发视觉特效；同一动作重复调用也会重播，不推导任何游戏判定窗口。
func play_effect(effect_name: StringName, facing_left: bool = false, playback_rate: float = 1.0) -> bool:
	if not is_node_ready():
		return false
	if not _effects.has(effect_name) or not _sprite.sprite_frames.has_animation(effect_name):
		push_warning("EffectPlayer 未知动作：" + str(effect_name))
		return false
	if speed_multiplier <= 0.0 or playback_rate <= 0.0:
		push_warning("EffectPlayer 播放倍率必须大于零")
		return false
	var item: Dictionary = _effects[effect_name]
	var root: Array = item.get("anchor", [0, 0])
	_sprite.stop()
	_sprite.animation = effect_name
	_sprite.offset = -Vector2(float(root[0]), float(root[1]))
	_sprite.centered = false
	_sprite.flip_h = false
	# 镜像整个视觉子节点，保持 root 原点；不围绕像素画布中心翻转。
	_visual_root.scale = Vector2(-1.0 if facing_left else 1.0, 1.0)
	_visual_root.modulate.a = 1.0
	_sprite.speed_scale = speed_multiplier * playback_rate
	_sprite.set_frame_and_progress(0, 0.0)
	_active_effect = effect_name
	show()
	_sprite.play(effect_name)
	_update_visual_alpha()
	return true


## 附着到调用方提供的 Marker2D/Node2D，再从其局部原点播放；沿用父节点变换。
func play_attached(marker: Node2D, effect_name: StringName, facing_left: bool = false, playback_rate: float = 1.0) -> bool:
	if not is_instance_valid(marker) or marker == self or is_ancestor_of(marker):
		return false
	if not is_node_ready() or not _effects.has(effect_name):
		return false
	if get_parent() != marker:
		reparent(marker, false)
	position = Vector2.ZERO
	rotation = 0.0
	return play_effect(effect_name, facing_left, playback_rate)


## 停止并隐藏当前特效，保留节点供下次复用；不发出自然播放完成信号。
func stop_effect() -> void:
	if is_node_ready():
		_sprite.stop()
		_visual_root.modulate.a = 1.0
		_sprite.modulate.a = 1.0
	_active_effect = &""
	hide()


func _on_animation_finished() -> void:
	var completed: StringName = _active_effect
	var item: Dictionary = _effects.get(completed, {})
	if float(item.get("fadeStartNormalized", 1.0)) < 1.0:
		_visual_root.modulate.a = 0.0
	_active_effect = &""
	if hide_on_finish:
		hide()
	effect_completed.emit(completed)
