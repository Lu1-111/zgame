class_name PixelHeroRig
extends Node2D
## 剑使用原版逐帧人物修帧后的完整 PNG；步枪沿用正式射击姿态与原生手臂。
var cfg: Dictionary
var source: Texture2D
var kind := "sword"
var appearance_id := "original"
var combo := 1
var progress := 0.0
var charge := 0.0
var release_time := -1.0
var aim := Vector2.RIGHT
var facing := 1
var sword_pose := "attack"
var ready_elapsed := 0.0
var return_combo := 0
var _frame_data: Dictionary = {}
var _frame_pose: Dictionary = {}
var _frame_clip := ""
var _whole_body := Sprite2D.new()
var _upper_body := Sprite2D.new()
var _native_hands := Sprite2D.new()
var _source_id := ""
var _source_rect := Rect2()
var _anchor := Vector2(32,58)
var _grip := Vector2.ZERO
var _rear_hand := Vector2.ZERO
var _support_hand := Vector2.ZERO
var _local_aim := Vector2.RIGHT
var _sword_angle := 0.0
var _depth := 1.0
var _textures: Dictionary = {}
var _materials: Dictionary = {}
static var _pose_shader: Shader
const POSE_SHADER := """shader_type canvas_item;
uniform vec2 source_origin;
uniform vec4 cut0;
uniform vec4 cut1;
uniform int cut_count;
uniform int part_mode;
uniform vec4 hand_rect;
uniform float split_line;
uniform float overlap_rows;
uniform bool detach_hands;
varying vec4 actor_color;
bool inside(vec2 p,vec4 r){return p.x>=r.x&&p.x<r.x+r.z&&p.y>=r.y&&p.y<r.y+r.w;}
void vertex(){actor_color=COLOR;}
void fragment(){
 vec2 p=floor(UV*vec2(textureSize(TEXTURE,0)))-source_origin;
 vec4 src=texture(TEXTURE,UV);
 if(src.b>src.r*1.015&&src.b>src.g*1.005){discard;}
 if(cut_count>0&&inside(p,cut0)){discard;}
 if(cut_count>1&&inside(p,cut1)){discard;}
 if(part_mode==1&&(p.y<split_line||(detach_hands&&inside(p,hand_rect)))){discard;}
 if(part_mode==2&&p.y>=split_line+overlap_rows){discard;}
 if(part_mode==3&&!inside(p,hand_rect)){discard;}
 COLOR=src*actor_color;
}"""

func _ready() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/hero_motion.json"))
	var frame_path := str(cfg.sword.get("frame_manifest",""))
	if FileAccess.file_exists(frame_path):
		_frame_data = JSON.parse_string(FileAccess.get_file_as_string(frame_path))
	_anchor = _vec(cfg.anchor)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for layer in [_whole_body,_upper_body,_native_hands]:
		layer.centered = false
		layer.region_enabled = true
		layer.offset = -_anchor
		add_child(layer)
	_whole_body.show_behind_parent = true
	_upper_body.show_behind_parent = true
	apply_pose()

## 剑切换完整人物帧；步枪使用原素材姿态与持握方向。
func apply_pose() -> void:
	if cfg.is_empty():
		return
	if kind == "sword" and has_sword_frames():
		_apply_sword_frame()
		return
	_frame_pose = {}
	_anchor = _vec(cfg.anchor)
	_native_hands.show()
	scale.x = float(facing)
	_local_aim = Vector2(aim.x*float(facing),aim.y).normalized()
	if _local_aim.is_zero_approx():
		_local_aim = Vector2.RIGHT
	var motion: Dictionary = cfg.native_motion
	var pose := 0
	var sword_pitch := 0.0
	if kind == "rifle":
		var definition: Dictionary
		for row: Dictionary in motion.rifle_aim:
			if _local_aim.angle() <= float(row.limit):
				definition = row
				break
		var phase := "hold"
		if release_time < 0 and progress < float(motion.rifle_prepare_fraction):
			phase = "prepare"
		elif release_time >= 0 and release_time < float(motion.rifle_fire_seconds):
			phase = "fire"
		elif release_time >= 0 and release_time < float(motion.rifle_recover_seconds):
			phase = "recover"
		_source_id = str(definition[phase])
	else:
		var row := clampi(combo-1,0,2)
		var sequence: Array = motion.sword_sequences[row]
		pose = clampi(roundi(clampf(progress,0,1)*(sequence.size()-1)),0,sequence.size()-1)
		_source_id = str(sequence[pose])
		# 剑与原生手臂共用离散姿态，停帧时不再独自插值转动。
		_depth = float(cfg.sword.depth[row][pose])
		sword_pitch = deg_to_rad(float(cfg.sword.pose_pitch[row][pose]))
	var frame: Dictionary = motion.frames[_source_id]
	if kind == "sword":
		_sword_angle = deg_to_rad(float(frame.get("sword_angle",frame.weapon_angle)))
	if not _textures.has(_source_id):
		_textures[_source_id] = load(str(frame.path))
	source = _textures[_source_id]
	_source_rect = Rect2(_vec(frame.origin),_vec(cfg.canvas))
	var rotation_angle := clampf(_local_aim.angle()-deg_to_rad(float(frame.weapon_angle)),-float(motion.rifle_body_pitch),float(motion.rifle_body_pitch)) if kind == "rifle" else sword_pitch
	if kind == "sword":
		_sword_angle += rotation_angle
	var translation := Vector2.ZERO
	if kind == "rifle" and release_time >= 0:
		translation.x -= float(motion.rifle_recoil_body)*maxf(0,1-release_time/float(cfg.rifle.recoil_seconds))
	for layer in [_whole_body,_upper_body,_native_hands]:
		layer.texture = source
		layer.region_rect = _source_rect
		layer.rotation = 0.0
		layer.offset = -_anchor
		layer.position = Vector2.ZERO
	var native_hand := _vec(frame.hand)
	var split := float(motion.body_split_high) if native_hand.y > float(motion.body_split_hand_threshold) else float(motion.body_split_low)
	if kind == "sword":
		split = float(motion.sword_body_split)
	var waist := Vector2(float(motion.waist_x),split-float(motion.waist_offset))
	_upper_body.visible = true
	# 挥剑时原生头肩、双臂和握剑姿态整体绕腰发力，腿脚保持原帧支撑。
	if kind in ["rifle","sword"]:
		_whole_body.material = _material_for(_source_id,"lower",split)
		_upper_body.material = _material_for(_source_id,"upper",split)
		for layer in [_upper_body,_native_hands]:
			layer.offset = -waist
			layer.position = waist-_anchor+translation
			layer.rotation = rotation_angle
	else:
		_whole_body.material = _material_for(_source_id,"body",split)
	_native_hands.material = _material_for(_source_id,"hands",split)
	_support_hand = (native_hand-waist).rotated(rotation_angle)+waist+translation
	if kind == "rifle":
		_grip = _support_hand-_local_aim*3-Vector2(-_local_aim.y,_local_aim.x)*3
		_rear_hand = _support_hand-_local_aim*float(motion.rifle_hand_spacing)
	else:
		# 原手掌中心落在握柄上，护手沿剑身前移，避免剑绕掌心打转。
		_grip = _support_hand+Vector2.from_angle(_sword_angle)*float(cfg.sword.hand_to_guard)
		_rear_hand = _grip-Vector2.from_angle(_sword_angle)*6
	queue_redraw()


## 判断三段完整逐帧攻击是否已接入。
func has_sword_frames() -> bool:
	var clips: Dictionary = _frame_data.get("clips",{})
	return clips.has("sword_1") and clips.has("sword_2") and clips.has("sword_3")


## 仅在当前素材清单明确提供待机架势时替换原人物闲置动画。
func has_sword_ready_pose() -> bool:
	return has_sword_frames() and bool(_frame_data.get("idle_pose_enabled",true)) and _frame_data.clips.has("ready")


func _apply_sword_frame() -> void:
	scale.x = float(facing)
	_frame_clip = "sword_%d" % clampi(combo,1,3)
	var sample := clampf(progress,0,1)
	if sword_pose == "ready" and _frame_data.clips.has("ready"):
		_frame_clip = "ready"
		sample = 0
		if return_combo in [1,2] and ready_elapsed < float(_frame_data.return_seconds):
			_frame_clip = "return_%d" % return_combo
			sample = clampf(ready_elapsed/float(_frame_data.return_seconds),0,1)
	var frames: Array = _frame_data.clips[_frame_clip].frames
	var index := 0
	for candidate in frames.size():
		if float(frames[candidate].progress) <= sample:
			index = candidate
		else:
			break
	_frame_pose = _frame_data.poses[str(frames[index].pose)]
	_source_id = str(_frame_pose.path).get_file().get_basename()
	if not _textures.has(_source_id):
		_textures[_source_id] = load(str(_frame_pose.path))
	source = _textures[_source_id]
	_anchor = _vec(_frame_data.anchor)
	source = WeaponAppearance.frame_texture(_frame_clip,index,source,appearance_id)
	_source_rect = Rect2(Vector2.ZERO,_vec(_frame_data.canvas))
	_whole_body.texture = source
	_whole_body.region_rect = _source_rect
	_whole_body.offset = -_anchor
	_whole_body.position = Vector2.ZERO
	_whole_body.rotation = 0
	_whole_body.material = null
	_upper_body.hide()
	_native_hands.hide()
	var offset := _anchor-_vec(_frame_data.native_anchor)
	_grip = _vec(_frame_pose.grip)+offset
	_support_hand = _vec(_frame_pose.hand)+offset
	_rear_hand = _vec(_frame_pose.offhand)+offset
	_sword_angle = deg_to_rad(float(_frame_pose.angle_degrees))
	_depth = float(_frame_pose.get("depth",1))
	queue_redraw()

func _material_for(id: String, mode: String, split: float) -> ShaderMaterial:
	var overlap := float(cfg.native_motion.sword_upper_overlap) if kind == "sword" else float(cfg.native_motion.upper_overlap)
	var key := "%s/%s/%s/%s/%s" % [id,kind,mode,split,overlap]
	if _materials.has(key):
		return _materials[key]
	if _pose_shader == null:
		_pose_shader = Shader.new()
		_pose_shader.code = POSE_SHADER
	var frame: Dictionary = cfg.native_motion.frames[id]
	var material := ShaderMaterial.new()
	material.shader = _pose_shader
	material.set_shader_parameter("source_origin",_vec(frame.origin))
	material.set_shader_parameter("part_mode",{"body":0,"lower":1,"upper":2,"hands":3}[mode])
	material.set_shader_parameter("cut_count",frame.masks.size())
	for index in mini(2,frame.masks.size()):
		material.set_shader_parameter("cut%d" % index,_rect_uniform(frame.masks[index]))
	var hand_rect := _rect_uniform(frame.hand_region)
	if kind == "sword":
		# 持握裁片不带入腿部像素，防止大幅转身时出现额外的脚或尾部。
		hand_rect.w = minf(hand_rect.w,split+overlap-hand_rect.y)
	material.set_shader_parameter("hand_rect",hand_rect)
	material.set_shader_parameter("detach_hands",kind == "sword")
	material.set_shader_parameter("split_line",split)
	material.set_shader_parameter("overlap_rows",overlap)
	_materials[key] = material
	return material

func _rect_uniform(values: Array) -> Vector4:
	return Vector4(values[0],values[1],values[2],values[3])

func _draw() -> void:
	if cfg.is_empty():
		return
	if kind == "sword" and has_sword_frames():
		return
	draw_set_transform(-_anchor)
	if kind == "rifle":
		_draw_rifle()
	else:
		_draw_sword()

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
	WeaponAppearance.draw_rifle(self,_grip,_local_aim,appearance_id,_anchor)

## 枪口与正式人物握点、枪管方向共用坐标。
func muzzle_global_position() -> Vector2:
	return to_global(_grip+_local_aim*float(cfg.rifle.barrel_length)-_anchor)

## 子弹沿可见枪管飞行，不改变原人物手臂画法。
func firing_direction_global() -> Vector2:
	return (to_global(_local_aim)-to_global(Vector2.ZERO)).normalized()

func _vec(value: Array) -> Vector2:
	return Vector2(value[0],value[1])
