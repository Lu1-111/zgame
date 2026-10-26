class_name PixelHeroRig
extends Node2D
## 正式完整角色帧作母版，人物保持原始上色和轮廓，只替换武器并增加瞄准。
var cfg: Dictionary
var source: Texture2D
var kind := "sword"
var combo := 1
var progress := 0.0
var charge := 0.0
var release_time := -1.0
var aim := Vector2.RIGHT
var facing := 1
var _whole_body := Sprite2D.new()
var _source_id := ""
var _source_rect := Rect2()
var _materials: Dictionary = {}
var _textures: Dictionary = {}
var _shoulder := Vector2.ZERO
var _hand := Vector2.ZERO
var _grip := Vector2.ZERO
var _sword_angle := 0.0
var _local_aim := Vector2.RIGHT
var _anchor := Vector2.ZERO
var _skin: Color
var _edge: Color
var _hand_texture: Texture2D

func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_motion.json"))
	_anchor = _vec(cfg.anchor)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_whole_body.centered = false
	_whole_body.region_enabled = true
	_whole_body.offset = -_anchor
	_whole_body.show_behind_parent = true
	add_child(_whole_body)
	_hand_texture = load(str(cfg.source))
	var reference := _hand_texture.get_image()
	_skin = reference.get_pixelv(Vector2i(_vec(cfg.palette_samples.skin)))
	_edge = reference.get_pixelv(Vector2i(_vec(cfg.palette_samples.edge)))
	apply_pose()

## 96画布正式帧只裁透明留白到64；人物本身不缩放，不拆头身。
func apply_pose() -> void:
	if cfg.is_empty():
		return
	scale.x = float(facing)
	_local_aim = Vector2(absf(aim.x),aim.y).normalized()
	if _local_aim.is_zero_approx():
		_local_aim = Vector2.RIGHT
	var bow := kind == "bow"
	var phase := charge*4.0 if bow else progress*7.0
	if bow and release_time >= 0:
		phase = 5.0+release_time/float(cfg.bow.release_frame_seconds)
	var frame := clampi(roundi(phase),0,7)
	var full: Dictionary = cfg.full_frame
	var aim_group := "up" if _local_aim.angle() < -float(full.bow_angle_threshold) else ("down" if _local_aim.angle() > float(full.bow_angle_threshold) else "level")
	_source_id = str(full.bow_aim_sequences[aim_group][frame]) if bow else str(full.sword_sequences[clampi(combo-1,0,2)][frame])
	var definition: Dictionary = full.frames[_source_id]
	if not _textures.has(_source_id):
		_textures[_source_id] = load(str(definition.path))
	source = _textures[_source_id]
	_whole_body.texture = source
	_source_rect = Rect2(_vec(definition.origin),_vec(cfg.canvas))
	_whole_body.region_rect = _source_rect
	_whole_body.material = _material_for(_source_id)
	_hand = _vec(definition.hand)
	_sword_angle = deg_to_rad(float(full.sword_angles[clampi(combo-1,0,2)][frame]))
	_whole_body.rotation = _local_aim.angle()*float(full.head_aim_factor) if bow else 0.0
	_whole_body.position.x = float(full.draw_shift[0])*charge if bow and release_time < 0 else 0.0
	var left := Vector2(-14,0).rotated(_whole_body.rotation).y
	var right := Vector2(18,0).rotated(_whole_body.rotation).y
	_whole_body.position.y = -maxf(left,right)
	_shoulder = (_vec(cfg.shoulder)-_anchor).rotated(_whole_body.rotation)+_whole_body.position+_anchor
	_grip = (_vec(definition.bow_grip)-_anchor).rotated(_whole_body.rotation)+_whole_body.position+_anchor
	queue_redraw()

func _material_for(id: String) -> ShaderMaterial:
	var key := id
	if _materials.has(key):
		return _materials[key]
	var definition: Dictionary = cfg.full_frame.frames[id]
	var origin := _vec(definition.origin)
	var code := "shader_type canvas_item; varying vec4 actor_color; void vertex(){actor_color=COLOR;} void fragment(){vec2 p=UV*vec2(textureSize(TEXTURE,0))-vec2(%.1f,%.1f); vec4 src=texture(TEXTURE,UV); if(src.b>src.r*1.02&&src.b>src.g*1.02){discard;}" % [origin.x,origin.y]
	for r: Array in definition.masks:
		code += "if(p.x>=%.1f&&p.x<%.1f&&p.y>=%.1f&&p.y<%.1f){discard;}" % [r[0],r[0]+r[2],r[1],r[1]+r[3]]
	code += "COLOR=src*actor_color;"
	code += "}"
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	_materials[key] = material
	return material

func _draw() -> void:
	if cfg.is_empty():
		return
	draw_set_transform(-_anchor)
	if kind == "bow":
		_draw_bow()
	else:
		_draw_sword()

func _arm(start: Vector2, end: Vector2, bend: float) -> void:
	var direction := (end-start).normalized()
	var middle := ((start+end)/2+Vector2(-direction.y,direction.x)*bend*3).round()
	draw_polyline(PackedVector2Array([start,middle,end]),_edge,4,false)
	draw_polyline(PackedVector2Array([start,middle,end]),_skin,3,false)
	var r: Array = cfg.regions.hand
	draw_texture_rect_region(_hand_texture,Rect2(end-Vector2(2,2),Vector2(r[2],r[3])),Rect2(r[0],r[1],r[2],r[3]))

func _draw_sword() -> void:
	var sword: Dictionary = cfg.sword
	var direction := Vector2.from_angle(_sword_angle)
	var across := Vector2(-direction.y,direction.x)
	var start := _hand+direction*float(sword.hilt)
	var end := _hand+direction*float(sword.length)
	draw_line(start.round(),end.round(),Color(sword.shadow),4,false)
	draw_line(start.round(),end.round(),Color(sword.steel),3,false)
	draw_line((start-across).round(),(end-across).round(),Color(sword.edge),1,false)
	draw_line((_hand-across*float(sword.guard)).round(),(_hand+across*float(sword.guard)).round(),Color(sword.gold),2,false)
	draw_line((_hand-direction*float(sword.hilt)).round(),_hand,Color(sword.grip),2,false)

func _draw_bow() -> void:
	var bow: Dictionary = cfg.bow
	var across := Vector2(-_local_aim.y,_local_aim.x)
	var grip := _grip.round()
	var rear := (grip-_local_aim*(3.0+(charge if release_time < 0 else 0.0)*float(bow.draw_distance))).round()
	_arm(_shoulder+Vector2(-2,1),rear,-1)
	if _source_id == "idle":
		_arm(_hand,grip,1)
	var points := PackedVector2Array()
	for sample in 9:
		var t := float(sample)/8*2-1
		points.append((grip+across*float(bow.limb)*t+_local_aim*float(bow.curve)*(1-t*t)).round())
	draw_polyline(points,Color(bow.wood),3,false)
	draw_polyline(points,Color(bow.wood_light),1,false)
	draw_polyline(PackedVector2Array([points[0],rear,points[points.size()-1]]),Color(bow.string),1,false)
	if release_time < 0:
		var tip := (grip+_local_aim*14).round()
		draw_line(rear,tip,Color(bow.wood_light),1,false)
		draw_polyline(PackedVector2Array([(tip-_local_aim*3-across*2).round(),tip,(tip-_local_aim*3+across*2).round()]),Color(bow.arrow),1,false)

## 实际出箭点与光标方向、当前持弓姿势使用同一组坐标。
func muzzle_global_position() -> Vector2:
	return to_global(_grip+_local_aim*float(cfg.bow.curve)-_anchor)

func _vec(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
