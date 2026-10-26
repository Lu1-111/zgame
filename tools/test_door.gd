extends SceneTree
## 主流程实走：标题屏 → 营地 → 右侧出口 → 新版森林 → 左侧返回。
## 用法：Godot --headless --path . --fixed-fps 60 --script res://tools/test_door.gd

var _fails := 0
const CAMP := "res://scenes/rooms/camp_01.tscn"
const FOREST := "res://scenes/rooms/forest_01.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").reset()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	var enter := InputEventAction.new()
	enter.action = &"ui_accept"
	enter.pressed = true
	current_scene._unhandled_input(enter)
	await _frames(8)
	if not _check(current_scene.scene_file_path == CAMP, "标题屏正常进入 camp_01"):
		_finish()
		return
	var camp := current_scene
	_check(camp.get_node("DoorEast").target_room == &"forest_01", "营地右侧出口指向 forest_01")
	_check(camp.get_node("DoorEast").target_door == &"DoorWest", "营地出口对应森林左侧入口")
	_check(not camp.has_node("DoorWest") and camp.has_node("Wall_west_trunk"), "营地左侧边界保持封闭")
	var player := camp.get_node("Player") as CharacterBody2D
	Input.action_press("move_left")
	await _frames(90)
	Input.action_release("move_left")
	_check(player.position.x > 6, "营地左侧墙体正常阻挡")
	if not await _walk_until(FOREST, &"move_right"):
		_finish()
		return
	_check(current_scene.has_meta("layout_data") and str(current_scene.get_meta("layout_data")) == "res://data/maps/forest_01.json", "进入的是新版草图森林")
	_check(current_scene.has_node("AncientTreeBackground") and current_scene.has_node("Platform_root_floor/ArtCenter_00"), "新版巨树及精细地形素材已加载")
	_check(current_scene.get_node("Wall_west_trunk").material != null, "墙体使用新版苔岩材质")
	player = current_scene.get_node("Player")
	var west := current_scene.get_node("DoorWest") as Node2D
	var expected := west.position + (west.get_meta("arrive_offset") as Vector2)
	_check(player.position.distance_to(expected) <= 4, "营地出口落在森林左下入口内侧")
	_check(player.is_on_floor(), "进入森林后正常落地")
	_check(root.get_node("GameState").current_room == &"forest_01", "当前房间状态更新为 forest_01")
	if not await _walk_until(CAMP, &"move_left"):
		_finish()
		return
	player = current_scene.get_node("Player")
	var east := current_scene.get_node("DoorEast") as Node2D
	expected = east.position + (east.get_meta("arrive_offset") as Vector2)
	_check(player.position.distance_to(expected) <= 4, "森林左侧通道返回营地右侧出口内侧")
	_check(player.is_on_floor(), "返回营地后正常落地")
	_check(root.get_node("GameState").current_room == &"camp_01", "当前房间状态恢复为 camp_01")
	_finish()


func _walk_until(path: String, action: StringName) -> bool:
	Input.action_press(action)
	var arrived := false
	for frame in 1200:
		await physics_frame
		if current_scene != null and current_scene.scene_file_path == path:
			arrived = true
			break
	Input.action_release(action)
	_check(arrived, "实走通道到达 %s" % path.get_file())
	if not arrived:
		return false
	var router := root.get_node("SceneRouter")
	for frame in 180:
		await physics_frame
		if not router.is_transitioning() and current_scene.get_node("Player").is_on_floor():
			return true
	_check(false, "转场完成且玩家落地")
	return false


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(cond: bool, label: String) -> bool:
	print("%s: %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fails += 1
	return cond


func _finish() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	print("CAMP/FOREST CONNECTION: %d failures" % _fails)
	quit(0 if _fails == 0 else 1)
