class_name WorldMapView
extends Control
signal travel_requested(room_id: StringName, checkpoint: StringName)
## 所有已制作房间的连通总览；标记每帧读取当前角色位置，支持缩放、拖动与居中。

class MapSurface extends Control:
	var map_view: WorldMapView
	func _draw() -> void:
		map_view.draw_world(self)
	func _gui_input(event: InputEvent) -> void:
		map_view.handle_map_pointer(event)

var _config: Dictionary
var _layout: Dictionary
var _rooms := {}
var _textures := {}
var _bounds := Rect2()
var _surface: MapSurface
var _clip: Control
var _location: Label
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var travel_mode := false
var _pointer_down := Vector2.ZERO
var _pointer_distance := 0.0
var _fire_texture: Texture2D
var _fire_config: Dictionary
var _border: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh_map()
	_fire_texture = load(_config.bonfire.icon)
	_fire_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay_ui.json")).campfires
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_clip)
	_surface = MapSurface.new()
	_surface.map_view = self
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(_surface)
	_location = Label.new()
	_location.add_theme_font_override("font", RPGSkin.font())
	_location.add_theme_font_size_override("font_size", int(_config.font_size))
	_location.add_theme_color_override("font_color", _color("text"))
	_location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_location)
	var reset := Button.new()
	reset.text = "总览"
	reset.position = Vector2(-142, 20)
	reset.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	reset.size = Vector2(48, 28)
	RPGSkin.dress_button(reset)
	reset.pressed.connect(reset_view)
	add_child(reset)
	reset.offset_left = -142
	reset.offset_top = 20
	reset.offset_right = -94
	reset.offset_bottom = 48
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(-78, 20)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.size = Vector2(48, 28)
	RPGSkin.dress_button(close)
	close.pressed.connect(func() -> void: get_tree().root.get_node("GameUI").close_menu())
	add_child(close)
	close.offset_left = -78
	close.offset_top = 20
	close.offset_right = -30
	close.offset_bottom = 48
	resized.connect(_resize_content)
	_border = RPGSkin.frame(self,"outline",Rect2(Vector2.ONE*8,size-Vector2.ONE*16))
	_resize_content()


## 重新载入统一地图注册表；所有坐标映射与通道端点都从这份数据读取。
func refresh_map() -> void:
	_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world_map_ui.json"))
	_layout = JSON.parse_string(FileAccess.get_file_as_string(_config.layout))
	_rooms.clear()
	_textures.clear()
	var first := true
	for room: Dictionary in _layout.rooms:
		_rooms[str(room.id)] = room
		var rect := Rect2(room_origin(str(room.id)), Vector2(room.size[0], room.size[1]))
		_bounds = rect if first else _bounds.merge(rect)
		first = false
		var path := "res://assets/ui/map/minimaps/minimap_%s.png" % room.id
		if ResourceLoader.exists(path):
			_textures[str(room.id)] = load(path)
	_bounds = _bounds.grow(float(_config.world_padding))
	queue_redraw()


## 房间在总览中的位置；留出的图间间隙用于显示真实通道配对。
func room_origin(id: String) -> Vector2:
	var fallback: Array = _rooms[id].origin if _rooms.has(id) else [0, 0]
	var origin: Array = _config.room_origins.get(id, fallback)
	return Vector2(origin[0], origin[1])


## 将房间内坐标映射到同一张世界地图坐标，绝不以出生点代替当前位置。
func project_room_position(id: String, local_position: Vector2) -> Vector2:
	return room_origin(id) + local_position


## 查询角色的当前地图坐标；切场景的空帧不绘制过期标记。
func player_map_position() -> Vector2:
	var actor := _player()
	var id := _current_room()
	return project_room_position(id, actor.position) if actor != null and _rooms.has(id) else Vector2.INF


## 查询一对实际连接门的世界地图端点，分别保留上层通道和根部捷径。
func connection_endpoints(connection: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	for side in ["from", "to"]:
		var id := str(connection[side + "_room"])
		if not _rooms.has(id):
			return PackedVector2Array()
		for door: Dictionary in _rooms[id].doors:
			if str(door.id) == str(connection[side + "_door"]):
				points.append(project_room_position(id, Vector2(door.pos[0], door.pos[1])))
				break
	return points


## 还原为完整世界总览。
func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	if _surface != null:
		_surface.queue_redraw()


func _process(_delta: float) -> void:
	if _surface == null:
		return
	var id := _current_room()
	_location.text = "当前位置 · " + str(_rooms[id].name) if _rooms.has(id) else "旅途地图"
	_surface.queue_redraw()


func _resize_content() -> void:
	if _clip == null:
		return
	var margin := float(_config.margin)
	_clip.position = Vector2(margin, _config.header)
	_clip.size = Vector2(maxf(1, size.x - margin * 2), maxf(1, size.y - float(_config.header) - float(_config.footer)))
	_location.position = Vector2(margin, size.y - float(_config.footer) + 10)
	if _border != null:
		_border.size = size-Vector2.ONE*16
	queue_redraw()


func _draw() -> void:
	if _config.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), _color("background"))
	draw_string(RPGSkin.font(), Vector2(_config.margin, 39), "快速旅行" if travel_mode else "旅途地图", HORIZONTAL_ALIGNMENT_LEFT, -1, int(_config.title_size), _color("text"))
	if _clip != null:
		draw_rect(Rect2(_clip.position, _clip.size), _color("surface"))
		draw_rect(Rect2(_clip.position, _clip.size), _color("edge"), false, 1.0)
	var hint := "点击已解锁灵火旅行 · M / Esc 返回" if travel_mode else "滚轮缩放 · 拖动平移 · M / Esc 返回"
	draw_string(RPGSkin.font(), Vector2(size.x - 280, size.y - 13), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_config.font_size), _color("muted"))
	var quest := QuestService.tracked()
	if not quest.is_empty():
		draw_string(RPGSkin.font(),Vector2(_config.margin,QuestService.config().ui.map_header_y),"追踪 · "+str(quest.name),HORIZONTAL_ALIGNMENT_LEFT,size.x-180,int(_config.font_size),_color("fire"))


## 绘制房间纹理、连接线和持续更新的角色标记。
func draw_world(canvas: Control) -> void:
	for id: String in _rooms:
		var room: Dictionary = _rooms[id]
		var rect := Rect2(_to_view(room_origin(id)), Vector2(room.size[0], room.size[1]) * _scale())
		if _textures.has(id):
			canvas.draw_texture_rect(_textures[id], rect, false, Color.WHITE if id == _current_room() else Color("#a8b7b1"))
		canvas.draw_rect(rect, _color("current_room" if id == _current_room() else "other_room"), false, 1.0)
		canvas.draw_string(RPGSkin.font(), rect.position + Vector2(6, 13), str(room.name), HORIZONTAL_ALIGNMENT_LEFT, -1, int(_config.room_title_size), _color("text"))
	for connection: Dictionary in _layout.get("connections", []):
		var endpoints := connection_endpoints(connection)
		if endpoints.size() != 2:
			continue
		var a := _to_view(endpoints[0])
		var b := _to_view(endpoints[1])
		var curve := Curve2D.new()
		var bend := (b.x - a.x) / 2.0
		curve.add_point(a, Vector2.ZERO, Vector2(bend, 0))
		curve.add_point(b, Vector2(-bend, 0), Vector2.ZERO)
		var shortcut := str(connection.get("shortcut_id", ""))
		var shortcuts: Array = get_tree().root.get_node("GameState").get("opened_shortcuts")
		var locked := shortcut != "" and not shortcuts.has(StringName(shortcut))
		var color := _color("locked_link" if locked else "link")
		canvas.draw_polyline(curve.get_baked_points(), color, float(_config.connection_width), true)
		canvas.draw_circle(a, 2.0, color)
		canvas.draw_circle(b, 2.0, color)
		if locked:
			var center := curve.sample_baked(curve.get_baked_length() / 2.0)
			canvas.draw_rect(Rect2(center - Vector2(3, 4), Vector2(6, 8)), color, false, 1.0)
	var point := player_map_position()
	if point.is_finite():
		var center := _to_view(point)
		var wave := sin(Time.get_ticks_msec() / 1000.0 * TAU / float(_config.pulse_seconds))
		var ring := float(_config.marker_ring) + wave
		canvas.draw_arc(center, ring, 0, TAU, 32, _color("player_ring"), float(_config.marker_line), true)
		canvas.draw_circle(center, float(_config.marker_radius), _color("player"))
		var facing: int = _player().get("facing")
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(facing * 11, 0), center + Vector2(facing * 6, -3), center + Vector2(facing * 6, 3)]), _color("player"))
	for fire: Dictionary in unlocked_fire_markers():
		var rect := fire_view_rect(str(fire.room))
		var hovered := rect.grow(float(_config.bonfire.hit_padding)).has_point(_surface.get_local_mouse_position())
		if travel_mode and hovered:
			canvas.draw_rect(rect.grow(2),_color("fire"),false,1.0)
		canvas.draw_texture_rect(_fire_texture,rect,false,Color.WHITE)
		if hovered:
			canvas.draw_string(RPGSkin.font(),rect.position+Vector2(rect.size.x+4,rect.size.y/2),str(_rooms[str(fire.room)].name),HORIZONTAL_ALIGNMENT_LEFT,-1,int(_config.font_size),_color("text"))
	var marker := tracked_quest_marker()
	if not marker.is_empty():
		var center := _to_view(marker.position)
		var radius := float(QuestService.config().ui.marker_radius)
		var color := Color(QuestService.config().ui.marker_color)
		var diamond := PackedVector2Array([center+Vector2.UP*radius,center+Vector2.RIGHT*radius,center+Vector2.DOWN*radius,center+Vector2.LEFT*radius,center+Vector2.UP*radius])
		canvas.draw_polyline(diamond,color,1.5,true)
		canvas.draw_circle(center,2,color)
		if center.distance_to(_surface.get_local_mouse_position()) <= radius*2:
			canvas.draw_string(RPGSkin.font(),center+Vector2(radius+4,-radius),str(marker.name),HORIZONTAL_ALIGNMENT_LEFT,-1,int(_config.font_size),color)


## 仅当前追踪且配置了地点的任务显示地图目标；没有地点时仍显示任务名称。
func tracked_quest_marker() -> Dictionary:
	var quest := QuestService.tracked()
	var location: Dictionary = quest.get("location",{})
	if location.is_empty() or not _rooms.has(str(location.get("room",""))) or not location.has("position"):
		return {}
	return {"name":quest.name,"room":location.room,"position":project_room_position(str(location.room),Vector2(location.position[0],location.position[1]))}


## 只返回实际互动记录中的篝火；宝箱、NPC、开关和未解锁火点均不作为地图标记。
func unlocked_fire_markers() -> Array:
	var result: Array = []
	var unlocked: Array = get_tree().root.get_node("GameState").get("unlocked_campfires")
	for id: String in _rooms:
		var fire: Dictionary = _fire_config.get(id,{})
		if not fire.is_empty() and unlocked.has(StringName(fire.checkpoint)):
			result.append({"room":id,"checkpoint":fire.checkpoint,"pos":fire.ground})
	return result


## 图标保持固定屏幕尺寸，缩放时只改变它的地图落点，便于快速旅行点击。
func fire_view_rect(room_id: String) -> Rect2:
	var fire: Dictionary = _fire_config[room_id]
	var center := _to_view(project_room_position(room_id,Vector2(fire.ground[0],fire.ground[1])))
	var side := float(_config.bonfire.icon_size)
	return Rect2(center-Vector2(side/2,side),Vector2.ONE*side)


## 鼠标缩放围绕光标位置，拖拽只移动地图视口。
func handle_map_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			if event.pressed:
				_pointer_down = event.position
				_pointer_distance = 0
			elif travel_mode and event.button_index == MOUSE_BUTTON_LEFT and _pointer_distance <= float(_config.bonfire.click_slop) and event.position.distance_to(_pointer_down) <= float(_config.bonfire.click_slop):
				for fire: Dictionary in unlocked_fire_markers():
					if fire_view_rect(str(fire.room)).grow(float(_config.bonfire.hit_padding)).has_point(event.position):
						travel_requested.emit(StringName(fire.room),StringName(fire.checkpoint))
						return
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var old := _scale()
			var factor := float(_config.zoom_step) if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / float(_config.zoom_step)
			_zoom = clampf(_zoom * factor, float(_config.zoom_min), float(_config.zoom_max))
			var delta: Vector2 = event.position - _surface.size / 2.0 - _pan
			_pan += delta * (1.0 - _scale() / old)
		_surface.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pointer_distance += event.relative.length()
		_pan += event.relative
		_surface.accept_event()


func _player() -> Node2D:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("Player") as Node2D if scene != null else null


func _current_room() -> String:
	return str(get_tree().root.get_node("GameState").get("current_room"))


func _to_view(point: Vector2) -> Vector2:
	return _surface.size / 2.0 + _pan + (point - _bounds.get_center()) * _scale()


func _scale() -> float:
	return minf(_surface.size.x / _bounds.size.x, _surface.size.y / _bounds.size.y) * _zoom


func _color(key: String) -> Color:
	return Color(_config.colors[key])
