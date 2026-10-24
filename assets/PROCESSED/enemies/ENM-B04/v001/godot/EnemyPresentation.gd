extends Node2D
## 视觉播放组件；动作时长不控制伤害、位移或命中窗口。
signal action_completed(action: StringName)
const CATALOG = preload("Catalog.gd")
@export var enemy_id: String = "ENM-02"
@export var action_mapping: Dictionary = {}
var facing_left: bool = false
var current: Dictionary = {}
var fx_current: Dictionary = {}
@onready var root: Node2D = $VisualRoot
@onready var body: AnimatedSprite2D = $VisualRoot/Body
@onready var fx: AnimatedSprite2D = $VisualRoot/FX

func _ready() -> void:
	body.animation_finished.connect(_finished)
	fx.animation_finished.connect(func() -> void: fx.hide())
	select_enemy(enemy_id)

## 可按素材编号或实际游戏敌人编号选择表现。
func select_enemy(value: String) -> bool:
	for entry: Dictionary in CATALOG.ENTRIES:
		if entry.kind == "body" and (entry.enemyId == value or entry.gameEnemyId == value):
			enemy_id = entry.enemyId
			body.sprite_frames = load(get_script().resource_path.get_base_dir().path_join(enemy_id + ".tres"))
			fx.hide()
			return play_action(&"idle")
	return false

## 重复触发始终重播，镜像围绕共同根节点，不翻转画布中心。
func play_action(action: StringName, left: bool = false, rate: float = 1.0) -> bool:
	if rate <= 0.0:
		return false
	var mapped: String = str(action_mapping.get(action, action))
	current = {}
	for entry: Dictionary in CATALOG.ENTRIES:
		if entry.kind == "body" and entry.enemyId == enemy_id and entry.name == mapped:
			current = entry
	if current.is_empty():
		if mapped != "idle":
			return play_action(&"idle", left, rate)
		return false
	facing_left = left
	root.scale.x = -1.0 if left else 1.0
	body.centered = false
	body.offset = -Vector2(current.anchor[0], current.anchor[1])
	body.modulate.a = 1.0
	body.stop()
	body.speed_scale = rate
	body.animation = mapped
	body.set_frame_and_progress(0, 0.0)
	body.play()
	# 收招继承攻击特效尾段，直到特效自然完成；新动作可明确打断。
	if mapped != "recover":
		fx.stop()
		fx.hide()
	for entry: Dictionary in CATALOG.ENTRIES:
		if entry.kind == "effect" and entry.enemyId == enemy_id and entry.get("triggerAction", "attack") == mapped:
			fx_current = entry
			fx.sprite_frames = load(get_script().resource_path.get_base_dir().path_join(entry.id + ".tres"))
			fx.centered = false
			fx.offset = -Vector2(entry.anchor[0], entry.anchor[1])
			var trigger_offset: Array = entry.get("triggerOffset", [0, 0])
			fx.position = Vector2(trigger_offset[0], trigger_offset[1])
			fx.stop()
			fx.animation = entry.name
			fx.speed_scale = rate
			fx.set_frame_and_progress(0, 0.0)
			fx.modulate.a = 1.0
			fx.show()
			fx.play()
	return true

func _process(_delta: float) -> void:
	_fade(body, current)
	if fx.visible:
		_fade(fx, fx_current)

func _fade(sprite: AnimatedSprite2D, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var start: float = float(entry.get("fadeStartNormalized", 1.0))
	if start < 1.0:
		var progress: float = (sprite.frame + sprite.frame_progress) / float(entry.frameCount)
		sprite.modulate.a = 1.0 - smoothstep(start, 1.0, progress)

func _finished() -> void:
	if current.get("name", "") == "death":
		body.modulate.a = 0.0
	action_completed.emit(StringName(current.get("name", "")))
