class_name WorldNPC
extends Node2D
## 可复用 NPC：短距离巡逻、玩家靠近提示、E 键对话与 idle/walk/talk 动画切换。

@export var npc_id: StringName = &"NPC"
@export var display_name: String = "NPC"
@export var dialogue: PackedStringArray = PackedStringArray()
@export var frames: SpriteFrames
@export_range(0.0, 96.0, 1.0) var patrol_radius := 24.0
@export_range(0.0, 60.0, 1.0) var walk_speed := 12.0
@export_range(8.0, 64.0, 1.0) var interact_radius := 42.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt
var _player: Node2D

enum Mode { WAIT, WALK, TALK }

var _home_x := 0.0
var _direction := 1.0
var _mode := Mode.WAIT
var _wait_left := 0.6
var _player_near := false
var _line_index := -1


func _ready() -> void:
	add_to_group(&"npc")
	_home_x = position.x
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	sprite.centered = false
	sprite.offset = Vector2(-32, -58)
	if frames:
		sprite.sprite_frames = frames
	else:
		push_warning("NPC %s has no SpriteFrames" % npc_id)
	sprite.play(&"idle")
	prompt.visible = false


func _process(delta: float) -> void:
	_update_nearby()
	if _mode == Mode.TALK:
		return
	if _player_near:
		prompt.visible = true
		if _mode != Mode.WAIT:
			_mode = Mode.WAIT
			sprite.play(&"idle")
		return
	prompt.visible = false
	if patrol_radius <= 0.0:
		if _mode != Mode.WAIT:
			_mode = Mode.WAIT
			sprite.play(&"idle")
		return
	if _mode == Mode.WAIT:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_mode = Mode.WALK
			sprite.flip_h = _direction < 0.0
			sprite.play(&"walk")
		return
	if _mode == Mode.WALK:
		position.x += _direction * walk_speed * delta
		if position.x >= _home_x + patrol_radius:
			position.x = _home_x + patrol_radius
			_face_and_wait()
		elif position.x <= _home_x - patrol_radius:
			position.x = _home_x - patrol_radius
			_face_and_wait()


func _update_nearby() -> void:
	var was_near := _player_near
	_player_near = _player != null and global_position.distance_to(_player.global_position) <= interact_radius
	if _player_near == was_near:
		return
	if _player_near:
		prompt.visible = true
		if _mode != Mode.TALK:
			_mode = Mode.WAIT
			_wait_left = 0.3
			sprite.play(&"idle")
	elif _mode == Mode.TALK:
		_close_dialogue()
	elif patrol_radius > 0.0:
		_mode = Mode.WAIT
		_wait_left = 0.3
		sprite.play(&"idle")


func _face_and_wait() -> void:
	_direction *= -1.0
	_mode = Mode.WAIT
	_wait_left = 0.55
	sprite.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact"):
		return
	if not _player_near:
		return
	if _mode == Mode.TALK:
		_advance_dialogue()
	else:
		_open_dialogue()
	get_viewport().set_input_as_handled()


func _open_dialogue() -> void:
	if dialogue.is_empty():
		return
	var ui := get_tree().get_first_node_in_group(&"npc_dialogue")
	if ui == null or not ui.has_method("show_line"):
		push_warning("No NPC dialogue UI found")
		return
	_mode = Mode.TALK
	_line_index = 0
	prompt.visible = false
	sprite.play(&"talk")
	ui.show_line(display_name, dialogue[0], 1, dialogue.size())


func _advance_dialogue() -> void:
	if _mode != Mode.TALK:
		return
	_line_index += 1
	var ui := get_tree().get_first_node_in_group(&"npc_dialogue")
	if _line_index >= dialogue.size():
		_close_dialogue()
		return
	if ui:
		ui.show_line(display_name, dialogue[_line_index], _line_index + 1, dialogue.size())


func _close_dialogue() -> void:
	_line_index = -1
	_mode = Mode.WAIT
	_wait_left = 0.35
	sprite.play(&"idle")
	var ui := get_tree().get_first_node_in_group(&"npc_dialogue")
	if ui and ui.has_method("close_dialogue"):
		ui.close_dialogue()
	prompt.visible = _player_near
