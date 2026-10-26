extends Node2D
## M1 手感试玩场（灰盒）：几何仅服务调手感，正式房间由 M2 RoomBuilder 按 regions.json 生成。
## Esc 返回标题屏。试玩场默认授予二段跳（正式流程由 cave_07 宝箱 ability_double_jump 授予）。

const GRANT_DOUBLE_JUMP := true
const ROOM_SIZE := Vector2(1280, 720)
## [x, y, w, h]（y 为顶边）
const SOLID_PLATS: Array = [
	[0, 680, 1280, 40],   # 地面
	[0, 0, 20, 720],      # 左墙
	[1260, 0, 20, 720],   # 右墙
]
const ONEWAY_PLATS: Array = [
	[180, 560, 180, 14],
	[430, 470, 170, 14],
	[720, 380, 220, 14],
	[980, 290, 160, 14],
]
const PLAYER_SPAWN := Vector2(120, 663)
const DUMMY_POS := Vector2(950, 666)
const BG_COLOR := Color(0.086, 0.141, 0.102)      # forest #16241a
const SOLID_COLOR := Color(0.23, 0.29, 0.23)
const ONEWAY_COLOR := Color(0.42, 0.5, 0.36)

# ---- M1.5 道具演示层（M2 由正式背包/掉落/拾取系统替换）----
const ITEM_VISUAL_SCENE := "res://assets/PROCESSED/items/ITM-B01/v001/godot/ItemVisual.tscn"
const PICKUP_RANGE := 30.0
## [data_id, 地面位置]（ItemVisual 的 root 锚点即地面点）
const DROP_ITEMS: Array = [
	["potion_small", Vector2(300, 680)],
	["milk_bomb", Vector2(560, 680)],
	["hp_fragment", Vector2(800, 680)],
	["mushroom", Vector2(1150, 680)],
]

var _drops: Array = []   ## {node: ItemVisual, id: StringName, collecting: bool}


func _ready() -> void:
	_build_platforms()
	var player := $Player
	player.checkpoint_position = PLAYER_SPAWN
	($Player/Camera as CameraRig).set_bounds(Rect2(Vector2.ZERO, ROOM_SIZE))
	if GRANT_DOUBLE_JUMP and not GameState.abilities.has(&"double_jump"):
		GameState.abilities.append(&"double_jump")
	($UI/DebugPanel as DebugStats).player = player
	$Dummy.position = DUMMY_POS
	_add_enemy()
	_setup_demo_loadout()
	_spawn_drops()
	_build_hotbar()


func _add_enemy() -> void:
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_presentation.json"))
	var enemy := preload("res://scenes/enemies/enemy.tscn").instantiate() as GameEnemy
	enemy.enemy_id = StringName(str(tuning.default_enemy))
	enemy.target = $Player
	enemy.position = Vector2(tuning.spawn_position[0], tuning.spawn_position[1])
	add_child(enemy)
	var button := Button.new()
	button.text = "F2 敌人战斗演练 / 12类选择"
	button.pressed.connect(func() -> void: SceneRouter.change_scene("res://scenes/levels/combat_enemy_arena.tscn"))
	button.pressed.connect(func() -> void: SceneRouter.change_scene("res://scenes/levels/enemy_arena.tscn"))
	$UI.add_child(button)


func _build_platforms() -> void:
	for r in SOLID_PLATS:
		_add_static(Vector2(r[0], r[1]), Vector2(r[2], r[3]), false)
	for r in ONEWAY_PLATS:
		_add_static(Vector2(r[0], r[1]), Vector2(r[2], r[3]), true)


func _add_static(pos: Vector2, size: Vector2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 128 if one_way else 1
	body.collision_mask = 0
	body.position = pos + size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.one_way_collision = one_way
	body.add_child(cs)
	add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2:
		SceneRouter.change_scene("res://scenes/levels/enemy_arena.tscn")
	elif event.is_action_pressed(&"pause"):
		SceneRouter.change_scene("res://scenes/main.tscn")
	elif event.is_action_pressed(&"interact"):
		_try_pickup()


## M1.5 调试初始装备：演示快捷栏与道具使用（M2 由正式背包流程替换）。
func _setup_demo_loadout() -> void:
	GameState.inventory = [
		{"id": "potion_small", "count": 3},
		{"id": "potion_mana", "count": 2},
		{"id": "potion_sta", "count": 2},
		{"id": "milk_bomb", "count": 2},
	]
	GameState.hotbar = ["potion_small", "potion_mana", "potion_sta", "milk_bomb", ""]


## M1.5 演示掉落物：ItemVisual 世界展示（正式掉落由 RoomBuilder/敌人 M2/M3 接管）。
func _spawn_drops() -> void:
	for d in DROP_ITEMS:
		var visual := (load(ITEM_VISUAL_SCENE) as PackedScene).instantiate()
		add_child(visual)
		visual.global_position = d[1]
		visual.set_item(StringName(d[0]))
		visual.pickup_visual_finished.connect(_on_drop_vanished.bind(visual))
		_drops.append({"node": visual, "id": StringName(d[0]), "collecting": false})


## E 键拾取最近的掉落物：先结算进背包，再播拾取淡出（素材包约定：先结算后播动画）。
func _try_pickup() -> void:
	var player := $Player
	var best: Node2D = null
	var best_id := &""
	var best_dist := PICKUP_RANGE
	for d in _drops:
		if bool(d["collecting"]):
			continue
		var dist: float = (d["node"].global_position - player.global_position).length()
		if dist < best_dist:
			best_dist = dist
			best = d["node"]
			best_id = d["id"]
	if best == null:
		return
	if not InventoryService.add_item(String(best_id),1):
		GameUI.toast("行囊已满")
		return
	for d in _drops:
		if d["node"] == best:
			d["collecting"] = true
	best.play_pickup()


func _on_drop_vanished(_item_id: StringName, node: Node2D) -> void:
	for d in _drops:
		if d["node"] == node:
			_drops.erase(d)
	node.queue_free()


## M1.5 调试快捷栏（右上角横排；正式 HUD 按 §3.10 右缘竖排，M2 实装）。
func _build_hotbar() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HotbarLayer"
	add_child(layer)
	var hotbar := DebugHotbar.new()
	hotbar.name = "Hotbar"
	hotbar.position = Vector2(472, 44)  # 避开敌人会话的 F2 按钮（400,8）
	layer.add_child(hotbar)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), BG_COLOR)
	for r in SOLID_PLATS:
		draw_rect(Rect2(r[0], r[1], r[2], r[3]), SOLID_COLOR)
	for r in ONEWAY_PLATS:
		draw_rect(Rect2(r[0], r[1], r[2], r[3]), ONEWAY_COLOR)
