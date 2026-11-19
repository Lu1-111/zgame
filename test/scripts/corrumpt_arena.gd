extends Node2D
## 独立双阶段演练场；启动器使用隔离存档，保留正式击败与死亡重试流程。
var boss: CorrumptBoss
var player: Player
var profile: Dictionary

func _ready() -> void:
	profile = JSON.parse_string(FileAccess.get_file_as_string(CorrumptBoss.PROFILE))
	var arena: Dictionary = profile.arena
	GameState.reset()
	GameState.current_room = &"forest_02"
	# 演练死亡后仍留在演练场，避免测试被送回正式营地。
	GameState.checkpoint_room = GameState.current_room
	GameState.checkpoint_position = arena.player_position.duplicate()
	var size_value := Vector2(arena.size[0],arena.size[1])
	var forest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	var backdrop := Sprite2D.new()
	backdrop.texture = load(str(forest.background))
	backdrop.centered = false
	backdrop.scale = size_value/backdrop.texture.get_size()
	var darkness := float(arena.background_darkness)
	backdrop.modulate = Color(darkness,darkness,darkness,1)
	backdrop.z_index = -20
	add_child(backdrop)
	var floor_y := float(arena.floor_y)
	_surface(Rect2(0,floor_y,size_value.x,size_value.y-floor_y),false)
	_surface(Rect2(-32,0,32,size_value.y),false)
	_surface(Rect2(size_value.x,0,32,size_value.y),false)
	_surface(Rect2(0,-32,size_value.x,32),false)
	for platform: Array in arena.platforms:
		_surface(Rect2(float(platform[0])-float(platform[2])/2,float(platform[1]),float(platform[2]),6),true)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	player.name = "Player"
	player.position = Vector2(arena.player_position[0],arena.player_position[1])
	add_child(player)
	player.cam.set_bounds(Rect2(Vector2.ZERO,size_value))
	player.cam.zoom = Vector2.ONE*float(arena.camera_zoom)
	boss = (load("res://scenes/enemies/corrumpt.tscn") as PackedScene).instantiate() as CorrumptBoss
	boss.position = Vector2(arena.boss_position[0],arena.boss_position[1])
	boss.target = player
	boss.arena_bounds = Rect2(Vector2.ZERO,size_value)
	add_child(boss)
	if "--phase2" in OS.get_cmdline_user_args():
		boss.begin_phase_two()

func _surface(rect: Rect2, oneway: bool) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 128 if oneway else 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size/2
	shape.one_way_collision = oneway
	body.add_child(shape)
	add_child(body)
	# 演练地面直接复用森林墙体/苔藓贴图，装饰层保持在角色下方。
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/environments/terrain/forest_01/moss_root_cliff_v1.png")
	if oneway:
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/environments/terrain/forest_01/platform_sheet_v1.png")
		atlas.region = Rect2(40,896,1184,108)
		sprite.texture = atlas
		sprite.centered = false
		sprite.scale = rect.size/atlas.get_size()
		body.add_child(sprite)
		return
	if sprite.texture:
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO,rect.size)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		body.add_child(sprite)
