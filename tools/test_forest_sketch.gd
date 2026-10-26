extends SceneTree
## 实际角色物理验收：逐条起跳、薄台上穿与下穿、厚台阻挡、篝火宝箱及跨房捷径。
var config: Dictionary
var player: CharacterBody2D
var failures := 0
var platforms := {}
const HALF := 17.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	root.get_node("GameState").reset()
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	# 本套只验收地形与路线，战斗单独由 test_forest_enemies.gd 覆盖。
	for child in current_scene.get_children():
		if child is CharacterBody2D and child.has_meta("spawn_id"):
			child.set_physics_process(false)
	for platform: Dictionary in config.platforms:
		platforms[platform.id] = Rect2(platform.rect[0], platform.rect[1], platform.rect[2], platform.rect[3])
	# 每段路线都用真实角色、输入、重力和烘焙后的物理碰撞起跳；不授予二段跳。
	for route: Array in config.routes:
		var reachable := await _try_route(platforms[route[0]], platforms[route[1]])
		_expect(reachable, "single_jump %s -> %s" % route)
	await _place(Vector2(440, 1824 - HALF))
	Input.action_press("jump")
	var best := player.position.y
	for frame in 42:
		await physics_frame
		best = minf(best, player.position.y)
	Input.action_release("jump")
	await _frames(18)
	_expect(best + HALF < 1728 and absf(player.position.y + HALF - 1728) < 2, "thin platform: pass upward and land on top")
	Input.action_press("move_down")
	await _frames(20)
	Input.action_release("move_down")
	_expect(player.position.y + HALF > 1760, "thin platform: S drops through")
	await _place(Vector2(1120, 1824 - HALF))
	Input.action_press("jump")
	best = player.position.y
	for frame in 36:
		await physics_frame
		best = minf(best, player.position.y)
	Input.action_release("jump")
	_expect(best - HALF >= 1760 - 2, "solid root ceiling blocks upward jump")
	await _place(Vector2(1100, 672 - HALF))
	Input.action_press("move_down")
	await _frames(20)
	Input.action_release("move_down")
	_expect(absf(player.position.y + HALF - 672) < 2, "solid platform cannot be dropped through")
	var gs := root.get_node("GameState")
	gs.hp = 1
	_expect(current_scene.interact_nearby(), "campfire accepts E interaction")
	_expect(gs.hp == gs.hp_max and gs.checkpoint_id == &"cp_forest_01_tree", "campfire heals and sets checkpoint")
	root.get_node("GameUI").close_menu()
	await _frames(40)
	await _place(Vector2(480, 672 - HALF))
	_expect(current_scene.interact_nearby() and not current_scene.get_node("Chest").visible, "chest opens and disappears")
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	_expect(service.count_item("potion_small") == 2, "chest grants potion_small x2 once")
	_expect(not current_scene.interact_nearby(), "opened chest cannot grant duplicate loot")
	await _place(Vector2(1120, 1824 - HALF))
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	_expect(current_scene.name == &"Forest01" and player.position.x < 1168, "shortcut blocks travel from forest_01 before unlock")
	await _place(Vector2(1220, 672 - HALF))
	Input.action_press("move_right")
	await _frames(35)
	Input.action_release("move_right")
	await _frames(35)
	_expect(current_scene.name == &"Forest02ConnectionPreview", "upper exit transitions into forest_02")
	player = current_scene.get_node("Player")
	_expect(absf(player.position.y + HALF - 340) < 2, "forest_02 arrival stands on floor")
	await _place(Vector2(912, 340 - HALF))
	_expect(current_scene.interact_nearby(), "far-side switch opens shortcut")
	await _frames(3)
	_expect(gs.opened_shortcuts.has(&"forest_01_roots") and current_scene.get_node("ShortcutGate").collision_layer == 0, "unlock removes blocking collision")
	await _place(Vector2(988, 340 - HALF))
	Input.action_press("move_right")
	await _frames(35)
	Input.action_release("move_right")
	await _frames(35)
	_expect(current_scene.name == &"Forest01", "shortcut returns to forest_01")
	if current_scene.name != &"Forest01":
		print("FOREST PHYSICS: %d failures" % failures)
		quit(1)
		return
	player = current_scene.get_node("Player")
	_expect(player.position.y > 1760 and not current_scene.get_node("ShortcutGate").visible, "shortcut returns to roots and stays open")
	var map_event := InputEventAction.new()
	map_event.action = &"map"
	map_event.pressed = true
	current_scene._unhandled_input(map_event)
	var map_view := current_scene.get("_map") as TextureRect
	_expect(map_view.visible and map_view.size.x > 0 and map_view.size.y > 0, "M opens a sized map overview")
	current_scene._unhandled_input(map_event)
	await _place(Vector2(60, 1824 - HALF))
	Input.action_press("move_left")
	await _frames(35)
	Input.action_release("move_left")
	await _frames(35)
	_expect(current_scene.name != &"Forest01" and current_scene.has_node("DoorEast"), "west passage returns to camp_01")
	print("FOREST PHYSICS: %d failures" % failures)
	quit(1 if failures else 0)


func _try_route(start: Rect2, target: Rect2) -> bool:
	# 在相邻平台交叠区与边缘采样起跳点，物理阻挡会真实影响结果。
	var left := maxf(start.position.x + 12, target.position.x + 12)
	var right := minf(start.end.x - 12, target.end.x - 12)
	var candidates: Array[float] = []
	if left <= right:
		candidates.append((left + right) / 2)
		candidates.append(right)
		candidates.append(left)
	candidates.append(clampf(target.get_center().x, start.position.x + 12, start.end.x - 12))
	candidates.append(start.end.x - 12)
	candidates.append(start.position.x + 12)
	candidates.append(clampf(target.end.x + 12, start.position.x + 12, start.end.x - 12))
	candidates.append(clampf(target.position.x - 12, start.position.x + 12, start.end.x - 12))
	var target_is_solid := false
	for definition: Dictionary in config.platforms:
		if float(definition.rect[0]) == target.position.x and float(definition.rect[1]) == target.position.y:
			target_is_solid = definition.type == "solid"
	for x in candidates:
		await _place(Vector2(x, start.position.y - HALF))
		if not player.is_on_floor() or absf(player.position.y + HALF - start.position.y) > 2:
			continue
		var aim := clampf(x, target.position.x + 20, target.end.x - 20)
		Input.action_press("jump")
		for frame in 58:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(player.position.x - aim) > 3 and (not target_is_solid or player.position.y + HALF <= target.position.y):
				Input.action_press("move_right" if player.position.x < aim else "move_left")
			await physics_frame
			if frame > 5 and player.is_on_floor():
				if absf(player.position.y + HALF - target.position.y) < 2 and player.position.x > target.position.x and player.position.x < target.end.x:
					_release()
					return true
				break
		_release()
	return false


func _place(pos: Vector2) -> void:
	_release()
	player.position = pos
	player.velocity = Vector2.ZERO
	player.set("_drop_through", 0.0)
	player.set("_jumped", false)
	player.set("_coyote", 0.0)
	player.get("sm").to(&"Idle")
	await _frames(8)


func _release() -> void:
	for action in ["jump", "move_left", "move_right", "move_down", "dodge"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
