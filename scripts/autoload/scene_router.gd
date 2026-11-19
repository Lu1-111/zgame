extends Node
## SceneRouter —— 场景 / 房间切换路由（autoload 单例）
## 黑场转场：淡出 0.15s → 切房间 → 落在目标门内侧 → 停留 0.10s → 淡入 0.15s（合计 0.40s）。
## 参考书 §3.11：切房后玩家对齐目标门（误差 ≤ 4px）；进房自动存档待接 SaveSystem。

const ROOM_DIR := "res://scenes/maps/"
const ARRIVE_DEFAULT := Vector2(40, -9)

const FADE_OUT := 0.10
const FADE_HOLD := 0.05
const FADE_IN := 0.10

var _pending_door: StringName = &""
var _busy := false
var _fade_rect: ColorRect
var _checkpoint_arrival: Dictionary = {}


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TransitionLayer"
	layer.layer = 128                     # 盖在所有游戏内容之上
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 目标房间的场景路径。
func room_path(room_id: StringName) -> String:
	return "%s%s.tscn" % [ROOM_DIR, String(room_id)]


## 目标房间是否存在（供门组件预先判断）。
func can_goto(room_id: StringName) -> bool:
	return room_id != &"" and ResourceLoader.exists(room_path(room_id))


## 当前黑场不透明度（0=透明，1=全黑）；供测试与调试用。
func fade_alpha() -> float:
	return _fade_rect.color.a if _fade_rect != null else 0.0


## 是否正在转场。
func is_transitioning() -> bool:
	return _busy


## 切换到目标房间，并从指定门出生（door_id 为空则用房间默认 Player 位置）。
## 立即返回是否接受本次切换；淡入淡出与落点在内部异步完成。
func goto_room(room_id: StringName, door_id: StringName = &"") -> bool:
	if not can_goto(room_id):
		return false
	if _busy:
		return true
	_busy = true
	_pending_door = door_id
	_transition(room_id, door_id)
	return true


## 由已解锁篝火发起黑场旅行；落点、复活点和自动存档在转场内统一更新。
func goto_checkpoint(room_id: StringName, checkpoint: StringName, position: Vector2) -> bool:
	if _busy or not can_goto(room_id) or not CampfireService.is_unlocked(room_id,checkpoint):
		return false
	_checkpoint_arrival = {"room":room_id,"checkpoint":checkpoint,"position":position}
	SaveSystem.restoring = false
	return goto_room(room_id)


func change_scene(path: String) -> void:
	## 切换到任意场景（res:// 路径）；供调试与测试宿主使用
	get_tree().change_scene_to_file(path)


func _transition(room_id: StringName, door_id: StringName) -> void:
	await _fade_to(1.0, FADE_OUT)
	await get_tree().process_frame

	# 同房间火点旅行保留遭遇状态，避免用点击当前篝火代替“休息”刷新敌人。
	var same_room_fire := not _checkpoint_arrival.is_empty() and GameState.current_room == room_id and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == room_path(room_id)
	var err := OK if same_room_fire else get_tree().change_scene_to_file(room_path(room_id))
	if err != OK:
		_checkpoint_arrival.clear()
		push_error("SceneRouter: 切场景失败 %s (err=%d)" % [room_path(room_id), err])
		await _fade_to(0.0, FADE_IN)
		_busy = false
		return

	GameState.current_room = room_id
	if not GameState.visited_rooms.has(room_id):
		GameState.visited_rooms.append(room_id)

	await get_tree().process_frame
	await get_tree().process_frame
	_place_player_at_door(door_id)
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody2D
	if not _checkpoint_arrival.is_empty() and player != null:
		player.position = _checkpoint_arrival.position
		player.velocity = Vector2.ZERO
		player.set("checkpoint_position",player.position)
		GameState.checkpoint_id = _checkpoint_arrival.checkpoint
		GameState.checkpoint_room = room_id
		GameState.checkpoint_position = [player.position.x,player.position.y]
		_checkpoint_arrival.clear()
	if SaveSystem.restoring and player != null and GameState.saved_position.size() == 2:
		player.position = Vector2(GameState.saved_position[0],GameState.saved_position[1])
		player.velocity = Vector2.ZERO
		SaveSystem.restoring = false

	await get_tree().create_timer(FADE_HOLD).timeout
	await _fade_to(0.0, FADE_IN)
	_busy = false
	EventBus.room_entered.emit(room_id)
	SaveSystem.save_game()


func _fade_to(alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await tween.finished


func _place_player_at_door(door_id: StringName) -> void:
	if door_id == &"":
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var door := scene.get_node_or_null(String(door_id))
	if door == null:
		push_warning("SceneRouter: 目标门不存在 —— %s" % door_id)
		return
	var player := scene.get_node_or_null("Player")
	if player == null:
		push_warning("SceneRouter: 目标房间没有 Player 节点")
		return
	var offset: Vector2 = ARRIVE_DEFAULT
	if door.has_meta("arrive_offset"):
		offset = door.get_meta("arrive_offset")
	player.position = (door as Node2D).position + offset
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
