class_name PixelHeroRig
extends Node2D
## 保留原闲置完整人物母版与像素密度；仅原位替换双臂，避免叠出第三只手。
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
var _source_id := "idle"
var _source_rect := Rect2(0,0,64,64)
var _anchor := Vector2(32,58)
var _grip := Vector2.ZERO
var _rear_hand := Vector2.ZERO
var _support_hand := Vector2.ZERO
var _front_shoulder := Vector2.ZERO
var _back_shoulder := Vector2.ZERO
var _local_aim := Vector2.RIGHT
var _sword_angle := 0.0
var _depth := 1.0
var _skin: Color
var _edge: Color
var _light: Color

func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_motion.json"))
	source = load(str(cfg.source))
	_anchor = _vec(cfg.anchor)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_whole_body.texture = source
	_whole_body.centered = false
	_whole_body.region_enabled = true
	_whole_body.region_rect = _source_rect
	_whole_body.offset = -_anchor
	_whole_body.show_behind_parent = true
	add_child(_whole_body)
	var image := source.get_image()
	_skin = image.get_pixelv(Vector2i(_vec(cfg.arms.skin_sample)))
	_edge = image.get_pixelv(Vector2i(_vec(cfg.arms.edge_sample)))
	_light = image.get_pixelv(Vector2i(_vec(cfg.arms.highlight_sample)))
	# 只清理原手臂覆盖的局部像素，底色取同一母版相同列的腹部，不重新生成头身。
	var shader := Shader.new()
	var code := "shader_type canvas_item; varying vec4 actor_color; void vertex(){actor_color=COLOR;} void fragment(){ vec2 p=floor(UV*vec2(textureSize(TEXTURE,0))); vec4 src=texture(TEXTURE,UV);"
	for r: Array in cfg.arms.mask:
		code += "if(p.x>=%.1f&&p.x<%.1f&&p.y>=%.1f&&p.y<%.1f){src=texture(TEXTURE,vec2(p.x+0.5,%.1f)/vec2(textureSize(TEXTURE,0)));if(p.x>=%.1f){src.a=0.0;}}" % [r[0],r[0]+r[2],r[1],r[1]+r[3],float(cfg.arms.fill_row)+0.5,float(cfg.arms.far_limit)]
	code += "COLOR=src*actor_color;}"
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_whole_body.material = mat
	apply_pose()

## 武器与两只手共用握点，持枪俯仰连续变化；完整人物只旋转重心，不缩放。
func apply_pose() -> void:
	if cfg.is_empty():
		return
	scale.x = float(facing)
	_local_aim = Vector2(aim.x*float(facing),aim.y).normalized()
	if _local_aim.is_zero_approx():
		_local_aim = Vector2.RIGHT
	if kind == "rifle":
		var rifle: Dictionary = cfg.rifle
		var pitch := _local_aim.angle()
		_whole_body.rotation = pitch*float(rifle.body_aim_factor)
		var recoil := float(rifle.recoil)*maxf(0.0,1.0-release_time/float(rifle.recoil_seconds)) if release_time >= 0 else 0.0
		_grip = _vec(rifle.pivot)+Vector2(absf(sin(pitch))*float(rifle.pitch_offset[0]),-absf(sin(pitch))*float(rifle.pitch_offset[1]))-_local_aim*recoil
		_rear_hand = _grip+Vector2(-_local_aim.y,_local_aim.x)*3
		_support_hand = _grip+_local_aim*float(rifle.support)+Vector2(-_local_aim.y,_local_aim.x)*3
	else:
		var s: Dictionary = cfg.sword
		var row := clampi(combo-1,0,2)
		var phase := clampf(progress,0,1)*7
		var frame := mini(floori(phase),6)
		var fraction := phase-frame
		_grip = _vec(s.grips[row][frame]).lerp(_vec(s.grips[row][frame+1]),fraction)
		_sword_angle = deg_to_rad(lerpf(float(s.angles[row][frame]),float(s.angles[row][frame+1]),fraction))
		_whole_body.rotation = deg_to_rad(lerpf(float(s.body_degrees[row][frame]),float(s.body_degrees[row][frame+1]),fraction))
		_depth = lerpf(float(s.depth[row][frame]),float(s.depth[row][frame+1]),fraction)
		var direction := Vector2.from_angle(_sword_angle)
		_support_hand = _grip-direction*2
		_rear_hand = _grip-direction*7
	var left := Vector2(-14,0).rotated(_whole_body.rotation).y
	var right := Vector2(18,0).rotated(_whole_body.rotation).y
	_whole_body.position.y = -maxf(left,right)
	_front_shoulder = _body_point(_vec(cfg.arms.front_shoulder))
	_back_shoulder = _body_point(_vec(cfg.arms.back_shoulder))
	queue_redraw()

func _body_point(point: Vector2) -> Vector2:
	return (point-_anchor).rotated(_whole_body.rotation)+_whole_body.position+_anchor

func _draw() -> void:
	if cfg.is_empty():
		return
	draw_set_transform(-_anchor)
	# 只有这两条完整手臂，原素材的手臂已经由局部遮罩替换。
	_arm(_back_shoulder,_support_hand,-1)
	_arm(_front_shoulder,_rear_hand,1)
	if kind == "rifle":
		_draw_rifle()
	else:
		_draw_sword()
	_hand(_support_hand)
	_hand(_rear_hand)

func _arm(start: Vector2, end: Vector2, bend: float) -> void:
	var d := (end-start).normalized()
	var middle := ((start+end)/2+Vector2(-d.y,d.x)*bend*3).round()
	var points := PackedVector2Array([start.round(),middle,end.round()])
	draw_polyline(points,_edge,float(cfg.arms.width),false)
	draw_polyline(points,_skin,float(cfg.arms.width)-1,false)
	draw_line(start.round(),middle,_light,1,false)

func _hand(point: Vector2) -> void:
	var width := float(cfg.arms.hand_width)
	draw_rect(Rect2(point.round()-Vector2.ONE*width/2,Vector2.ONE*width),_edge)
	draw_rect(Rect2(point.round()-Vector2.ONE,Vector2.ONE*2),_skin)

func _draw_sword() -> void:
	var s: Dictionary = cfg.sword
	var d := Vector2.from_angle(_sword_angle)
	var n := Vector2(-d.y,d.x)
	var root := _grip+d*2
	var point := _grip+d*float(s.length)*_depth
	var base := _grip+d*5
	var blade := PackedVector2Array([(root-n*2).round(),(base-n*2).round(),point.round(),(base+n*2).round(),(root+n*2).round()])
	draw_colored_polygon(blade,Color(s.shadow))
	draw_colored_polygon(PackedVector2Array([root.round(),(base-n).round(),point.round(),(base+n).round()]),Color(s.steel))
	draw_line((root-n*2).round(),point.round(),Color(s.edge),1,false)
	draw_line(root.round(),(point-d*5).round(),Color("#86999c"),1,false)
	draw_line((_grip-n*float(s.guard)).round(),(_grip+n*float(s.guard)).round(),Color(s.shadow),3,false)
	draw_line((_grip-n*float(s.guard)).round(),(_grip+n*float(s.guard)).round(),Color(s.gold),1,false)
	draw_line((_grip-d*float(s.hilt)).round(),_grip.round(),Color(s.grip),3,false)
	for index in 3:
		var center := _grip-d*(3+index*2)
		draw_line((center-n).round(),(center+n).round(),Color("#9e8b68"),1,false)
	var pommel := (_grip-d*(float(s.hilt)+1)).round()
	draw_rect(Rect2(pommel-Vector2.ONE,Vector2(3,3)),Color(s.gold))

func _draw_rifle() -> void:
	var r: Dictionary = cfg.rifle
	var d := _local_aim
	var n := Vector2(-d.y,d.x)
	var stock := PackedVector2Array()
	for point: Vector2 in [Vector2(-12,-1),Vector2(-8,-2),Vector2(-2,0),Vector2(8,0),Vector2(8,4),Vector2(-3,3),Vector2(-9,5),Vector2(-12,4)]:
		stock.append((_grip+d*point.x+n*point.y).round())
	draw_colored_polygon(stock,Color(r.wood))
	draw_line((_grip-d*11+n*4).round(),(_grip-d*3+n*2).round(),Color(r.wood_light),1,false)
	draw_line((_grip-d*2-n).round(),(_grip+d*float(r.barrel_length)-n).round(),Color(r.dark),4,false)
	draw_line((_grip-d*2-n*2).round(),(_grip+d*float(r.barrel_length)-n*2).round(),Color(r.steel),2,false)
	draw_line((_grip+d*3-n*3).round(),(_grip+d*float(r.barrel_length)-n*3).round(),Color(r.highlight),1,false)
	draw_line((_grip+d*8+n*2).round(),(_grip+d*18+n*2).round(),Color(r.wood_light),2,false)
	draw_line((_grip-d-n*4).round(),(_grip+d*3-n*4).round(),Color(r.highlight),1,false)
	draw_line((_grip+d*25-n*4).round(),(_grip+d*25-n*2).round(),Color(r.dark),1,false)

## 实际枪口和可见枪管共用长度、握点与方向。
func muzzle_global_position() -> Vector2:
	return to_global(_grip+_local_aim*float(cfg.rifle.barrel_length)-_anchor)

## 将握持方向转换到世界坐标，子弹沿可见枪管飞行。
func firing_direction_global() -> Vector2:
	return (to_global(_local_aim)-to_global(Vector2.ZERO)).normalized()

func _vec(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
