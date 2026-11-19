class_name SkillEntity
extends Node2D
## 光球、奶泉、星牢与光束实体；视觉、接触范围、世界遮挡和回收共用生命周期。
var source: Player
var skill_id: StringName
var mode := ""
var specification: Dictionary = {}
var elapsed := 0.0
var direction := Vector2.RIGHT
var facing := 1
var room: StringName
var beam_length := 0.0
var beam_height := 0.0
var _event := 0
var _art: SkillArt
var _contacts := {}
var _controlled := {}
var _healing := 0.0
var _exploded := false

## 初始化独立效果，切房和死亡时统一清理。
func configure(actor: Player, id: StringName, kind: String, spec: Dictionary) -> void:
	source = actor
	skill_id = id
	mode = kind
	specification = spec
	room = GameState.current_room
	facing = actor.facing
	z_index = 21
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	if mode == "beam":
		return
	_art = SkillArt.spawn(self,str(specification.fx),Vector2.ZERO,float(specification.lifetime),facing,mode == "orb")
	_art.persistent = true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or GameState.hp <= 0 or GameState.current_room != room:
		_cleanup()
		return
	elapsed += delta
	match mode:
		"orb": _orb(delta)
		"explosion":
			if elapsed >= float(_art.duration):
				queue_free()
		"prison": _prison()
		"spring": _spring()
		"beam":
			queue_redraw()
			if elapsed >= float(specification.active_sec):
				queue_free()
	if mode in ["prison","spring"]:
		_field_animation()
		if elapsed >= float(specification.lifetime):
			queue_free()

func _orb(delta: float) -> void:
	var motion := direction*float(specification.speed)*delta
	var circle := CircleShape2D.new()
	circle.radius = float(specification.contact_radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = global_transform
	query.motion = motion
	query.collision_mask = 1
	var travel := get_world_2d().direct_space_state.cast_motion(query)
	global_position += motion*float(travel[0])
	if float(travel[0]) < 1.0 or elapsed >= float(specification.lifetime):
		detonate()
		return
	for area: HurtboxComponent in source.skills.contacts(global_position,Vector2.ONE*float(specification.contact_radius)*2,true):
		var actor := source.skills.target_actor(area)
		var key := actor.get_instance_id()
		if elapsed < float(_contacts.get(key,-1.0)) or not source.skills.visible_target(global_position,area,false):
			continue
		_contacts[key] = elapsed+float(specification.contact_interval)
		source.skills.damage(area,skill_id,float(DataDB.get_skill(skill_id).damage_mult),float(specification.knockback),false,false,int(get_meta("cast_serial")),str(skill_id)+":contact")

## 手动、超时或撞墙只爆炸一次，冷却从此刻开始。
func detonate() -> void:
	if _exploded or mode != "orb":
		return
	_exploded = true
	if is_instance_valid(source):
		source.skills.start_cooldown(skill_id)
		source.skills.hit_region(global_position,Vector2.ONE*float(specification.explosion_radius)*2,true,skill_id,float(specification.explosion_mult),float(specification.knockback),false,false,{},int(get_meta("cast_serial")),false,str(skill_id)+":explosion")
	mode = "explosion"
	elapsed = 0.0
	_art.animation = str(specification.explosion_fx)
	_art.loop = false
	_art.elapsed = 0.0
	var animation := SkillLibrary.animation(_art.animation)
	_art.duration = float(animation.frames.size())/float(animation.fps)
	_art.queue_redraw()

func _prison() -> void:
	var size := Vector2(float(specification.radius)*2,float(specification.height))
	var center := global_position+Vector2.UP*size.y/2
	var control: Dictionary = specification.control
	for area: HurtboxComponent in source.skills.contacts(center,size):
		var actor := source.skills.target_actor(area)
		if _controlled.has(actor.get_instance_id()) or not source.skills.visible_target(center,area,false):
			continue
		_controlled[actor.get_instance_id()] = true
		var definition := DataDB.get_enemy(StringName(actor.get("enemy_id")))
		var rank := str(definition.get("rank","normal"))
		var rule: Dictionary = control.get(rank,control.normal)
		if float(definition.get("resist",{}).get("magic",0)) >= 100:
			rule = control.magic_immune
		SkillControl.apply(actor,float(rule.root_sec),float(rule.slow_sec_after_root),float(rule.slow_pct))
	var events: Array = specification.hits
	while _event < events.size() and elapsed >= float(events[_event].time_sec_after_spawn):
		source.skills.hit_region(center,size,false,skill_id,float(events[_event].mult),float(specification.knockback),false,true,{},int(get_meta("cast_serial")),false,"%s:hit_%d" % [skill_id,_event+1])
		_event += 1

func _spring() -> void:
	var events: Array = specification.heals
	while _event < events.size() and elapsed >= float(events[_event].time_sec_after_spawn):
		var feet := source.skills.feet()
		var same_floor := source.is_on_floor() and absf(feet.y-global_position.y) <= float(SkillLibrary.presentation().same_ground_tolerance)
		var center := source.skills.body_center()
		if same_floor and absf(feet.x-global_position.x) <= float(specification.radius) and source.skills.line_clear(global_position+Vector2.UP*float(SkillLibrary.presentation().same_ground_tolerance),center):
			_healing += GameState.hp_max*float(events[_event].heal_pct_max_hp)/100.0 * AccessoryRules.healing_multiplier()
			var amount := floori(_healing)
			_healing -= amount
			GameState.hp = mini(GameState.hp_max,GameState.hp+amount)
		_event += 1

func _field_animation() -> void:
	var cfg := SkillLibrary.animation(str(specification.fx))
	var intro_frames := int(SkillLibrary.presentation().field_intro_frames)
	var outro_frames := int(SkillLibrary.presentation().field_outro_frames)
	var outro_seconds := float(outro_frames)/float(cfg.fps)
	if elapsed < float(intro_frames)/float(cfg.fps):
		_art.animation = str(specification.fx)
		_art.frame_override = floori(elapsed*float(cfg.fps))
	elif elapsed >= float(specification.lifetime)-outro_seconds:
		_art.animation = str(specification.fx)
		_art.frame_override = mini(cfg.frames.size()-1,cfg.frames.size()-outro_frames+floori((elapsed-float(specification.lifetime)+outro_seconds)*float(cfg.fps)))
	else:
		_art.animation = str(specification.loop_fx)
		_art.frame_override = -1
		_art.loop = true

func _cleanup() -> void:
	if mode == "orb" and is_instance_valid(source):
		source.skills.start_cooldown(skill_id)
	queue_free()

func _draw() -> void:
	if mode != "beam" or beam_length <= 0:
		return
	var variant := "beam_hold_a" if floori(elapsed*float(SkillLibrary.presentation().beam_fps))%2 == 0 else "beam_hold_b"
	var parts: Dictionary = SkillLibrary.presentation().beam_components
	var y_scale := beam_height/float(specification.beam_art_height)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,y_scale))
	var muzzle: Dictionary = parts[variant+"_muzzle"]
	var middle: Dictionary = parts[variant+"_middle"]
	var head: Dictionary = parts[variant+"_head"]
	var head_texture := SkillLibrary.texture(str(head.texture))
	var muzzle_texture := SkillLibrary.texture(str(muzzle.texture))
	var middle_texture := SkillLibrary.texture(str(middle.texture))
	var head_start := maxf(0,beam_length-head_texture.get_width())
	var start := float(muzzle_texture.get_width())-float(muzzle.root[0])
	while start < head_start:
		_draw_beam_piece(middle_texture,Vector2(start,-float(middle.root[1])),beam_length)
		start += middle_texture.get_width()
	_draw_beam_piece(muzzle_texture,-Vector2(muzzle.root[0],muzzle.root[1]),beam_length)
	_draw_beam_piece(head_texture,Vector2(head_start,-float(head.root[1])),beam_length)

func _draw_beam_piece(texture: Texture2D, point: Vector2, length: float) -> void:
	var left := maxf(0,point.x)
	var right := minf(length,point.x+texture.get_width())
	if right <= left:
		return
	var size := Vector2(right-left,texture.get_height())
	draw_texture_rect_region(texture,Rect2(Vector2(left,point.y),size),Rect2(Vector2(left-point.x,0),size))
