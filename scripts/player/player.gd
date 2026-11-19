class_name Player
extends CharacterBody2D
## 玩家控制器（M1，参考书 §3.1）：移动/跳跃三件套/二段跳/闪避/防御/普攻/技能/受击/死亡。
## 数值来源：手感参数经PlayerTuning读取，土狼时间与闪避配置在data/player_movement.json；
## 武器/技能数值 = DataDB（data/weapons.json、data/skills.json）；
## 三资源（HP/STA/奶力）权威在 GameState，本脚本只做读写与规则结算。

signal presentation_animation_finished(animation: StringName)

const BUBBLE_SCENE := preload("res://scenes/player/projectile_bubble.tscn")
const SPRITE_FRAMES_PATH := "res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres"

# ---- 近战特效判定框规格（M1.5 伤害判定实体化；特效挂武器点并跟随角色，制作人规格）----
const WEAPON_FX_X := 16.0            ## 武器持握点前向偏移（特效节点局部位置，随 facing 取正负）
const WEAPON_FX_Y := -8.0            ## 武器持握点高度（约胸口/手部）
const MELEE_FX_OFFSET_X := 8.0       ## 判定框相对武器点的前向偏移
const MELEE_FX_OFFSET_Y := 12.0      ## 判定框纵向随动幅度（随瞄准 y 缩放）
const MELEE_FX_OFFSET_Y_DOWN := 10.0 ## 判定框纵向随动下限（向上可满幅，向下收窄）

# ---- 运行时 ----
var facing := 1
var cinematic_locked := false
var sm: StateMachine
var checkpoint_position := Vector2.ZERO
var is_guarding := false            ## Guard 状态维护（供受击结算/绘制）
var guard_pose_time := 0.0
var guard_release_from := 0
var guard_perfect := 0.0            ## 完美格挡剩余窗口
var dodge_iframe := false           ## Dodge 状态维护
var attack_combo := 0               ## 当前连击段（0=未在连击中）
var attack_chain := false           ## 连击中再按攻击 → 下一拍（深度 1 的动作队列）
var _attack_held := false
var _rifle_ready_at := 0.0
var _dodge_bonus_until := 0.0
var _hunt_ready := false
var attack_charge := 0.0
var attack_release_t := -1.0
var _hp_regen_acc := 0.0
var _mana_regen_acc := 0.0
var _contact_left := 0.0
var _contact_cooldown := 0.0
var _contact_velocity := 0.0
var _boss_force_left := 0.0
var _boss_force_velocity := Vector2.ZERO
var _boss_pull_center := Vector2.ZERO
var _boss_pull_radius := 0.0
var _boss_is_pull := false
var _pixel_rig: PixelHeroRig
var weapon_appearance_override := "" ## 演练入口可指定外观；正式旅途由当前武器appearance_id读取。
var _weapon_ticket: WeaponAttackTicket
var _kinetic_stacks := 0
var _trait_weapon_id := ""
var _weapon_heal_fraction := 0.0
var _presentation_state: StringName = &""
var _presentation_state_since := 0.0
var _sword_return_combo := 0
var _external_animation: StringName = &""
var attack_phase := &""             ## 供绘制的攻击阶段

var _buffers: Dictionary = {}       ## 动作名 → 剩余缓冲秒数
var _coyote := 0.0
var _dodge_cd := 0.0
var _air_dodge_used := false
var _air_jumps_left := 0
var _jumped := false                ## 本次离地是否由跳跃造成（防土狼重复跳）
var _jump_cut_done := false         ## 松键短跳衰减是否已结算（一次性，防每帧指数急停）
var _invuln := 0.0
var _skill_cd := 0.0
var _last_attack_time := -10.0
var _last_sta_cost := -10.0
var _sta_acc := 0.0                ## 体力回复小数累加器（防逐帧舍入丢回复）
var _clock := 0.0
var _was_on_floor := false
var _drop_through := 0.0
var gravity_enabled := true       ## Dodge/Dead 等状态关闭重力（由状态 enter/exit 维护）
var _last_g := 0.0
var _used_double := false          ## 本段空中已用二段跳（选动画：jump vs double_jump）
var _dodge_air := false            ## 本次闪避起手是否在空中（选动画：dodge vs air_dodge）
var _hurt_break := false           ## 本次受击是否为破防（选动画：guard_break vs hurt）
var _skill_cfgs: Dictionary = {}   ## 十二技能正式配置，来自 DataDB
var skills: PlayerSkills
var _skill_ready: Dictionary = {}  ## 技能 id → 冷却就绪时刻（_clock 秒）
var _current_skill: StringName = &"skill_comet_dash"  ## 正在施放的技能（Skill 状态与动画用）
var _item_anim: StringName = &""   ## 使用道具的演出动画（heal/cast）
var _item_anim_t := 0.0
var _shield_hp := 0
var _shield_until := 0.0

@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $AttackPivot/Hitbox  # 判定已移至 AttackEffect（节点保留不激活）
@onready var cam: CameraRig = $Camera
@onready var _bubble_spawn: Marker2D = $BubbleSpawn
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	hurtbox.hit_callback = apply_hit
	hurtbox.owner_actor = self      # 归属标记：普攻/投射物绝不命中自己
	hitbox.source_actor = self
	hitbox.hit_landed.connect(_on_hit_landed)
	for id in DataDB.skills:
		_skill_cfgs[id] = DataDB.get_skill(id)
	_setup_sprite()
	skills = PlayerSkills.new()
	add_child(skills)
	_pixel_rig = PixelHeroRig.new()
	_pixel_rig.position = sprite.position
	_pixel_rig.hide()
	add_child(_pixel_rig)
	sm = StateMachine.new()
	sm.name = "StateMachine"
	add_child(sm)
	var list: Array = [
		PlayerStates.Idle.new(), PlayerStates.Run.new(),
		PlayerStates.Jump.new(), PlayerStates.Fall.new(),
		PlayerStates.Land.new(), PlayerStates.Dodge.new(),
		PlayerStates.Guard.new(), PlayerStates.GuardRelease.new(), PlayerStates.Attack.new(),
		PlayerStates.Skill.new(), PlayerStates.Hurt.new(),
		PlayerStates.Dead.new(),
	]
	sm.setup(self, &"Idle", list)
	checkpoint_position = global_position
	_update_animation()


## 注入 CHR-01 精灵帧；资源缺失时保持 _draw() 灰盒回退（素材容错约定）。
func _setup_sprite() -> void:
	var frames := (load(SPRITE_FRAMES_PATH) as SpriteFrames).duplicate(true) as SpriteFrames
	if frames == null:
		push_warning("Player：主角精灵帧缺失，回退灰盒色块 —— %s" % SPRITE_FRAMES_PATH)
		sprite.visible = false
		return
	WeaponRuntime.inject_animations(frames)
	sprite.sprite_frames = frames
	sprite.frame_changed.connect(_sync_weapon_sprite)
	sprite.animation_changed.connect(_sync_weapon_sprite)
	sprite.animation_finished.connect(_on_frame_presentation_finished)
	sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if cinematic_locked:
		velocity = Vector2.ZERO
		return
	_clock += delta
	_update_timers(delta)
	_update_passive_regeneration(delta)
	_update_input()
	sm.tick(delta)
	if sm.current_name() == &"Dead":
		_boss_force_left = 0
	if _contact_left > 0:
		velocity.x = _contact_velocity
	if _boss_force_left > 0 and sm.current_name() != &"Dead":
		_boss_force_left = maxf(0,_boss_force_left-delta)
		if _boss_is_pull and global_position.distance_to(_boss_pull_center) <= _boss_pull_radius:
			_boss_force_left = 0
			velocity = Vector2.ZERO
		else:
			velocity = _boss_force_velocity
	# 半步重力（leapfrog）：tick 先行（含跳跃脉冲赋速），随后 g·dt/2 → 位移 → 再 g·dt/2，
	# 使离散跳高逼近连续解析值（§3.1 验收 4）；Dodge/Dead 等可整体关闭重力。
	if gravity_enabled:
		_last_g = PlayerTuning.GRAVITY_UP if velocity.y < 0.0 else PlayerTuning.GRAVITY_DOWN
		velocity.y = minf(velocity.y + _last_g * delta * 0.5, PlayerTuning.MAX_FALL)
	_update_collision_mask()   # 位移前更新：上升帧当帧即放行平台
	move_and_slide()
	_resolve_enemy_contact()
	if gravity_enabled:
		velocity.y = minf(velocity.y + _last_g * delta * 0.5, PlayerTuning.MAX_FALL)
	_update_floor_state()
	_try_platform_mantle()
	_update_drop_trigger()
	_update_animation()
	queue_redraw()


## 首领冲撞在正常伤害/格挡/闪避结算成功后施加大幅击退，不绕过玩家无敌。
func apply_boss_charge(packet: DamagePacket, seconds: float, stun_seconds: float) -> int:
	var damage := apply_hit(packet)
	if damage <= 0 or GameState.hp <= 0:
		return damage
	clear_action_buffers()
	_boss_is_pull = false
	var away := (global_position-packet.from_position).normalized()
	_boss_force_velocity = away*packet.knockback
	_boss_force_left = seconds
	sm.to(&"Hurt",{"stun":stun_seconds,"kb_dir":0})
	velocity = _boss_force_velocity
	return damage

## 首领无伤控制：引力和震退产生真实受击硬直，经物理移动防止穿墙。
func apply_boss_force(center: Vector2, speed: float, seconds: float, stun_seconds: float, pull: bool, safe_radius: float = 0.0) -> bool:
	if is_invulnerable() or GameState.hp <= 0:
		return false
	clear_action_buffers()
	_boss_is_pull = pull
	_boss_pull_center = center
	_boss_pull_radius = safe_radius
	var direction := (center-global_position).normalized() if pull else (global_position-center).normalized()
	if direction.is_zero_approx():
		direction = Vector2.LEFT
	_boss_force_velocity = direction*speed
	_boss_force_left = seconds
	sm.to(&"Hurt",{"stun":stun_seconds,"kb_dir":0})
	velocity = _boss_force_velocity
	return true


# ============================================================
# 输入与缓冲
# ============================================================

## 水平输入轴。
func input_dir() -> float:
	return 0.0 if cinematic_locked else Input.get_axis(&"move_left", &"move_right")

## 转阶段期间冻结玩家全部操作，清除旧攻击与缓冲，结束后恢复正常移动。
func set_cinematic_lock(active: bool) -> void:
	cinematic_locked = active
	clear_action_buffers()
	velocity = Vector2.ZERO
	_boss_force_left = 0
	_contact_left = 0
	hitbox.deactivate()
	if active and sm.current_name() != &"Dead":
		sm.to(&"Idle")
		_update_animation()

## 虚空接触逐物理帧扣固定生命，不经过普通受击无敌、防御和硬直。
func apply_void_contact_damage(amount: int) -> int:
	if cinematic_locked or GameState.hp <= 0 or sm.current_name() == &"Dead":
		return 0
	var loss := _lose_health(amount)
	if GameState.hp <= 0:
		sm.to(&"Dead")
	return loss

## 最终招式的弱引力只附加小幅物理位移，不禁止移动、闪避或攻击。
func apply_void_pull(center: Vector2, speed: float, delta: float) -> void:
	if cinematic_locked or GameState.hp <= 0:
		return
	move_and_collide((center-global_position).normalized()*speed*delta)


## 把 just_pressed 动作写入缓冲（普攻在连击中走专用 1 槽 chain 标记）。
func _update_input() -> void:
	if not Input.is_action_pressed(&"attack"):
		_attack_held = false
	if GameUI.gameplay_input_blocked():
		clear_action_buffers()
		return
	for action in [&"jump",&"dodge",&"attack",&"cast_selected"]:
		if Input.is_action_just_pressed(action):
			if action == &"cast_selected" and skills.detonate_selected(InventoryService.equipped_skill(GameState.selected_skill)):
				continue
			if action == &"attack" and GameUI.pointer_over_interface():
				continue
			if action == &"attack":
				_attack_held = true
			if action == &"attack" and sm.current_name() == &"Attack":
				attack_chain = true
			elif action == &"jump":
				_buffers[action] = PlayerTuning.JUMP_BUFFER
			else:
				_buffers[action] = PlayerTuning.ATTACK_BUFFER
	for i in 5:
		if Input.is_action_just_pressed(StringName("item_%d" % (i+1))):
			use_hotbar_slot(i)


## 消费缓冲（命中即清零）。
func buffer_consume(action: StringName) -> bool:
	if float(_buffers.get(action, 0.0)) > 0.0:
		_buffers[action] = 0.0
		return true
	return false


func buffer_peek(action: StringName) -> bool:
	return float(_buffers.get(action, 0.0)) > 0.0


# ============================================================
# 连贯性核心：统一动作衔接入口
# ============================================================

## 各地面/空中自由态每帧先问这里；优先级：跳跃 > 闪避 > 普攻 > 技能 > 防御。
## 攻击/技能的后摇取消不在此处（由对应状态在可取消窗口自行裁决）。
## 注意：peek 成功才 consume——动作暂不可用（如空中无二段跳）不能吞掉缓冲，
## 缓冲须存活到落地/冷却结束（§3.1 验收 2）。
func try_actions() -> bool:
	if buffer_peek(&"jump"):
		if try_ground_jump():
			buffer_consume(&"jump")
			sm.to(&"Jump")
			return true
		if try_air_jump():
			buffer_consume(&"jump")
			sm.to(&"Jump", {"air": true})
			return true
	if buffer_peek(&"dodge") and can_dodge():
		buffer_consume(&"dodge")
		sm.to(&"Dodge", {"dir": input_dir()})
		return true
	if (buffer_peek(&"attack") or attack_held()) and can_start_weapon_attack():
		buffer_consume(&"attack")
		sm.to(&"Attack", {"combo": next_combo()})
		return true
	if try_selected_skill():
		return true
	if Input.is_action_pressed(&"guard") and is_on_floor():
		sm.to(&"Guard")
		return true
	return false


# ============================================================
# 移动原语
# ============================================================

## 地面加减速。
func ground_accelerate(delta: float) -> void:
	var dir := input_dir()
	velocity.x = move_toward(velocity.x, dir * movement_speed(),
			(PlayerTuning.GROUND_ACCEL if absf(dir) > 0.01 else PlayerTuning.GROUND_DECEL) * delta)


## 空中加减速。
func air_accelerate(delta: float) -> void:
	var dir := input_dir()
	set_facing_by_input(dir)
	velocity.x = move_toward(velocity.x, dir * movement_speed(),
			(PlayerTuning.AIR_ACCEL if absf(dir) > 0.01 else PlayerTuning.AIR_DECEL) * delta)


## 当前常态移速（含天赋），供玩家移动与Boss相对速度共用。
func movement_speed() -> float:
	return PlayerTuning.MAX_SPEED * (1.0 + (InventoryService.talent_effect("move_speed_pct") + AccessoryRules.effect("move_speed_pct")) / 100.0)


func set_facing(v: int) -> void:
	if v == 0:
		return
	facing = v
	$AttackPivot.scale.x = float(v)


func set_facing_by_input(dir: float) -> void:
	set_facing(int(signf(dir)))


## 攻击用瞄准向量：鼠标世界坐标减玩家中心；
## 距离 <4px（鼠标贴身/无输入设备）时回退当前朝向，避免方向抖动。
func aim_vector() -> Vector2:
	var v := get_global_mouse_position() - global_position
	return v if v.length() >= 4.0 else Vector2(float(facing), 0.0)


# ============================================================
# 跳跃 / 闪避 / 技能 条件与执行
# ============================================================

## 地面跳含离台宽限；主动跳跃与下穿不再借用旧接地标记重复起跳。
func try_ground_jump() -> bool:
	if _jumped or _drop_through > 0.0:
		return false
	if is_on_floor() or _coyote > 0.0:
		velocity.y = -PlayerTuning.JUMP_VELOCITY
		_coyote = 0.0
		_jumped = true
		_jump_cut_done = false
		return true
	return false


## 空中二段跳（奶泡跃：能力解锁后空中 1 次）。
## 手感约定：固定跳高（免除松键衰减）+ 保留上升动量（minf：正在更快上升时不再减速，
## 消除"上升中二段跳先顿一下"的顿挫）。
func try_air_jump() -> bool:
	if not GameState.abilities.has(&"double_jump"):
		return false
	if _air_jumps_left <= 0:
		return false
	_air_jumps_left -= 1
	_coyote = 0.0
	_jumped = true
	_used_double = true
	velocity.y = minf(velocity.y, -PlayerTuning.DOUBLE_JUMP_VELOCITY)
	_jump_cut_done = true
	return true


func can_dodge() -> bool:
	if bool(GameState.skill_buffs.get("endurance",{}).get("disable_dodge",false)):
		return false
	if _dodge_cd > 0.0:
		return false
	if not is_on_floor() and _air_dodge_used:
		return false
	return GameState.sta >= AccessoryRules.stamina_cost(PlayerTuning.DODGE_STA_COST)


## 扣体力（不足返回 false）；成功则刷新体力回复计时。
func pay_sta(v: int) -> bool:
	if GameState.sta < v:
		return false
	GameState.sta -= v
	_last_sta_cost = _clock
	return true


## 闪避起手结算（Dodge 状态 enter 时调用）：扣体力、进冷却、记空中次数。
func begin_dodge() -> void:
	pay_sta(AccessoryRules.stamina_cost(PlayerTuning.DODGE_STA_COST))
	_dodge_cd = PlayerTuning.DODGE_COOLDOWN * (1.0 + InventoryService.talent_effect("dodge_cooldown_pct") / 100.0)
	if not is_on_floor():
		_air_dodge_used = true


## 施放前校验不收费；动作真正生效时才原子扣资源和开始冷却。
func try_skill(skill_id: StringName = &"skill_comet_dash") -> bool:
	return skills.can_start(SkillLibrary.canonical(skill_id))


## 当前武器是否远程（决定普攻走特效实体还是投射物）。
func weapon_is_ranged() -> bool:
	return String(weapon_cfg().get("range_type", "melee")) == "ranged"

## 只接受从游戏区域开始的长按，界面打开或松键会清除。
func attack_held() -> bool:
	return _attack_held and not GameUI.pointer_over_interface()

## 枪械可预备下一发，但射击间隔和弹药必须满足。
func can_start_weapon_attack() -> bool:
	var weapon := weapon_cfg()
	if weapon.is_empty():
		return false
	if weapon_type() != "rifle":
		return true
	var module := WeaponRuntime.attack_module(weapon, normal_attack_speed())
	# 枪在第一个跨过起手终点的物理帧开火，两次射击使用同一离散时间。
	var step := Engine.time_scale / Engine.physics_ticks_per_second
	var fire_at := _clock + ceilf(float(module.startup) / step) * step
	return GameState.ammo_units >= WeaponAttributes.ammo_cost(weapon) and (fire_at >= _rifle_ready_at or is_equal_approx(fire_at, _rifle_ready_at))

## 普攻时序同时采用武器攻速与饰品攻速，当前攻击冻结该倍率。
func normal_attack_speed() -> float:
	if _weapon_ticket != null:
		return _weapon_ticket.attack_speed
	return float(weapon_cfg().get("attack_speed_multiplier", 1.0)) * (1.0 + AccessoryRules.effect("attack_speed_pct") / 100.0)

## 步枪与奶杖远程普攻，枪口、子弹和瞄准使用同一组坐标。
func spawn_weapon_projectile(_charge: float = 1.0) -> void:
	var w := weapon_cfg()
	var proj: Dictionary = w.get("projectile",{})
	var kind := weapon_type()
	var module := normal_attack_module()
	var packet := build_attack_packet(1)
	var direction := aim_vector().normalized()
	var socket: Array = module.get("socket",[24,-9])
	var point := global_position+Vector2(float(socket[0])*facing,float(socket[1]))
	var speed := float(proj.get("speed", 380))
	var spread: Array = [0]
	if kind == "rifle":
		var cost := WeaponAttributes.ammo_cost(w)
		# 一个物理帧内的浮点误差不能阻止正常间隔的射击。
		if GameState.ammo_units < cost or (_clock < _rifle_ready_at and not is_equal_approx(_clock, _rifle_ready_at)):
			return
		var free_probability := AccessoryRules.effect("free_shot_probability")
		if free_probability <= 0.0 or randf() >= free_probability:
			GameState.ammo_units -= cost
		_rifle_ready_at = _clock + normal_attack_duration()
		speed = float(WeaponAttributes.config().rifle.base_projectile_speed) * float(proj.get("speed_multiplier", 1.0))
		spread = proj.get("spread_degrees", [0])
		_sync_rig_pose()
		point = _pixel_rig.muzzle_global_position()
		direction = _pixel_rig.firing_direction_global()
	for angle: float in spread:
		var bullet := BUBBLE_SCENE.instantiate() as ProjectileBubble
		bullet.setup(direction.rotated(deg_to_rad(angle)), packet)
		bullet.visual_kind = "bullet" if kind == "rifle" else "staff"
		bullet.projectile_kind = str(proj.get("kind", bullet.visual_kind))
		bullet.speed = speed
		bullet.pierce = bool(proj.get("pierce", false))
		bullet.shockwave_ratio = float(proj.get("shockwave_ratio", 0))
		bullet.source_actor = self
		bullet.hit_landed.connect(_on_hit_landed)
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = point
	AttackEffect.spawn(get_tree().current_scene,null,self,&"rifle_shot" if kind == "rifle" else &"staff_cast",point,direction,Vector2.ZERO,Vector2.ZERO,0)


## 剑按剑身与剑光的逐帧轮廓接触，其余近战保留原特效判定实体。
## 玩家身上的静态 $AttackPivot/Hitbox 不激活，避免叠加隐形矩形伤害。
func spawn_melee_effect(combo_idx: int) -> void:
	if weapon_type() == "sword":
		var sword_effect := SwordAttackEffect.spawn(self,build_attack_packet(combo_idx),self,combo_idx)
		sword_effect.hit_landed.connect(_on_hit_landed)
		return
	var module := normal_attack_module()
	var index := clampi(combo_idx-1,0,module.sockets.size()-1)
	var raw: Array = module.sockets[index]
	var socket := Vector2(float(raw[0])*facing,float(raw[1]))
	var cfg: Dictionary = weapon_cfg().get("hitbox",{})
	var raw_offset: Array = module.hitbox_offsets[index]
	var hitbox_size := Vector2(float(cfg.get("w",44)),float(cfg.get("h",36)))
	if module.has("hitbox_sizes"):
		var size: Array = module.hitbox_sizes[index]
		hitbox_size = Vector2(size[0],size[1])
	var fx := AttackEffect.spawn(self,build_attack_packet(combo_idx),self,melee_effect_name(combo_idx),global_position+socket,Vector2(float(facing),0),hitbox_size,Vector2(float(raw_offset[0])*facing,float(raw_offset[1])),float(module.active))
	fx.align_weapon_visual(float(module.effect_rate)*normal_attack_speed(),weapon_type() == "hammer" and combo_idx == 3)
	fx.hit_landed.connect(_on_hit_landed)


## 武器类别和连击段决定对应的独立攻击特效。
func melee_effect_name(combo_idx: int) -> StringName:
	var names: Array = WeaponRuntime.module(weapon_type()).get("effects",[])
	return StringName(names[clampi(combo_idx-1,0,names.size()-1)]) if not names.is_empty() else &"hammer_swing_1"


## 调试：T 键按 DataDB 登记顺序循环切换武器（M2 由装备界面接管）。
func _cycle_weapon() -> void:
	var order: Array = DataDB.weapons.keys()
	if order.is_empty():
		return
	var idx := order.find(GameState.weapon_id)
	GameState.weapon_id = StringName(String(order[(idx + 1) % order.size()]))


## 使用快捷栏槽位道具，数量与堆叠统一交给正式背包服务。
func use_hotbar_slot(slot: int) -> bool:
	var result := InventoryService.use_hotbar(slot,self)
	if result:
		GameUI.select_hotbar(slot)
	return result


# ============================================================
# 武器 / 数值
# ============================================================

## 清除界面交互前后的动作缓冲，避免关菜单后误触攻击或跳跃。
func clear_action_buffers() -> void:
	_buffers.clear()
	attack_chain = false
	_attack_held = false


## 篝火恢复全部技能冷却。
func reset_cooldowns() -> void:
	_skill_ready.clear()
	_dodge_cd = 0.0


## HUD 获取指定技能的剩余冷却秒数。
func skill_cooldown(id: StringName) -> float:
	return maxf(0.0,float(_skill_ready.get(SkillLibrary.canonical(id),0.0)) - _clock)


## 点击技能格与键盘共用同一套施法规则。
func cast_ui_skill(id: StringName) -> bool:
	id = SkillLibrary.canonical(id)
	if skills.detonate_selected(id):
		return true
	if sm.current_name() not in [&"Idle",&"Run",&"Land",&"Fall",&"Jump"] or not try_skill(id):
		return false
	_current_skill = id
	sm.to(&"Skill")
	return true


## 背包使用道具后选择对应的正式演出动作。
func play_item_animation(id: String) -> void:
	_item_anim = &"heal" if id == "potion_small" else &"cast"
	_item_anim_t = float(InventoryService.config().combat.item_animation)


## 奶弹从玩家位置发射；物品扣除由背包服务统一负责。
func throw_inventory_item(id: String, damage: int) -> void:
	var packet := DamagePacket.new(damage,DamagePacket.DamageType.PHYSICAL,PlayerTuning.ATTACK_KB,global_position,StringName(id))
	packet.poise_key = StringName("item:"+id)
	var bubble := BUBBLE_SCENE.instantiate()
	bubble.setup(aim_vector().normalized(),packet)
	bubble.speed = float(InventoryService.config().combat.bomb_speed)
	bubble.source_actor = self
	bubble.hit_landed.connect(_on_hit_landed)
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = _bubble_spawn.global_position

func weapon_cfg() -> Dictionary:
	return DataDB.get_weapon(GameState.weapon_id)


func max_combo() -> int:
	return int(weapon_cfg().get("combo", 3))


## 连击下一拍：连击窗口内 +1，否则回到第 1 段。
func next_combo() -> int:
	if attack_combo > 0 and attack_combo < max_combo():
		return attack_combo + 1
	return 1


func attack_damage(mult: float = 1.0, magic: bool = false) -> int:
	mult *= AccessoryRules.damage_multiplier(str(weapon_cfg().get("range_type", "")), _clock < _dodge_bonus_until)
	var already_magic := magic or str(weapon_cfg().get("damage_type","physical")) == "magic"
	if GameState.skill_buffs.has("arcane"):
		if already_magic:
			mult *= 1.0+float(GameState.skill_buffs.arcane.normal_attack_already_milk_magic_bonus_pct)/100.0
		return damage_for_type("magic" if already_magic else "physical",mult)
	return damage_for_type("magic" if already_magic else "physical",mult)


## 生成普攻伤害包（Attack 状态调用；末段强击退）。
func build_attack_packet(combo_idx: int) -> DamagePacket:
	var kb := PlayerTuning.ATTACK_KB_FINISH if combo_idx >= max_combo() else PlayerTuning.ATTACK_KB
	var packet := DamagePacket.new(attack_damage(1.0), DamagePacket.DamageType.MAGIC if GameState.skill_buffs.has("arcane") or str(weapon_cfg().get("damage_type","physical")) == "magic" else DamagePacket.DamageType.PHYSICAL,
			kb, global_position, GameState.weapon_id)
	packet.poise_key = StringName("normal:%s:%d" % [GameState.weapon_id,combo_idx])
	packet.origin_actor=self
	packet.normal_poise=WeaponAttributes.poise_damage(weapon_cfg(),combo_idx)
	packet.weapon_ticket=_weapon_ticket
	return packet

## 每段开始冻结武器能力及动能倍率，不把一段的多个受击目标算作多次攻击。
func begin_weapon_attack() -> void:
	if _trait_weapon_id!=str(GameState.weapon_id):reset_weapon_traits()
	_weapon_ticket=WeaponAttackTicket.new()
	_weapon_ticket.weapon=weapon_cfg().duplicate(true)
	_weapon_ticket.attack_speed = float(weapon_cfg().get("attack_speed_multiplier", 1.0)) * (1.0 + AccessoryRules.effect("attack_speed_pct") / 100.0)
	_weapon_ticket.bleeding_multiplier = 1.0 + AccessoryRules.effect("bleeding_damage_pct") / 100.0
	_weapon_ticket.damage_multiplier = take_hunt_bonus()
	var kinetic := WeaponAttributes.effect(_weapon_ticket.weapon,"kinetic")
	if not kinetic.is_empty():
		_weapon_ticket.damage_multiplier *= 1.0 + _kinetic_stacks * float(kinetic.damage_per_stack)

## 只在亲手使目标从未破韧进入破韧时准备追猎。
func target_poise_broken() -> void:
	_hunt_ready = AccessoryRules.effect("next_attack_after_break_pct") > 0.0

## 为下一段普攻或首次造成伤害的技能锁定一次追猎加成。
func take_hunt_bonus() -> float:
	if not _hunt_ready:
		return 1.0
	_hunt_ready = false
	return 1.0 + AccessoryRules.effect("next_attack_after_break_pct") / 100.0

## 闪避完成后开始计算豪情的持续时间。
func on_dodge_completed() -> void:
	_dodge_bonus_until = _clock + AccessoryRules.effect("post_dodge_seconds")

## 攻击结束或被取消时判定挥空，空挥清空切割者的动能。
func finish_weapon_attack() -> void:
	if _weapon_ticket==null:return
	_weapon_ticket.finished=true
	if not _weapon_ticket.landed and not WeaponAttributes.effect(_weapon_ticket.weapon,"kinetic").is_empty():_kinetic_stacks=0
	_weapon_ticket=null

## 换装/死亡清除瞬态能力，避免换回武器继承旧动能或存储过量治疗。
func reset_weapon_traits() -> void:
	_kinetic_stacks=0
	_weapon_heal_fraction=0
	_trait_weapon_id=str(GameState.weapon_id)

## 攻击票据收到实际生命损失后施加已实装能力；占位异常与技能不产生效果。
func weapon_attack_landed(ticket: WeaponAttackTicket, actual_damage: int) -> void:
	var first := not ticket.landed
	ticket.landed=true
	var kinetic := WeaponAttributes.effect(ticket.weapon,"kinetic")
	if first and not ticket.finished and not kinetic.is_empty() and str(ticket.weapon.id)==str(GameState.weapon_id):_kinetic_stacks=mini(_kinetic_stacks+1,int(kinetic.max_stacks))
	var leech := WeaponAttributes.effect(ticket.weapon,"life_steal")
	if leech.is_empty() or actual_damage<=0 or GameState.hp<=0:return
	if GameState.hp>=GameState.hp_max:
		_weapon_heal_fraction=0
		return
	_weapon_heal_fraction += actual_damage * float(leech.ratio) * AccessoryRules.healing_multiplier()
	var heal := floori(_weapon_heal_fraction)
	_weapon_heal_fraction-=heal
	GameState.hp=mini(GameState.hp_max,GameState.hp+heal)

## 玩法和逐帧表现共用已倍率化的普通攻击时序。
func normal_attack_module() -> Dictionary:
	return WeaponRuntime.attack_module(_weapon_ticket.weapon if _weapon_ticket!=null else weapon_cfg(), normal_attack_speed())

## 当前普攻完整时长，包含已冻结的攻速修正。
func normal_attack_duration() -> float:
	return WeaponAttributes.duration(weapon_cfg(), normal_attack_speed())

## HUD读取同一瞬态动能，不复制能力数值。
func weapon_effect_summary() -> String:
	var effect := WeaponAttributes.effect(weapon_cfg(),"kinetic")
	return "动能 %d/%d" % [_kinetic_stacks,int(effect.max_stacks)] if not effect.is_empty() else ""


## 设定普攻判定盒尺寸（来自武器表 hitbox{w,h}）。
## 注意：M1.5 起近战判定已移至 AttackEffect 特效实体，本函数仅为静态节点保留（不再被普攻调用）。
func set_hitbox_size(size: Vector2) -> void:
	var cs := hitbox.get_node("Shape") as CollisionShape2D
	if cs != null and cs.shape is RectangleShape2D:
		cs.shape.size = size


# ============================================================
# 受击结算（HurtboxComponent 回调）
# ============================================================

## 受击入口：无敌 → 0；防御 → 完美/普通/破防三档；否则全额并进硬直。返回最终伤害。
func apply_hit(pkt: DamagePacket) -> int:
	if sm.current_name() == &"Dead":
		return 0
	if is_invulnerable():
		return 0
	if skills.parry(pkt):
		return 0
	var amount := int(pkt.amount)
	var attributes := RPGService.stats()
	var defense := 0.0 if pkt.ignore_defense else float(attributes.defense)
	var constant := float(RPGService.config().base_attributes.defense_constant)
	amount = maxi(0,roundi(amount*(1.0-defense/(defense+constant))*(1.0-float(attributes.damage_reduction)/100.0)))
	amount = roundi(amount*(1.0+float(GameState.skill_buffs.get("frenzy",{}).get("damage_taken_bonus_pct",0))/100.0))
	amount = roundi(amount * (1.0 + AccessoryRules.effect("damage_taken_pct") / 100.0))
	amount = skills.defend(amount,pkt)
	if amount <= 0:
		return 0
	if _shield_hp > 0 and _clock < _shield_until:
		var absorbed := mini(amount,_shield_hp)
		_shield_hp -= absorbed
		amount -= absorbed
		if amount <= 0:
			return 0
	var kb_dir := 1 if global_position.x >= pkt.from_position.x else -1

	if is_guarding and Input.is_action_pressed(&"guard") and is_on_floor() and not pkt.ignore_defense:
		var precise := guard_pose_time < guard_raise_duration()
		var extra := maxf(0,InventoryService.talent_effect("guard_reduce_pct")/100.0-float(CombatMath.guard_config().damage_reduction))
		var r := CombatMath.guard_result(amount, GameState.sta, precise, extra, 1.0 + AccessoryRules.effect("stamina_cost_pct") / 100.0)
		if not WeaponAttributes.effect(weapon_cfg(),"full_guard").is_empty() or AccessoryRules.effect("full_guard") > 0.0:
			r.damage = 0
		GameState.sta = int(r["sta_left"])
		_last_sta_cost = _clock
		if r["perfect"]:
			# 完美格挡：0 伤害 + 反弹 30% + 敌硬直（敌侧 M1 消费）+ 轻屏震
			cam.shake(3.0, 0.12)
			return 0
		if r["break_guard"]:
			amount = _lose_health(int(r.damage))
			if GameState.hp <= 0:
				sm.to(&"Dead")
			else:
				sm.to(&"Hurt", {"stun": PlayerTuning.GUARD_BREAK_STUN, "kb_dir": kb_dir, "break": true})
			return amount
		var dmg := _lose_health(int(r["damage"]))
		if GameState.hp <= 0:
			sm.to(&"Dead")
		else:
			velocity.x = kb_dir * 60.0  # 格挡小击退，不脱防
		return dmg

	amount = _lose_health(amount)
	if GameState.hp <= 0:
		sm.to(&"Dead")
	else:
		sm.to(&"Hurt", {"stun": PlayerTuning.HURT_STUN, "kb_dir": kb_dir})
	return amount


func _lose_health(amount: int) -> int:
	var before: int = GameState.hp
	GameState.hp = maxi(0,before-amount)
	var loss: int = before-GameState.hp
	if loss > 0:
		var feedback := DamageFeedback.for_loss(loss,GameState.hp_max)
		if float(feedback.shake_px) > 0:
			cam.shake(float(feedback.shake_px),float(feedback.seconds))
		EventBus.player_damaged.emit(loss)
	return loss


## 举起至完全就位的整段动画都是精准格挡窗口。
func guard_raise_duration() -> float:
	var cfg := CombatMath.guard_config()
	return float(cfg.raise_frame_seconds)*int(cfg.hold_frame)


func is_invulnerable() -> bool:
	return cinematic_locked or _invuln > 0.0 or dodge_iframe or sm.current_name() == &"Dead"


## 命中反馈：顿帧 0.04s + 屏震（§3.3 命中流程尾段）。
func _on_hit_landed(_target: Node, final_damage: int) -> void:
	skills.on_hit(_target,final_damage)
	if final_damage <= 0:
		return
	var heal := roundi(final_damage*float(RPGService.stats().life_steal)/100.0 * AccessoryRules.healing_multiplier())
	GameState.hp = mini(GameState.hp_max,GameState.hp+heal)
	hitstop(0.04)
	cam.shake(3.0, 0.15)


## 顿帧：短暂降时间流速，输入照常采集（缓冲），恢复后立即执行。
func hitstop(duration: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, true, false, true).timeout.connect(
			func() -> void: Engine.time_scale = 1.0)


# ============================================================
# 状态迁移辅助 / 死亡重生
# ============================================================

## 实际接地、上台辅助或Land状态结算：清除旧宽限并重置空中行动次数。
func on_landed(_impact_vy: float) -> void:
	_coyote = 0.0
	_air_jumps_left = 1 if GameState.abilities.has(&"double_jump") else 0
	_air_dodge_used = false
	_jumped = false
	_used_double = false
	_jump_cut_done = false


## 死亡演出后的重生：回检查点，HP 满、体力/奶力半满（参考书 §3.2）。
func respawn() -> void:
	_boss_force_left = 0
	_coyote = 0.0
	_was_on_floor = false
	GameState.hp = GameState.hp_max
	GameState.sta = int(GameState.sta_max / 2.0)
	GameState.mana = int(GameState.mana_max / 2.0)
	GameState.ammo_units = WeaponAttributes.ammo_capacity()
	_rifle_ready_at = 0.0
	_hunt_ready = false
	_dodge_bonus_until = 0.0
	if GameState.checkpoint_room != GameState.current_room and GameState.checkpoint_position.size() == 2:
		GameState.saved_position = GameState.checkpoint_position.duplicate()
		SaveSystem.restoring = true
		SceneRouter.goto_room(GameState.checkpoint_room)
		return
	global_position = checkpoint_position
	velocity = Vector2.ZERO
	_invuln = 1.0
	gravity_enabled = true
	on_landed(0.0)


# ============================================================
# 内部：计时器 / 落地检测 / 下穿
# ============================================================

func _update_timers(delta: float) -> void:
	_contact_left = maxf(0.0,_contact_left-delta)
	_contact_cooldown = maxf(0.0,_contact_cooldown-delta)
	for k in _buffers.keys():
		_buffers[k] = maxf(0.0, float(_buffers[k]) - delta)
	_coyote = maxf(0.0, _coyote - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	guard_perfect = maxf(0.0, guard_perfect - delta)
	_item_anim_t = maxf(0.0, _item_anim_t - delta)
	if _item_anim_t <= 0.0:
		_item_anim = &""
	# 连击窗口：超时未续拍则重置段数
	var interval := normal_attack_duration()
	if attack_combo > 0 and _clock - _last_attack_time > interval + 0.25:
		attack_combo = 0
	# 体力回复：停手 0.8s 后 12/s（浮点累加器——逐帧 int 舍入会把 0.2/帧 吃成 0，回复永不生效）
	if _clock - _last_sta_cost > PlayerTuning.STA_REGEN_DELAY:
		_sta_acc += float(RPGService.stats().sta_regen) * delta
		if _sta_acc >= 1.0:
			var gain := int(_sta_acc)
			_sta_acc -= float(gain)
			GameState.sta = mini(GameState.sta_max, GameState.sta + gain)
	else:
		_sta_acc = 0.0


## 以物理接地变化恢复跳跃资格，攻击/技能等落地不经过Land也能正确重置。
func _update_floor_state() -> void:
	if is_on_floor():
		if not _was_on_floor and velocity.y >= 0.0:
			on_landed(velocity.y)
	else:
		# 走出平台（非跳跃离地）→ 进入土狼时间
		if _was_on_floor and velocity.y >= 0.0 and not _jumped and _drop_through <= 0.0:
			_coyote = PlayerTuning.COYOTE_TIME
	_was_on_floor = is_on_floor()


## 单向平台规则（制作人规格）：只要在上升过程（velocity.y < 0）就完全不与平台碰撞；
## S 下穿窗口内同样放行；下落/站立时正常站踏。掩码在 move_and_slide 之前更新，
## 保证起跳当帧即生效。
func _update_collision_mask() -> void:
	if velocity.y < 0.0 or _drop_through > 0.0:
		collision_mask = (PlayerTuning.BODY_MASK | 4) & ~128
	else:
		collision_mask = PlayerTuning.BODY_MASK | 4


func _resolve_enemy_contact() -> void:
	if _contact_cooldown > 0 or sm.current_name() == &"Dead":
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var enemy := collision.get_collider()
		if not (enemy is CombatEnemy or enemy is GameEnemy or enemy is CorrumptBoss) or enemy.hp <= 0:
			continue
		var cfg: Dictionary = EncounterRules.config().contact
		var away := signf(global_position.x-enemy.global_position.x)
		if is_zero_approx(away):
			away = -float(facing)
		_contact_velocity = away*float(cfg.bounce_speed)
		_contact_left = float(cfg.bounce_time)
		_contact_cooldown = float(cfg.cooldown)
		velocity.x = _contact_velocity
		if collision.get_normal().y < -0.5:
			velocity.y = -float(cfg.vertical_impulse)
		break


func _update_drop_trigger() -> void:
	# ↓ 键下穿单向平台触发（§3.1 验收 6）
	if _drop_through > 0.0:
		_drop_through -= get_physics_process_delta_time()
		return
	if is_on_floor() and Input.is_action_pressed(&"move_down"):
		var col := get_last_slide_collision()
		if col != null:
			var body := col.get_collider()
			if body is StaticBody2D and (body as StaticBody2D).collision_layer & 128:
				_drop_through = PlayerTuning.DROP_THROUGH_TIME
				_coyote = 0.0
				global_position.y += 2.0


## 上台辅助（mantle，制作人规格）：下落中脚部距某单向平台顶面 ≤ MANTLE_MARGIN 时吸附上台。
## 解决"从平台正下方起跳、脚部差几像素够不到顶面"的穿而不落（上升期不碰撞规则下常见）。
## 仅在本次离地由跳跃造成（_jumped）时生效——从平台边缘走落不会吸附回平台。
func _try_platform_mantle() -> void:
	if velocity.y < 0.0 or is_on_floor() or _drop_through > 0.0 or not _jumped:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var feet := global_position.y + 17.0   ## 脚底（碰撞体 20×34，中心到脚 17px）
	var params := PhysicsShapeQueryParameters2D.new()
	var probe := RectangleShape2D.new()
	probe.size = Vector2(12.0, PlayerTuning.MANTLE_MARGIN + 4.0)
	params.shape = probe
	params.transform = Transform2D(0.0, Vector2(global_position.x, feet + PlayerTuning.MANTLE_MARGIN * 0.5))
	params.collision_mask = 128
	params.collide_with_bodies = true
	params.collide_with_areas = false
	for hit in space.intersect_shape(params, 4):
		var body: Object = hit.get("collider")
		if body is StaticBody2D:
			for child in (body as StaticBody2D).get_children():
				if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
					var rect := (child as CollisionShape2D).shape as RectangleShape2D
					var top: float = (child.global_transform * Vector2(0.0, -rect.size.y * 0.5)).y
					var dist := feet - top
					if dist >= -2.0 and dist <= PlayerTuning.MANTLE_MARGIN:
						global_position.y = top - 17.0   ## 脚部吸附到平台顶面
						velocity.y = 0.0
						_jumped = false
						on_landed(0.0)
						return


func _process(_delta: float) -> void:
	# 受击无敌闪烁
	if _invuln > 0.0 and sm.current_name() != &"Dead":
		modulate.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.03))
	else:
		modulate.a = 1.0


# ============================================================
# 动画驱动（CHR-01 全帧朝右，facing<0 镜像）
# ============================================================

## 每物理帧按当前状态切换动画；资源未注入时跳过（灰盒回退）。
func _update_animation() -> void:
	if sm != null and _presentation_state != sm.current_name():
		_sword_return_combo = attack_combo if _presentation_state == &"Attack" and sm.current_name() == &"Idle" and attack_combo < 3 else 0
		_presentation_state = sm.current_name()
		_presentation_state_since = _clock
	if _external_animation != &"":
		return
	if sprite.sprite_frames == null:
		return
	var sword_ready := sm.current_name() == &"Idle" and weapon_type() == "sword" and _pixel_rig.has_sword_ready_pose() and _item_anim_t <= 0
	if sm.current_name() == &"Skill":
		_pixel_rig.hide()
		sprite.visible = true
		skills.update_actor()
		_sync_weapon_sprite()
		return
	var rig_active := sword_ready or (sm.current_name() == &"Attack" and weapon_type() in ["sword","rifle"])
	_pixel_rig.visible = rig_active
	sprite.visible = not rig_active
	if rig_active:
		_sync_rig_pose()
	var anim := _pick_animation()
	if anim != &"" and sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0
	if sm.current_name() == &"Dodge":
		# 原有人物逐帧完整覆盖延长后的闪避，不改尺寸或像素。
		sprite.pause()
		var progress := clampf((_clock-_presentation_state_since)/PlayerTuning.DODGE_TIME,0,1)
		sprite.frame = mini(int(progress*sprite.sprite_frames.get_frame_count(anim)),sprite.sprite_frames.get_frame_count(anim)-1)
	if sm.current_name() in [&"Guard",&"GuardRelease"]:
		sprite.pause()
		var guard_cfg: Dictionary = _pixel_rig.cfg.guard
		if sm.current_name() == &"Guard":
			sprite.frame = mini(int(guard_pose_time/float(guard_cfg.raise_frame_seconds)),int(guard_cfg.hold_frame))
		else:
			sprite.frame = clampi(ceili(lerpf(float(guard_release_from),-1,guard_pose_time/float(guard_cfg.release_seconds))),0,int(guard_cfg.hold_frame))
	if sm.current_name()==&"Attack":
		sprite.pause()
		var duration := normal_attack_duration()
		var progress := clampf((_clock-_last_attack_time)/duration,0,1)
		sprite.frame=mini(int(progress*sprite.sprite_frames.get_frame_count(anim)),sprite.sprite_frames.get_frame_count(anim)-1)
	_sync_weapon_sprite()


## 播放坐下、休息和起身的逐帧演出；世界暂停时仍推进精灵动画。
func play_presentation_animation(animation: StringName) -> void:
	_external_animation = animation
	_pixel_rig.hide()
	sprite.visible = sprite.sprite_frames != null
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.flip_h = facing < 0
	sprite.play(animation)


## 结束界面演出，恢复角色当前状态的逐帧动画。
func stop_presentation_animation() -> void:
	_external_animation = &""
	sprite.process_mode = Node.PROCESS_MODE_INHERIT
	_update_animation()


func _on_frame_presentation_finished() -> void:
	if _external_animation != &"":
		presentation_animation_finished.emit(_external_animation)


func _sync_rig_pose() -> void:
	_pixel_rig.appearance_id = weapon_appearance_override if weapon_appearance_override!="" else WeaponAppearance.equipped_id(weapon_cfg())
	_pixel_rig.kind = "rifle" if weapon_type() == "rifle" and sm.current_name() == &"Attack" else "sword"
	_pixel_rig.combo = 3 if sm.current_name() == &"Skill" else attack_combo
	_pixel_rig.sword_pose = "ready" if sm.current_name() == &"Idle" else "attack"
	_pixel_rig.ready_elapsed = maxf(0,_clock-_presentation_state_since)
	_pixel_rig.return_combo = _sword_return_combo
	var module := normal_attack_module()
	var duration := float(module.startup)+float(module.active)+float(module.recovery)
	_pixel_rig.progress = clampf((_clock-_last_attack_time)/duration,0,1)
	if _pixel_rig.kind == "sword" and not _pixel_rig.has_sword_frames():
		var elapsed := _clock-_last_attack_time
		var phases: Array = _pixel_rig.cfg.sword.phase_indices
		var phase: float
		if elapsed < float(module.startup):
			phase = float(phases[0])*elapsed/float(module.startup)
		elif elapsed < float(module.startup)+float(module.active):
			phase = lerpf(float(phases[0]),float(phases[1]),(elapsed-float(module.startup))/float(module.active))
		else:
			phase = lerpf(float(phases[1]),float(phases[2]),clampf((elapsed-float(module.startup)-float(module.active))/float(module.recovery),0,1))
		_pixel_rig.progress = phase/float(phases[2])
	_pixel_rig.charge = attack_charge
	_pixel_rig.release_time = ((_clock - _last_attack_time) - float(module.startup)) * normal_attack_speed() if _clock - _last_attack_time >= float(module.startup) else -1.0
	_pixel_rig.aim = aim_vector()
	_pixel_rig.facing = facing
	_pixel_rig.apply_pose()
	if _pixel_rig.kind == "rifle" and aim_vector().length() >= 48:
		var target := global_position+aim_vector()
		for iteration in 3:
			var grip := _pixel_rig.to_global(_pixel_rig._grip-_pixel_rig._anchor)
			_pixel_rig.aim = target-grip
			_pixel_rig.apply_pose()


## 状态 → 动画名映射（动画名与 CHR-01_sprite_frames.tres 内 26 个动作一一对应）。
func _pick_animation() -> StringName:
	# 使用道具的短暂演出（仅自由态时覆盖，不打断攻防动作）
	if _item_anim_t > 0.0:
		var cur := sm.current_name()
		if cur == &"Idle" or cur == &"Run" or cur == &"Land" or cur == &"Fall":
			return _item_anim
	match sm.current_name():
		&"Idle":
			return &"idle"
		&"Run":
			return &"run"
		&"Jump":
			return &"double_jump" if _used_double else (&"fall" if velocity.y >= 0.0 else &"jump")
		&"Fall":
			return &"fall"
		&"Land":
			return &"land"
		&"Dodge":
			return &"air_dodge" if _dodge_air else &"dodge"
		&"Guard":
			return StringName("guard_"+weapon_type())
		&"GuardRelease":
			return StringName("guard_"+weapon_type())
		&"Attack":
			return _attack_anim()
		&"Hurt":
			return &"guard_break" if _hurt_break else &"hurt"
		&"Dead":
			return &"death"
	return &"idle"


## 武器类别决定普攻动画名，剑和锤分别采用三段连击。
func _attack_anim() -> StringName:
	var names: Array = WeaponRuntime.module(weapon_type()).get("animations",["cast"])
	return StringName(names[clampi(attack_combo-1,0,names.size()-1)])


func _draw() -> void:
	if _shield_hp > 0 and _clock < _shield_until:
		draw_circle(Vector2.ZERO,24,Color(0.3,0.65,1.0,0.15))
		draw_arc(Vector2.ZERO,24,0,TAU,48,Color("#a2dbea"),2,true)
	# 精灵帧已注入时不画灰盒（回退路径专用）
	if sprite.visible or (is_instance_valid(_pixel_rig) and _pixel_rig.visible):
		return
	# 灰盒视觉：奶白色圆角方块 + 朝向眼睛 + 状态描边（§3.13）
	var body := Rect2(-10, -17, 20, 34)
	draw_rect(body, Color(0.85, 0.78, 0.66), true)
	draw_rect(body, Color(0.2, 0.16, 0.12), false, 1.5)
	var eye_x := facing * 3.0
	draw_rect(Rect2(-10 + eye_x + 1, -10, 2.5, 4), Color(0.15, 0.12, 0.1))
	draw_rect(Rect2(-10 + eye_x + 5, -10, 2.5, 4), Color(0.15, 0.12, 0.1))


## 当前装备决定使用剑、锤、步枪或杖模组。
func weapon_type() -> String:
	return str(weapon_cfg().get("weapon_type","unarmed"))


## 统一伤害类型入口，人物面板显示值与实际伤害基础一致。
func damage_for_type(kind: String, multiplier: float = 1.0) -> int:
	return roundi(RPGService.attack_power(kind)*multiplier)


## 侧键施放滚轮选中的主动技能。
func try_selected_skill() -> bool:
	if not buffer_peek(&"cast_selected"):
		return false
	var id := SkillLibrary.canonical(InventoryService.equipped_skill(GameState.selected_skill))
	if id == &"" or not try_skill(id):
		return false
	buffer_consume(&"cast_selected")
	_current_skill = id
	sm.to(&"Skill")
	return true


func _sync_weapon_sprite() -> void:
	WeaponRuntime.sync_sprite(sprite)
	if sprite.sprite_frames!=null:
		WeaponAppearance.sync_sprite(sprite,weapon_appearance_override if weapon_appearance_override!="" else WeaponAppearance.equipped_id(weapon_cfg()))


func _update_passive_regeneration(delta: float) -> void:
	if GameState.hp <= 0:
		return
	var attributes := RPGService.stats()
	_hp_regen_acc += float(attributes.hp_regen) * delta * AccessoryRules.healing_multiplier()
	_mana_regen_acc += float(attributes.mana_regen)*delta
	var hp := floori(_hp_regen_acc)
	var mana := floori(_mana_regen_acc)
	_hp_regen_acc -= hp
	_mana_regen_acc -= mana
	GameState.hp = mini(GameState.hp_max,GameState.hp+hp)
	GameState.mana = mini(GameState.mana_max,GameState.mana+mana)


## 装备交换时结束旧武器动作，避免菜单关闭后延续旧判定。
func cancel_weapon_action() -> void:
	reset_weapon_traits()
	clear_action_buffers()
	if sm.current_name() in [&"Attack",&"Skill"]:
		sm.to(&"Idle")
	velocity.x = 0
	_update_animation()
	for child in get_children():
		if child is AttackEffect or child is SwordAttackEffect:
			child.queue_free()
