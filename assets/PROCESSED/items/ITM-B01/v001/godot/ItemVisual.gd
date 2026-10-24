extends Node2D
## 仅展示世界道具与拾取反馈；调用方负责碰撞、库存及奖励结算。

signal pickup_visual_finished(item_id: StringName)

const CATALOG = preload("ItemCatalog.gd")

@export var item_id: StringName = &"potion_small"
@export var bob_enabled: bool = true
@export var playback_rate: float = 1.0

@onready var _visual: Node2D = $VisualRoot
@onready var _sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

var _elapsed: float = 0.0
var _pickup_elapsed: float = 0.0
var _pickup_start_y: float = 0.0
var _collecting: bool = false
var _collected: bool = false
var _paused: bool = false


func _ready() -> void:
	_sprite.sprite_frames = CATALOG.FRAMES
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not set_item(item_id):
		hide()


func _process(delta: float) -> void:
	_sprite.speed_scale = maxf(playback_rate, 0.0)
	if _paused or _collected or playback_rate <= 0.0:
		return
	_elapsed += delta * playback_rate
	if _collecting:
		_pickup_elapsed += delta * playback_rate
		var duration: float = float(CATALOG.DEFAULTS["pickupDuration"])
		var progress: float = clampf(_pickup_elapsed / duration, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, float(CATALOG.DEFAULTS["pickupEasePower"]))
		_visual.position.y = _pickup_start_y - float(CATALOG.DEFAULTS["pickupRise"]) * eased
		_visual.modulate.a = 1.0 - progress
		if progress >= 1.0:
			_collecting = false
			_collected = true
			_sprite.pause()
			hide()
			pickup_visual_finished.emit(item_id)
	else:
		var bob: float = sin(_elapsed * TAU / float(CATALOG.DEFAULTS["bobPeriod"])) * float(CATALOG.DEFAULTS["bobAmplitude"]) if bob_enabled else 0.0
		_visual.position.y = -float(CATALOG.DEFAULTS["baseLift"]) - bob


## 切换数据表中的道具 ID 并从首帧重播；未知 ID 不改变当前展示。
func set_item(value: StringName) -> bool:
	if not is_node_ready() or not CATALOG.ITEMS.has(value):
		return false
	item_id = value
	_sprite.animation = value
	var anchor: Vector2 = CATALOG.ITEMS[value]["anchor"]
	_sprite.offset = -anchor
	_sprite.flip_h = false
	reset_visual()
	return true


## 返回当前道具的24像素UI贴图，可直接赋给TextureRect。
func get_icon() -> Texture2D:
	if not CATALOG.ITEMS.has(item_id):
		return null
	return CATALOG.ITEMS[item_id]["icon"] as Texture2D


## 从当前帧进入拾取淡出；重复触发会返回false，防止重复完成通知。
func play_pickup() -> bool:
	if not is_node_ready() or not CATALOG.ITEMS.has(item_id) or _collecting or _collected:
		return false
	_collecting = true
	_pickup_elapsed = 0.0
	_pickup_start_y = _visual.position.y
	return true


## 恢复首帧、浮动相位及透明度，方便对象池复用。
func reset_visual() -> void:
	if not is_node_ready() or not CATALOG.ITEMS.has(item_id):
		return
	_elapsed = 0.0
	_pickup_elapsed = 0.0
	_collecting = false
	_collected = false
	_visual.position = Vector2(0.0, -float(CATALOG.DEFAULTS["baseLift"]))
	_visual.modulate = Color.WHITE
	_sprite.stop()
	_sprite.animation = item_id
	_sprite.set_frame_and_progress(0, 0.0)
	_sprite.speed_scale = maxf(playback_rate, 0.0)
	if not _paused:
		_sprite.play()
	show()


## 同时暂停精灵帧、浮动与拾取计时；恢复后沿用原相位。
func set_visual_paused(value: bool) -> void:
	_paused = value
	if not is_node_ready():
		return
	if _paused:
		_sprite.pause()
	elif not _collected:
		_sprite.play()
