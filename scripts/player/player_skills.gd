class_name PlayerSkills
extends Node
## 十二招主动技能的施放、阶段、增益和命中；角色移动仍由原物理控制器负责。
var player: Player
var skill_id: StringName = &""
var definition: Dictionary = {}
var specification: Dictionary = {}
var elapsed := 0.0
var committed := false
var finished := false
var cast_serial := 0
var _hit_event := 0
var _hit_targets := {}
var _mana_procs := {}
var _hunt_by_cast := {}
var _kills := {}
var _auras := {}
var _entities: Array[SkillEntity] = []
var _cast_art: SkillArt
var _room: StringName
var _held_input := false
var _release_at := -1.0
var _recovery_at := -1.0
var _counter_at := -1.0
var _counter_triggered := false
var _mirror_hp := 0
var _dash_distance := 0.0
var _dash_stopped := false
var _landed_at := -1.0
var orb: SkillEntity

func _ready() -> void:
	player = get_parent() as Player
	_room = GameState.current_room

func _physics_process(delta: float) -> void:
	if GameState.hp <= 0 or _room != GameState.current_room:
		clear_effects()
		_room = GameState.current_room
	for id: String in _auras.keys():
		if not GameState.skill_buffs.has(id):
			_remove_buff(id)
	for id: String in GameState.skill_buffs.keys():
		GameState.skill_buffs[id].remaining = maxf(0,float(GameState.skill_buffs[id].remaining)-delta)
		if float(GameState.skill_buffs[id].remaining) <= 0:
			_remove_buff(id)

## 所有技能只在有效地面和相应武器下开始；检查失败不收费。
func can_start(id: StringName) -> bool:
	var cfg := DataDB.get_skill(id)
	if cfg.is_empty() or not player.is_on_floor() or not InventoryService.skill_unlocked(id):
		return false
	var required := str(cfg.get("weapon_requirement", "")) if cfg.get("weapon_requirement") != null else ""
	if required != "" and required != player.weapon_type():
		return false
	if id == &"skill_nb_void_milk" and is_instance_valid(orb) and orb.mode == "orb":
		return false
	var mana := InventoryService.skill_mana_cost(id)
	var spec := SkillLibrary.runtime(id)
	if str(spec.get("behavior","")) == "beam":
		mana = _mana_cost(int(spec.charge.tiers[0].mana_cost))
	return player.skill_cooldown(id) <= 0 and GameState.mana >= mana and GameState.sta >= InventoryService.skill_stamina_cost(id)

## 状态机进入施法时初始化阶段；费用在真正生效时提交。
func begin(id: StringName) -> void:
	skill_id = SkillLibrary.canonical(id)
	definition = DataDB.get_skill(skill_id)
	specification = SkillLibrary.runtime(skill_id)
	elapsed = 0
	committed = false
	finished = false
	cast_serial += 1
	_hit_event = 0
	_hit_targets.clear()
	_counter_triggered = false
	_held_input = Input.is_action_pressed(&"cast_selected")
	_release_at = -1
	_recovery_at = -1
	_counter_at = -1
	_landed_at = -1
	_dash_distance = 0
	_dash_stopped = false
	_mirror_hp = 0
	if str(specification.behavior) == "beam":
		_cast_art = SkillArt.spawn(player,str(specification.charge_fx),_local_point(specification.muzzle_offset),float(specification.charge.auto_release_sec),player.facing,true)
	elif float(specification.get("commit_at",1)) <= 0:
		_commit()
	update_actor()

## 推进招式与判定，返回完成状态；伤害事件由数据时刻触发。
func tick(delta: float) -> bool:
	elapsed += delta
	player.velocity.x = 0
	if specification.is_empty():
		return true
	var behavior := str(specification.behavior)
	if behavior == "beam":
		_tick_beam(delta)
		return finished
	if not committed and elapsed >= float(specification.commit_at):
		_commit()
	if finished:
		return true
	match behavior:
		"slash":
			var events: Array = specification.hits
			while committed and _hit_event < events.size() and elapsed >= float(events[_hit_event].time_sec):
				hit_region(_world_point(specification.hit_offset),_vector(specification.hit_size),false,skill_id,float(events[_hit_event].mult),float(specification.knockback),false,false,{},-1,true,"%s:hit_%d" % [skill_id,_hit_event+1])
				_hit_event += 1
		"dash": _tick_dash(delta)
		"slam":
			_tick_slam()
			return finished
		"quickdraw":
			if _counter_at >= 0:
				return elapsed-_counter_at >= float(specification.counter_seconds)
			if _held_input and not Input.is_action_pressed(&"cast_selected"):
				return true
			return elapsed >= float(specification.stance_seconds)
		"mirror":
			_update_mirror_art()
			if _counter_at >= 0 and elapsed-_counter_at >= float(specification.counter_seconds):
				_start_recovery()
			if committed and _counter_at < 0 and _held_input and not Input.is_action_pressed(&"cast_selected") and elapsed >= float(specification.commit_at)+float(specification.perfect_window):
				_start_recovery()
			if _recovery_at >= 0:
				return elapsed-_recovery_at >= float(specification.phases[-1].duration)
	return elapsed >= _total_duration()

func _commit() -> void:
	if committed:
		return
	if str(specification.behavior) in ["prison","spring"] and ground_point(float(specification.get("placement_forward",0))) == Vector2.INF:
		finished = true
		return
	if not _pay(InventoryService.skill_mana_cost(skill_id),InventoryService.skill_stamina_cost(skill_id)):
		finished = true
		return
	committed = true
	if str(specification.behavior) != "orb":
		start_cooldown(skill_id)
	match str(specification.behavior):
		"dash","slash","quickdraw","mirror":
			_cast_art = SkillArt.spawn(player,str(specification.fx),_foot_offset()+_vector(SkillLibrary.animation(str(specification.fx)).attachment)*Vector2(player.facing,1),_total_duration(),player.facing,str(specification.behavior) == "mirror")
			if str(specification.behavior) == "mirror":
				_mirror_hp = int(specification.absorb)
		"prison","spring":
			var entity := _spawn_entity(str(specification.behavior),ground_point(float(specification.get("placement_forward",0))))
			if entity.mode == "spring":
				for other: SkillEntity in _entities:
					if other != entity and is_instance_valid(other) and other.mode == "spring":
						other.queue_free()
		"slam": player.velocity.y = -float(specification.leap_speed)
		"buff":
			var buff: Dictionary = specification.buff.duplicate(true)
			for id: String in specification.exclusive:
				_remove_buff(id)
			_remove_buff(str(buff.id))
			buff.remaining = float(buff.duration_seconds)
			GameState.skill_buffs[str(buff.id)] = buff
			_auras[str(buff.id)] = SkillArt.spawn(player,str(specification.aura),_foot_offset()+_vector(SkillLibrary.presentation().body_center_offset),float(buff.duration_seconds),player.facing,true)
			if str(buff.id) == "frenzy":
				_kills.clear()
			if specification.has("fx"):
				SkillArt.spawn(player,str(specification.fx),_foot_offset(),float(specification.circle_seconds),player.facing)
		"orb":
			orb = _spawn_entity("orb",_world_point(specification.spawn_offset))
			orb.direction = player.aim_vector().normalized()
			# 贴墙/低顶时不能把大球直接生成在墙后；出生即接触世界则在身前引爆。
			var shape := CircleShape2D.new()
			shape.radius = float(specification.contact_radius)
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0,orb.global_position)
			query.collision_mask = 1
			if not line_clear(body_center(),orb.global_position) or not player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
				orb.global_position = body_center()
				orb.detonate()

func _pay(mana: int, stamina: int) -> bool:
	if GameState.mana < mana or GameState.sta < stamina:
		return false
	GameState.mana -= mana
	if stamina > 0:
		player.pay_sta(stamina)
	return true

func _mana_cost(base: int) -> int:
	return AccessoryRules.mana_cost(base)

func _tick_beam(delta: float) -> void:
	var charge: Dictionary = specification.charge
	if _release_at < 0:
		if not player.is_on_floor():
			finished = true
			return
		player.ground_accelerate(delta)
		player.velocity.x = clampf(player.velocity.x,-PlayerTuning.MAX_SPEED*float(charge.move_speed_ratio),PlayerTuning.MAX_SPEED*float(charge.move_speed_ratio))
		if elapsed < float(charge.facing_locked_after_sec):
			player.set_facing(int(signf(player.aim_vector().x)))
		if (_held_input and not Input.is_action_pressed(&"cast_selected")) or (not _held_input and elapsed >= float(charge.minimum_release_sec)) or elapsed >= float(charge.auto_release_sec):
			_release_beam()
	elif elapsed-_release_at >= float(specification.release_seconds)+float(specification.recovery_seconds):
		finished = true
	if is_instance_valid(_cast_art):
		var fx := SkillLibrary.animation(str(specification.charge_fx))
		_cast_art.frame_override = mini(fx.frames.size()-1,floori(clampf(elapsed/float(charge.full_charge_sec),0,1)*fx.frames.size()))
		_cast_art.position = _local_point(specification.muzzle_offset)
		_cast_art.facing = player.facing

func _release_beam() -> void:
	var tier := {}
	for candidate: Dictionary in specification.charge.tiers:
		if elapsed >= float(candidate.min_hold_sec) and GameState.mana >= _mana_cost(int(candidate.mana_cost)):
			tier = candidate
	if tier.is_empty() or not _pay(_mana_cost(int(tier.mana_cost)),InventoryService.skill_stamina_cost(skill_id)):
		finished = true
		return
	committed = true
	_release_at = elapsed
	start_cooldown(skill_id)
	if is_instance_valid(_cast_art):
		_cast_art.queue_free()
	var mouth := _world_point(specification.muzzle_offset)
	var length := clipped_beam_length(mouth,float(tier.range_px),float(tier.beam_height_px))
	var spec := specification.duplicate(true)
	spec.active_sec = float(tier.active_sec)
	var entity := _spawn_entity("beam",mouth,spec)
	entity.beam_length = length
	entity.beam_height = float(tier.beam_height_px)
	hit_region(mouth+Vector2(player.facing*length/2,0),Vector2(length,float(tier.beam_height_px)),false,skill_id,float(tier.damage_mult),float(specification.knockback),false,false,{},-1,true,"%s:%s" % [skill_id,tier.name])

func _tick_dash(delta: float) -> void:
	if not committed or elapsed >= float(specification.dash_end) or _dash_stopped:
		return
	if player.is_on_wall() or not player.is_on_floor() or not EnemyAwareness.has_support_ahead(player,player.facing*float(specification.speed),float(player.get_node("Collision").shape.size.x)):
		_dash_stopped = true
		return
	var distance := minf(float(specification.speed)*delta,float(specification.distance)-_dash_distance)
	_dash_distance += distance
	player.velocity.x = player.facing*distance/delta
	hit_region(_world_point(specification.hit_offset),_vector(specification.hit_size),false,skill_id,float(definition.damage_mult),float(specification.knockback),false,false,_hit_targets)

func _tick_slam() -> void:
	if not committed:
		return
	if _landed_at >= 0:
		finished = elapsed-_landed_at >= float(specification.landing_recovery)
		return
	if elapsed >= float(specification.slam_start):
		if player.is_on_floor():
			_landed_at = elapsed
			var center := feet()+Vector2.UP*float(specification.height)/2
			for area: HurtboxComponent in contacts(center,Vector2(float(specification.radius)*2,float(specification.height))):
				if not visible_target(center,area):
					continue
				damage(area,skill_id,float(definition.damage_mult),float(specification.knockback))
			SkillArt.spawn(player,str(specification.fx),_foot_offset(),_animation_duration(str(specification.fx)),player.facing)
		else:
			player.velocity.y = float(specification.slam_speed)
	if elapsed >= float(specification.landing_timeout):
		finished = true

func _update_mirror_art() -> void:
	if not is_instance_valid(_cast_art):
		return
	if _counter_at >= 0:
		_cast_art.animation = str(specification.fx)
		_cast_art.loop = false
		_cast_art.frame_override = int(SkillLibrary.presentation().field_intro_frames)+mini(1,floori((elapsed-_counter_at)/float(specification.counter_seconds)*2))
	elif elapsed-float(specification.commit_at) >= float(specification.perfect_window):
		_cast_art.animation = str(specification.loop_fx)
		_cast_art.frame_override = -1
		_cast_art.loop = true
	else:
		_cast_art.frame_override = mini(int(SkillLibrary.presentation().field_intro_frames)-1,floori((elapsed-float(specification.commit_at))/float(specification.perfect_window)*int(SkillLibrary.presentation().field_intro_frames)))

## 架势只免除触发的这次受击；反击位移经碰撞求解，不能穿墙。
func parry(_packet: DamagePacket) -> bool:
	if player.sm.current_name() != &"Skill" or str(specification.get("behavior","")) != "quickdraw" or not committed or _counter_triggered or elapsed >= float(specification.stance_seconds) or (_held_input and not Input.is_action_pressed(&"cast_selected")):
		return false
	_counter_triggered = true
	_counter_at = elapsed
	update_actor()
	if is_instance_valid(_cast_art):
		_cast_art.queue_free()
	var closest: HurtboxComponent
	var distance := INF
	for area: HurtboxComponent in contacts(body_center(),Vector2.ONE*float(specification.search_radius)*2,true):
		var point := area.global_position
		var next := body_center().distance_squared_to(point)
		if next < distance and visible_target(body_center(),area):
			closest = area
			distance = next
	if closest != null:
		var toward := closest.global_position-player.global_position
		player.set_facing(int(signf(toward.x)))
		var travel := minf(float(specification.dash_max),maxf(0,absf(toward.x)-float(SkillLibrary.presentation().target_clearance)))
		player.move_and_collide(Vector2(player.facing*travel,0))
		hit_region(_world_point(specification.hit_offset),_vector(specification.hit_size),false,skill_id,float(definition.damage_mult),float(specification.knockback),true)
		_cast_art = SkillArt.spawn(player,str(specification.counter_fx),_foot_offset()+_vector(SkillLibrary.presentation().body_center_offset),float(specification.counter_seconds),player.facing)
	return true

## 镜盾仅防正面；完美窗口、吸收池和一次反击与普通右键格挡独立。
func defend(amount: int, packet: DamagePacket) -> int:
	if player.sm.current_name() != &"Skill" or str(specification.get("behavior","")) != "mirror" or not committed or _recovery_at >= 0 or _counter_at >= 0 or elapsed >= float(specification.recovery_at):
		return amount
	for prefix: String in SkillLibrary.presentation().unguardable_sources:
		if str(packet.source_id).begins_with(prefix):
			return amount
	var incoming := packet.from_position-body_center()
	if absf(Vector2(player.facing,0).angle_to(incoming)) > deg_to_rad(float(specification.facing_arc_deg)/2):
		return amount
	var absorbed := mini(amount,_mirror_hp)
	_mirror_hp -= absorbed
	if elapsed-float(specification.commit_at) <= float(specification.perfect_window) and not _counter_triggered:
		_counter_triggered = true
		_counter_at = elapsed
		var size := Vector2(float(specification.counter_range),float(specification.counter_height))
		hit_region(body_center()+Vector2(player.facing*size.x/2,0),size,false,skill_id,float(specification.counter_mult),float(specification.knockback))
		if absorbed > 0:
			var attacker := packet.origin_actor as Node2D
			var attacker_area := attacker.get("hurtbox") as HurtboxComponent if is_instance_valid(attacker) else null
			if is_instance_valid(attacker) and attacker.has_method("receive_hit") and attacker.get_world_2d() == player.get_world_2d() and attacker_area != null and visible_target(body_center(),attacker_area):
				var reflected := DamagePacket.new(roundi(amount*float(specification.reflect_ratio)),packet.type,0,player.global_position,skill_id)
				reflected.poise_key = StringName(str(skill_id)+":reflect")
				reflected.skill_proc_handled = true
				_record_hit(attacker,int(attacker.receive_hit(reflected)),cast_serial)
		return 0
	if _mirror_hp <= 0:
		_start_recovery()
	return amount-absorbed

## 再次按当前光球技能仅引爆原实体，不进入施法、不再次扣资源。
func detonate_selected(id: StringName) -> bool:
	if SkillLibrary.canonical(id) != &"skill_nb_void_milk" or not is_instance_valid(orb) or orb.mode != "orb":
		return false
	orb.detonate()
	return true

## 技能冷却统一应用感知属性修正。
func start_cooldown(id: StringName) -> void:
	id = SkillLibrary.canonical(id)
	player._skill_ready[id] = player._clock+ProgressionService.skill_cooldown(id)

## 命中入口负责技能回奶一次、吸血反馈及狂击击杀恢复。
func damage(area: HurtboxComponent, id: StringName, multiplier: float, knockback: float, ignore_defense: bool = false, non_interrupting: bool = false, token: int = -1, poise_key: String = "") -> int:
	var cfg := DataDB.get_skill(id)
	var kind := str(cfg.damage_type)
	var cast_token := cast_serial if token < 0 else token
	if not _hunt_by_cast.has(cast_token):
		_hunt_by_cast[cast_token] = player.take_hunt_bonus()
	var range_type := str(SkillLibrary.runtime(id).get("damage_range_type", ""))
	multiplier *= float(_hunt_by_cast[cast_token]) * AccessoryRules.damage_multiplier(range_type, player._clock < player._dodge_bonus_until)
	var packet := DamagePacket.new(player.damage_for_type(kind,multiplier),DamagePacket.DamageType.MAGIC if kind == "magic" else DamagePacket.DamageType.PHYSICAL,knockback,player.global_position,id)
	packet.origin_actor = player
	packet.poise_key = StringName(poise_key if poise_key != "" else str(id)+":hit")
	packet.ignore_defense = ignore_defense
	packet.non_interrupting = non_interrupting
	packet.skill_proc_handled = true
	var result := area.receive_hit(packet)
	_record_hit(area,result,cast_serial if token < 0 else token)
	return result

func _record_hit(target: Node, amount: int, token: int) -> void:
	if amount <= 0:
		return
	if not _mana_procs.has(token):
		_mana_procs[token] = true
		GameState.mana = mini(GameState.mana_max,GameState.mana+int(InventoryService.talent_effect("skill_hit_mana_regen")))
	player._on_hit_landed(target,amount)

## 在可见范围内逐宿主去重，所有技能都检查世界遮挡并排除自己。
func hit_region(point: Vector2, size: Vector2, circle: bool, id: StringName, multiplier: float, knockback: float, ignore_defense: bool = false, non_interrupting: bool = false, dedup: Dictionary = {}, token: int = -1, require_source_los: bool = true, poise_key: String = "") -> void:
	for area: HurtboxComponent in contacts(point,size,circle):
		var actor := target_actor(area)
		if dedup.has(actor.get_instance_id()) or not visible_target(point,area,require_source_los):
			continue
		dedup[actor.get_instance_id()] = true
		damage(area,id,multiplier,knockback,ignore_defense,non_interrupting,token,poise_key)

## 查询同物理世界的敌人受击框，每个敌人最多返回一个。
func contacts(point: Vector2, size: Vector2, circle: bool = false) -> Array[HurtboxComponent]:
	var query := PhysicsShapeQueryParameters2D.new()
	if circle:
		var shape := CircleShape2D.new()
		shape.radius = size.x/2+float(SkillLibrary.presentation().contact_margin)
		query.shape = shape
	else:
		var shape := RectangleShape2D.new()
		shape.size = size+Vector2.ONE*float(SkillLibrary.presentation().contact_margin)*2
		query.shape = shape
	query.transform = Transform2D(0,point)
	query.collision_mask = 32
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result: Array[HurtboxComponent] = []
	var seen := {}
	for hit: Dictionary in player.get_world_2d().direct_space_state.intersect_shape(query,int(SkillLibrary.presentation().query_max_results)):
		var area := hit.collider as HurtboxComponent
		if area == null:
			continue
		var actor := target_actor(area)
		if actor == player or not actor.is_in_group(&"enemies") or seen.has(actor.get_instance_id()) or (actor.get("hp") != null and int(actor.get("hp")) <= 0):
			continue
		seen[actor.get_instance_id()] = true
		result.append(area)
	return result

## 受击框归属用于技能击杀、控制和去重。
func target_actor(area: HurtboxComponent) -> Node2D:
	return area.owner_actor as Node2D if is_instance_valid(area.owner_actor) else area.get_parent() as Node2D

## 使用受击框实际中心做遮挡检查，透明画布不影响命中。
func visible_target(from: Vector2, area: HurtboxComponent, require_source_los: bool = true) -> bool:
	var center := area.global_position
	for child in area.get_children():
		if child is CollisionShape2D:
			center = child.global_position
			break
	return line_clear(from,center) and (not require_source_los or line_clear(body_center(),center))

## 世界层射线用于伤害、治疗和放置，技能不能穿墙。
func line_clear(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from,to,1)
	return player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

## 炮口上中下共同裁短光束，视觉和判定使用同一长度。
func clipped_beam_length(mouth: Vector2, requested: float, height: float) -> float:
	var length := requested
	for fraction: float in SkillLibrary.presentation().beam_probe_fractions:
		var from := mouth+Vector2(0,height*fraction)
		var query := PhysicsRayQueryParameters2D.create(from,from+Vector2(player.facing*requested,0),1)
		var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			length = minf(length,absf(float(hit.position.x)-mouth.x))
	return length

## 地面投影先检查墙，再逐步回退至脚前有效地面。
func ground_point(forward: float) -> Vector2:
	var cfg := SkillLibrary.presentation()
	var root := feet()
	var probe := root+Vector2(player.facing*forward,0)
	var step := float(cfg.ground_probe_up)
	while absf(probe.x-root.x) >= 0:
		if line_clear(body_center(),probe+_vector(cfg.body_center_offset)):
			var query := PhysicsRayQueryParameters2D.create(probe+Vector2.UP*float(cfg.ground_probe_up),probe+Vector2.DOWN*float(cfg.ground_probe_down),129)
			query.hit_from_inside = false
			var hit := player.get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				return hit.position
		if absf(probe.x-root.x) <= step:
			if probe.x == root.x:
				break
			probe.x = root.x
		else:
			probe.x -= player.facing*step
	return Vector2.INF

## 命中回调只对本角色击杀回复一次，不借用全局敌人死亡广播。
func on_hit(area: Node, amount: int) -> void:
	if amount <= 0 or not GameState.skill_buffs.has("frenzy"):
		return
	var actor := target_actor(area as HurtboxComponent) if area is HurtboxComponent else area as Node2D
	if not is_instance_valid(actor) or actor.get("hp") == null or int(actor.get("hp")) > 0 or _kills.has(actor.get_instance_id()):
		return
	_kills[actor.get_instance_id()] = true
	var buff: Dictionary = GameState.skill_buffs.frenzy
	GameState.hp = mini(GameState.hp_max,GameState.hp+roundi(GameState.hp_max*float(buff.on_enemy_kill_heal_pct)/100.0 * AccessoryRules.healing_multiplier()))
	var spec := SkillLibrary.runtime(&"skill_nb_laughter")
	SkillArt.spawn(player,str(spec.heal_fx),_foot_offset()+_vector(SkillLibrary.presentation().body_center_offset),_animation_duration(str(spec.heal_fx)),player.facing)

## 将技能阶段映射到完整逐帧，按逻辑时长保持或循环，不用 PNG 帧序触发伤害。
func update_actor() -> void:
	var phase := _visual_phase()
	if phase.is_empty():
		return
	var id := StringName(phase.actor)
	SkillLibrary.ensure_actor(player.sprite.sprite_frames,id)
	if player.sprite.animation != id:
		player.sprite.play(id)
	player.sprite.pause()
	var count := player.sprite.sprite_frames.get_frame_count(id)
	var cfg := SkillLibrary.animation(str(id))
	var frame := floori(float(phase.time)*float(cfg.fps))%count if bool(cfg.loop) else mini(count-1,floori(clampf(float(phase.time)/float(phase.duration),0,1)*count))
	player.sprite.set_frame_and_progress(frame,0)
	player.sprite.flip_h = player.facing < 0
	SkillLibrary.sync_actor(player.sprite)

func _visual_phase() -> Dictionary:
	if str(specification.get("behavior","")) == "quickdraw" and _counter_at < 0 and elapsed >= float(specification.phases[0].duration):
		var stance: Dictionary = specification.phases[0]
		return {"actor":stance.actor,"time":stance.duration,"duration":stance.duration}
	if specification.is_empty():
		return {}
	if str(specification.behavior) == "beam":
		if _release_at >= 0:
			var t := elapsed-_release_at
			return {"actor":"skill_giga_milk_beam__release" if t < float(specification.release_seconds) else "skill_giga_milk_beam__recovery","time":t if t < float(specification.release_seconds) else t-float(specification.release_seconds),"duration":float(specification.release_seconds) if t < float(specification.release_seconds) else float(specification.recovery_seconds)}
		var charge: Dictionary = specification.charge
		if elapsed < float(charge.minimum_release_sec):
			return {"actor":"skill_giga_milk_beam__charge_start","time":elapsed,"duration":float(charge.minimum_release_sec)}
		return {"actor":"skill_giga_milk_beam__charge_grow" if elapsed < float(charge.full_charge_sec) else "skill_giga_milk_beam__full_hold_loop","time":elapsed-float(charge.minimum_release_sec),"duration":float(charge.full_charge_sec)-float(charge.minimum_release_sec)}
	if _counter_at >= 0:
		return {"actor":str(specification.counter_actor) if specification.has("counter_actor") else "skill_mirror_milk_guard__counter_on_perfect","time":elapsed-_counter_at,"duration":float(specification.counter_seconds)}
	if _recovery_at >= 0:
		return {"actor":str(specification.phases[-1].actor),"time":elapsed-_recovery_at,"duration":float(specification.phases[-1].duration)}
	if str(specification.behavior) == "slam" and _landed_at >= 0:
		return {"actor":"SKL-N03_slam","time":float(specification.landing_recovery)+elapsed-_landed_at,"duration":float(specification.phases[-1].duration)}
	var start := 0.0
	for phase: Dictionary in specification.phases:
		if elapsed < start+float(phase.duration):
			return {"actor":phase.actor,"time":elapsed-start,"duration":phase.duration}
		start += float(phase.duration)
	var last: Dictionary = specification.phases[-1]
	return {"actor":last.actor,"time":last.duration,"duration":last.duration}

## 前摇或后摇可闪避取消；已提交连斩、冲刺和下砸不能被主动普攻截断。
func can_cancel() -> bool:
	if str(specification.get("behavior","")) == "beam":
		return _release_at < 0 or elapsed-_release_at >= float(specification.release_seconds)
	if str(specification.get("behavior","")) == "slam":
		return not committed or _landed_at >= 0
	if str(specification.get("behavior","")) == "mirror":
		return _counter_at < 0 or _recovery_at >= 0
	return not committed or (_counter_at < 0 and elapsed >= float(specification.get("recovery_at",INF)))

## 已提交技能的后摇可衔接普攻；起手与有效出招阶段不能借普攻跳过。
func can_attack_cancel() -> bool:
	if not committed:
		return false
	if str(specification.get("behavior","")) == "beam":
		return _release_at >= 0 and elapsed-_release_at >= float(specification.release_seconds)
	if str(specification.get("behavior","")) == "slam":
		return _landed_at >= 0
	if str(specification.get("behavior","")) == "mirror":
		return _recovery_at >= 0
	return _counter_at < 0 and elapsed >= float(specification.get("recovery_at",INF))

## 退出施法只回收跟随动作的特效；已生成的光球、场地仍按自身生命周期结束。
func end_cast() -> void:
	if is_instance_valid(_cast_art):
		_cast_art.queue_free()
	_mirror_hp = 0
	skill_id = &""

## 死亡、切房、退出节点统一清理临时增益和独立实体。
func clear_effects() -> void:
	_hunt_by_cast.clear()
	for id: String in GameState.skill_buffs.keys():
		_remove_buff(id)
	for id: String in _auras.keys():
		_remove_buff(id)
	for entity: SkillEntity in _entities:
		if is_instance_valid(entity):
			if entity.mode == "orb" and is_instance_valid(player):
				start_cooldown(entity.skill_id)
			entity.queue_free()
	_entities.clear()
	_kills.clear()
	_mana_procs.clear()

func _remove_buff(id: String) -> void:
	GameState.skill_buffs.erase(id)
	if _auras.has(id) and is_instance_valid(_auras[id]):
		_auras[id].queue_free()
	_auras.erase(id)

func _spawn_entity(mode: String, point: Vector2, spec: Dictionary = {}) -> SkillEntity:
	var entity := SkillEntity.new()
	entity.configure(player,skill_id,mode,specification if spec.is_empty() else spec)
	entity.set_meta("cast_serial",cast_serial)
	player.get_parent().add_child(entity)
	entity.global_position = point
	_entities = _entities.filter(func(item: SkillEntity) -> bool: return is_instance_valid(item))
	_entities.append(entity)
	return entity

func _start_recovery() -> void:
	if _recovery_at < 0:
		_recovery_at = elapsed
		_counter_at = -1
		if is_instance_valid(_cast_art):
			_cast_art.queue_free()

func _total_duration() -> float:
	var result := 0.0
	for phase: Dictionary in specification.get("phases",[]):
		result += float(phase.duration)
	return result

func _animation_duration(id: String) -> float:
	var cfg := SkillLibrary.animation(id)
	return float(cfg.frames.size())/float(cfg.fps)

func _foot_offset() -> Vector2:
	return _vector(SkillLibrary.presentation().actor_foot_offset)

## 角色脚底注册点。
func feet() -> Vector2:
	return player.global_position+_foot_offset()

## 角色身体中心，用于视线、反击和光效附着。
func body_center() -> Vector2:
	return feet()+_vector(SkillLibrary.presentation().body_center_offset)

func _world_point(raw: Array) -> Vector2:
	return feet()+_vector(raw)*Vector2(player.facing,1)

func _local_point(raw: Array) -> Vector2:
	return _foot_offset()+_vector(raw)*Vector2(player.facing,1)

func _vector(raw: Array) -> Vector2:
	return Vector2(raw[0],raw[1])

func _exit_tree() -> void:
	clear_effects()
