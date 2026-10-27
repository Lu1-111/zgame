class_name Player
extends CharacterBody2D
## 玩家控制器（M1，参考书 §3.1）：移动/跳跃三件套/二段跳/闪避/防御/普攻/技能/受击/死亡。
## 数值来源：手感参数 = PlayerTuning（计划书 §3.1 表，契约约定手感不进数据表）；
## 武器/技能数值 = DataDB（data/weapons.json、data/skills.json）；
## 三资源（HP/STA/奶力）权威在 GameState，本脚本只做读写与规则结算。

signal presentation_animation_finished(animation: StringName)

const ANIMATION_MODE := preload("res://scripts/player/character_animation_mode.gd")
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
var sm: StateMachine
var checkpoint_position := Vector2.ZERO
var is_guarding := false            ## Guard 状态维护（供受击结算/绘制）
var guard_pose_time := 0.0
var guard_release_from := 0
var guard_perfect := 0.0            ## 完美格挡剩余窗口
var dodge_iframe := false           ## Dodge 状态维护
var attack_combo := 0               ## 当前连击段（0=未在连击中）
var attack_chain := false           ## 连击中再按攻击 → 下一拍（深度 1 的动作队列）
var attack_charge := 0.0
var attack_release_t := -1.0
var _hp_regen_acc := 0.0
var _mana_regen_acc := 0.0
var _contact_left := 0.0
var _contact_cooldown := 0.0
var _contact_velocity := 0.0
var _pixel_rig: PixelHeroRig
var _skeletal_rig: Node2D
var _animation_backend := "frames"
var _presentation_state: StringName = &""
var _presentation_state_since := 0.0
var _external_animation: StringName = &""
var _external_completed_time := 0.0
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
var _skill_cfgs: Dictionary = {}   ## 技能 id → 配置（skill_bubble/heal/slam，来自 DataDB）
var _skill_ready: Dictionary = {}  ## 技能 id → 冷却就绪时刻（_clock 秒）
var _current_skill: StringName = &"skill_bubble"  ## 正在施放的技能（Skill 状态与动画用）
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
	set_animation_backend(ANIMATION_MODE.current())


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
	_clock += delta
	_update_timers(delta)
	_update_passive_regeneration(delta)
	_update_input()
	sm.tick(delta)
	if _contact_left > 0:
		velocity.x = _contact_velocity
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


# ============================================================
# 输入与缓冲
# ============================================================

## 水平输入轴。
func input_dir() -> float:
	return Input.get_axis(&"move_left", &"move_right")


## 把 just_pressed 动作写入缓冲（普攻在连击中走专用 1 槽 chain 标记）。
func _update_input() -> void:
	if GameUI.gameplay_input_blocked():
		clear_action_buffers()
		return
	for action in [&"jump",&"dodge",&"attack",&"cast_selected"]:
		if Input.is_action_just_pressed(action):
			if action == &"attack" and GameUI.pointer_over_interface():
				continue
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
	if buffer_peek(&"attack") and not weapon_cfg().is_empty():
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
	velocity.x = move_toward(velocity.x, dir * PlayerTuning.MAX_SPEED * (1.0 + InventoryService.talent_effect("move_speed_pct") / 100.0),
			(PlayerTuning.GROUND_ACCEL if absf(dir) > 0.01 else PlayerTuning.GROUND_DECEL) * delta)


## 空中加减速。
func air_accelerate(delta: float) -> void:
	var dir := input_dir()
	velocity.x = move_toward(velocity.x, dir * PlayerTuning.MAX_SPEED * (1.0 + InventoryService.talent_effect("move_speed_pct") / 100.0),
			(PlayerTuning.AIR_ACCEL if absf(dir) > 0.01 else PlayerTuning.AIR_DECEL) * delta)


func set_facing(v: int) -> void:
	if v == 0:
		return
	facing = v
	$AttackPivot.scale.x = float(v)


func set_facing_by_input(dir: float) -> void:
	set_facing(int(signf(dir)))


## 瞄准向量（M1.5 鼠标自动转向）：鼠标世界坐标 − 玩家中心；
## 距离 <4px（鼠标贴身/无输入设备）时回退当前朝向，避免方向抖动。
func aim_vector() -> Vector2:
	var v := get_global_mouse_position() - global_position
	return v if v.length() >= 4.0 else Vector2(float(facing), 0.0)


# ============================================================
# 跳跃 / 闪避 / 技能 条件与执行
# ============================================================

## 地面跳（含土狼时间）。
func try_ground_jump() -> bool:
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
	_used_double = true
	velocity.y = minf(velocity.y, -PlayerTuning.DOUBLE_JUMP_VELOCITY)
	_jump_cut_done = true
	return true


func can_dodge() -> bool:
	if _dodge_cd > 0.0:
		return false
	if not is_on_floor() and _air_dodge_used:
		return false
	return GameState.sta >= PlayerTuning.DODGE_STA_COST


## 扣体力（不足返回 false）；成功则刷新体力回复计时。
func pay_sta(v: int) -> bool:
	if GameState.sta < v:
		return false
	GameState.sta -= v
	_last_sta_cost = _clock
	return true


## 闪避起手结算（Dodge 状态 enter 时调用）：扣体力、进冷却、记空中次数。
func begin_dodge() -> void:
	pay_sta(PlayerTuning.DODGE_STA_COST)
	_dodge_cd = PlayerTuning.DODGE_COOLDOWN * (1.0 + InventoryService.talent_effect("dodge_cooldown_pct") / 100.0)
	if not is_on_floor():
		_air_dodge_used = true


## 技能施放条件：已解锁且冷却完毕，体力与奶力同时满足后原子扣除。
func try_skill(skill_id: StringName = &"skill_bubble") -> bool:
	if not InventoryService.skill_unlocked(skill_id):
		return false
	var cfg: Dictionary = _skill_cfgs.get(skill_id,{})
	if cfg.is_empty() or str(cfg.get("category","active")) != "active" or float(_skill_ready.get(skill_id,0.0)) > _clock:
		return false
	var mana := InventoryService.skill_mana_cost(skill_id)
	var stamina := InventoryService.skill_stamina_cost(skill_id)
	if GameState.mana < mana or GameState.sta < stamina:
		return false
	GameState.mana -= mana
	pay_sta(stamina)
	_skill_ready[skill_id] = _clock + float(cfg.cooldown)
	return true


## 技能生效点（Skill 状态起手结束调用）：按技能 id 分派效果。
func fire_skill(id: StringName) -> void:
	var cfg: Dictionary = _skill_cfgs.get(id, {})
	match String(id):
		"skill_cleave":
			var wave := SwordWave.new()
			wave.specification = cfg.presentation
			wave.direction = aim_vector().normalized()
			wave.packet = DamagePacket.new(damage_for_type("physical",float(cfg.damage_mult)),DamagePacket.DamageType.PHYSICAL,float(cfg.knockback),global_position,id)
			wave.source_actor = self
			wave.hit_landed.connect(_on_hit_landed)
			var socket: Array = cfg.presentation.spawn_offset
			var point := global_position+Vector2(float(socket[0])*facing,float(socket[1]))
			get_tree().current_scene.add_child(wave)
			wave.global_position = point
		"skill_bubble":
			spawn_bubble()
		"skill_heal":
			var pct := float(cfg.get("heal_pct", 30))
			GameState.hp = mini(GameState.hp_max, GameState.hp + int(GameState.hp_max * pct / 100.0))
		"skill_slam":
			# 挤奶冲击：伤害判定实体化为 AttackEffect（64×48 法术判定窗 0.12s）
			spawn_slam_effect()
		"skill_starfall":
			var rain := Node2D.new()
			rain.set_script(load("res://scripts/player/starfall_effect.gd"))
			rain.set("source",self)
			rain.set("packet",DamagePacket.new(attack_damage(float(cfg.damage_mult),true),DamagePacket.DamageType.MAGIC,PlayerTuning.SKILL_KB,global_position,id))
			get_tree().current_scene.add_child(rain)
			var aim := get_global_mouse_position() - global_position
			rain.global_position = global_position + aim.limit_length(float(InventoryService.config().combat.starfall_cast_range))
		"skill_shield":
			_shield_hp = int(cfg.get("absorb",0))
			_shield_until = _clock + float(cfg.get("duration",0))


## 生成奶泡弹投射物（skill_bubble）。
func spawn_bubble() -> void:
	var bubble := BUBBLE_SCENE.instantiate()
	var cfg: Dictionary = _skill_cfgs.get(&"skill_bubble", {})
	var pkt := DamagePacket.new(attack_damage(float(cfg.get("damage_mult", 1.0)),true),
			DamagePacket.DamageType.MAGIC, PlayerTuning.SKILL_KB,
			global_position, &"skill_bubble")
	bubble.setup(aim_vector().normalized(), pkt)
	bubble.source_actor = self
	bubble.hit_landed.connect(_on_hit_landed)
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = _bubble_spawn.global_position


## 当前武器是否远程（决定普攻走特效实体还是投射物）。
func weapon_is_ranged() -> bool:
	return String(weapon_cfg().get("range_type", "melee")) == "ranged"


## 步枪与奶杖远程普攻，枪口、子弹和瞄准使用同一组坐标。
func spawn_weapon_projectile(_charge: float = 1.0) -> void:
	var w := weapon_cfg()
	var proj: Dictionary = w.get("projectile",{})
	var kind := weapon_type()
	var module := WeaponRuntime.module(kind)
	var damage_type := DamagePacket.DamageType.MAGIC if str(w.get("damage_type","physical")) == "magic" else DamagePacket.DamageType.PHYSICAL
	var packet := DamagePacket.new(attack_damage(),damage_type,PlayerTuning.ATTACK_KB,global_position,GameState.weapon_id)
	var bullet := BUBBLE_SCENE.instantiate()
	bullet.setup(aim_vector().normalized(),packet)
	bullet.visual_kind = "bullet" if kind == "rifle" else "staff"
	bullet.speed = float(proj.get("speed",380))
	bullet.source_actor = self
	bullet.hit_landed.connect(_on_hit_landed)
	var socket: Array = module.get("socket",[24,-9])
	var point := global_position+Vector2(float(socket[0])*facing,float(socket[1]))
	if kind == "rifle" and uses_skeletal_animation():
		_sync_skeletal_pose()
		point = _skeletal_rig.call("muzzle_global_position")
		bullet.setup(_skeletal_rig.call("firing_direction_global"),packet)
	elif kind == "rifle" and is_instance_valid(_pixel_rig):
		_sync_rig_pose()
		point = _pixel_rig.muzzle_global_position()
		bullet.setup(_pixel_rig.firing_direction_global(),packet)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = point
	AttackEffect.spawn(get_tree().current_scene,null,self,&"rifle_shot" if kind == "rifle" else &"staff_cast",point,bullet.dir,Vector2.ZERO,Vector2.ZERO,0)


## 近战普攻特效实体（M1.5 伤害判定实体化）：判定框随特效发射、伤害结算在特效位置；
## 玩家身上的静态 $AttackPivot/Hitbox 不再激活（判定已移至 AttackEffect，节点保留兼容）。
func spawn_melee_effect(combo_idx: int) -> void:
	var module := WeaponRuntime.module(weapon_type())
	var index := clampi(combo_idx-1,0,module.sockets.size()-1)
	var raw: Array = module.sockets[index]
	var socket := Vector2(float(raw[0])*facing,float(raw[1]))
	var cfg: Dictionary = weapon_cfg().get("hitbox",{})
	var raw_offset: Array = module.hitbox_offsets[index]
	var fx := AttackEffect.spawn(self,build_attack_packet(combo_idx),self,melee_effect_name(combo_idx),global_position+socket,Vector2(float(facing),0),Vector2(float(cfg.get("w",44)),float(cfg.get("h",36))),Vector2(float(raw_offset[0])*facing,float(raw_offset[1])),float(module.active))
	fx.align_weapon_visual(float(module.effect_rate),weapon_type() == "hammer" and combo_idx == 3)
	fx.hit_landed.connect(_on_hit_landed)


## 挤奶冲击特效实体（skill_slam 判定实体化）：前方 64×48 法术判定窗，数值读 skills.json。
func spawn_slam_effect() -> void:
	var cfg: Dictionary = _skill_cfgs.get(&"skill_slam",{})
	var raw: Array = WeaponRuntime.module("hammer").sockets[2]
	var socket := Vector2(float(raw[0])*facing,float(raw[1]))
	var fx := AttackEffect.spawn(self,DamagePacket.new(damage_for_type("magic",float(cfg.damage_mult)),DamagePacket.DamageType.MAGIC,float(cfg.get("knockback",200)),global_position,&"skill_slam"),self,&"hammer_slam_3",global_position+socket,Vector2(float(facing),0),Vector2(64,48),Vector2(0,-20),PlayerTuning.ATK_ACTIVE)
	fx.align_weapon_visual(2.0,true)
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


## 篝火恢复全部技能冷却。
func reset_cooldowns() -> void:
	_skill_ready.clear()
	_dodge_cd = 0.0


## HUD 获取指定技能的剩余冷却秒数。
func skill_cooldown(id: StringName) -> float:
	return maxf(0.0,float(_skill_ready.get(id,0.0)) - _clock)


## 点击技能格与键盘共用同一套施法规则。
func cast_ui_skill(id: StringName) -> bool:
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
	return damage_for_type("magic" if magic or str(weapon_cfg().get("damage_type","physical")) == "magic" else "physical",mult)


## 生成普攻伤害包（Attack 状态调用；末段强击退）。
func build_attack_packet(combo_idx: int) -> DamagePacket:
	var kb := PlayerTuning.ATTACK_KB_FINISH if combo_idx >= max_combo() else PlayerTuning.ATTACK_KB
	return DamagePacket.new(attack_damage(1.0), DamagePacket.DamageType.PHYSICAL,
			kb, global_position, GameState.weapon_id)


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
	var amount := int(pkt.amount)
	var attributes := RPGService.stats()
	var defense := float(attributes.defense)
	var constant := float(RPGService.config().base_attributes.defense_constant)
	amount = maxi(0,roundi(amount*(1.0-defense/(defense+constant))*(1.0-float(attributes.damage_reduction)/100.0)))
	if _shield_hp > 0 and _clock < _shield_until:
		var absorbed := mini(amount,_shield_hp)
		_shield_hp -= absorbed
		amount -= absorbed
		if amount <= 0:
			return 0
	var kb_dir := 1 if global_position.x >= pkt.from_position.x else -1

	if is_guarding and is_on_floor():
		var r := CombatMath.guard_result(amount, GameState.sta, guard_perfect > 0.0)
		GameState.sta = int(r["sta_left"])
		_last_sta_cost = _clock
		if r["perfect"]:
			# 完美格挡：0 伤害 + 反弹 30% + 敌硬直（敌侧 M1 消费）+ 轻屏震
			cam.shake(3.0, 0.12)
			return 0
		if r["break_guard"]:
			GameState.hp = max(0, GameState.hp - amount)
			EventBus.player_damaged.emit(amount)
			sm.to(&"Hurt", {"stun": PlayerTuning.GUARD_BREAK_STUN, "kb_dir": kb_dir, "break": true})
			return amount
		var dmg := int(r["damage"])
		var reduce := InventoryService.talent_effect("guard_reduce_pct")
		if reduce > 0:
			dmg = int(amount * (1.0 - reduce / 100.0))
		GameState.hp = max(0, GameState.hp - dmg)
		EventBus.player_damaged.emit(dmg)
		if GameState.hp <= 0:
			sm.to(&"Dead")
		else:
			velocity.x = kb_dir * 60.0  # 格挡小击退，不脱防
		return dmg

	GameState.hp = max(0, GameState.hp - amount)
	EventBus.player_damaged.emit(amount)
	if GameState.hp <= 0:
		sm.to(&"Dead")
	else:
		sm.to(&"Hurt", {"stun": PlayerTuning.HURT_STUN, "kb_dir": kb_dir})
	return amount


func is_invulnerable() -> bool:
	return _invuln > 0.0 or dodge_iframe or sm.current_name() == &"Dead"


## 命中反馈：顿帧 0.04s + 屏震（§3.3 命中流程尾段）。
func _on_hit_landed(_target: Node, final_damage: int) -> void:
	if final_damage <= 0:
		return
	var heal := roundi(final_damage*float(RPGService.stats().life_steal)/100.0)
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

## 落地结算（Land 状态进入时调用）：重置空中次数与二段跳。
func on_landed(_impact_vy: float) -> void:
	_air_jumps_left = 1 if GameState.abilities.has(&"double_jump") else 0
	_air_dodge_used = false
	_jumped = false
	_used_double = false
	_jump_cut_done = false


## 死亡演出后的重生：回检查点，HP 满、体力/奶力半满（参考书 §3.2）。
func respawn() -> void:
	GameState.hp = GameState.hp_max
	GameState.sta = int(GameState.sta_max / 2.0)
	GameState.mana = int(GameState.mana_max / 2.0)
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
	var interval := float(weapon_cfg().get("attack_interval", 0.55))
	if attack_combo > 0 and _clock - _last_attack_time > interval + 0.25:
		attack_combo = 0
	# 体力回复：停手 0.8s 后 12/s（浮点累加器——逐帧 int 舍入会把 0.2/帧 吃成 0，回复永不生效）
	if _clock - _last_sta_cost > PlayerTuning.STA_REGEN_DELAY:
		_sta_acc += PlayerTuning.STA_REGEN * delta
		if _sta_acc >= 1.0:
			var gain := int(_sta_acc)
			_sta_acc -= float(gain)
			GameState.sta = mini(GameState.sta_max, GameState.sta + gain)
	else:
		_sta_acc = 0.0


func _update_floor_state() -> void:
	if not is_on_floor():
		# 走出平台（非跳跃离地）→ 进入土狼时间
		if _was_on_floor and velocity.y >= 0.0 and not _jumped:
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
		if not (enemy is CombatEnemy or enemy is GameEnemy) or enemy.hp <= 0:
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
		_presentation_state = sm.current_name()
		_presentation_state_since = _clock
	if uses_skeletal_animation():
		sprite.hide()
		sprite.pause()
		_pixel_rig.hide()
		if _external_animation == &"":
			_sync_skeletal_pose()
		return
	if _external_animation != &"":
		return
	if sprite.sprite_frames == null:
		return
	var rig_active := (sm.current_name() == &"Attack" and weapon_type() in ["sword","rifle"]) or (sm.current_name() == &"Skill" and _current_skill == &"skill_cleave")
	_pixel_rig.visible = rig_active
	sprite.visible = not rig_active
	if rig_active:
		_sync_rig_pose()
	var anim := _pick_animation()
	if anim != &"" and sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0
	if sm.current_name() in [&"Guard",&"GuardRelease"]:
		sprite.pause()
		var guard_cfg: Dictionary = _pixel_rig.cfg.guard
		if sm.current_name() == &"Guard":
			sprite.frame = mini(int(guard_pose_time/float(guard_cfg.raise_frame_seconds)),int(guard_cfg.hold_frame))
		else:
			sprite.frame = clampi(ceili(lerpf(float(guard_release_from),-1,guard_pose_time/float(guard_cfg.release_seconds))),0,int(guard_cfg.hold_frame))
	_sync_weapon_sprite()


## 切换展示后端；战斗状态、速度、判定和动作计时保持原样。
func set_animation_backend(mode: String) -> bool:
	var requested := "skeleton" if mode == "skeleton" else "frames"
	var external := get_presentation_animation()
	var external_time := _presentation_external_time()
	if requested == "skeleton" and not _ensure_skeletal_rig():
		ANIMATION_MODE.report_fallback()
		requested = "frames"
	if is_instance_valid(_skeletal_rig):
		_skeletal_rig.call("stop_external")
		_skeletal_rig.visible = requested == "skeleton"
	_animation_backend = requested
	ANIMATION_MODE.select(requested)
	if requested == "skeleton":
		sprite.pause()
		sprite.process_mode = Node.PROCESS_MODE_DISABLED
		sprite.hide()
		_pixel_rig.hide()
		_sync_skeletal_pose()
	else:
		sprite.process_mode = Node.PROCESS_MODE_INHERIT
		# 骨骼模式已暂停旧精灵，返回时从当前状态的实际时序恢复。
		if sprite.sprite_frames != null:
			sprite.play(_pick_animation())
		_update_animation()
		if external == &"" and sm.current_name() not in [&"Guard",&"GuardRelease"]:
			_seek_frame_time(maxf(0,_clock-(_last_attack_time if sm.current_name() == &"Attack" else _presentation_state_since)))
	if external != &"":
		play_presentation_animation(external)
		if uses_skeletal_animation():
			_skeletal_rig.call("seek_external",external_time)
		else:
			_seek_frame_time(external_time)
	queue_redraw()
	return requested == mode


## 当前是否使用原生骨骼展示。
func uses_skeletal_animation() -> bool:
	return _animation_backend == "skeleton" and is_instance_valid(_skeletal_rig)


## 返回当前展示后端，供暂停菜单和测试工具使用。
func get_animation_backend() -> String:
	return _animation_backend


## 返回防御举手的展示帧，避免骨骼模式读取暂停精灵的旧帧。
func guard_visual_frame() -> int:
	if uses_skeletal_animation():
		var guard_cfg: Dictionary = _pixel_rig.cfg.guard
		return mini(int(guard_pose_time/float(guard_cfg.raise_frame_seconds)),int(guard_cfg.hold_frame))
	return sprite.frame


## 切换原生骨骼和关节可视化，不改变游戏状态。
func toggle_skeleton_debug() -> void:
	if uses_skeletal_animation():
		_skeletal_rig.call("toggle_debug")


## 播放休息等界面驱动的演出；世界暂停时仅活动展示器继续运行。
func play_presentation_animation(animation: StringName) -> void:
	if uses_skeletal_animation():
		_sync_skeletal_pose()
	_external_animation = animation
	_external_completed_time = 0.0
	_pixel_rig.hide()
	if uses_skeletal_animation():
		sprite.hide()
		sprite.pause()
		_skeletal_rig.call("play_external",animation)
	else:
		sprite.visible = sprite.sprite_frames != null
		sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		sprite.flip_h = facing < 0
		sprite.play(animation)


## 结束界面演出，恢复当前战斗状态的展示。
func stop_presentation_animation() -> void:
	_external_animation = &""
	_external_completed_time = 0.0
	if is_instance_valid(_skeletal_rig):
		_skeletal_rig.call("stop_external")
	sprite.process_mode = Node.PROCESS_MODE_DISABLED if uses_skeletal_animation() else Node.PROCESS_MODE_INHERIT
	_update_animation()


## 返回当前界面演出名；普通状态机动画不属于外部演出。
func get_presentation_animation() -> StringName:
	if uses_skeletal_animation() and _skeletal_rig.call("is_external_active"):
		return StringName(_skeletal_rig.call("get_external_animation"))
	return _external_animation


func _ensure_skeletal_rig() -> bool:
	if is_instance_valid(_skeletal_rig):
		return true
	var integration: Dictionary = ANIMATION_MODE.configuration().get("integration",{})
	var path := str(integration.get("model_scene","res://scenes/player/skeletal/hero_skeleton_test.tscn"))
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var candidate := packed.instantiate() as Node2D
	if candidate == null or not candidate.has_method("sync_pose"):
		if candidate != null:
			candidate.free()
		return false
	_skeletal_rig = candidate
	_skeletal_rig.name = "SkeletalPresentation"
	_skeletal_rig.position = sprite.position
	add_child(_skeletal_rig)
	if _skeletal_rig.has_method("is_ready_for_animation") and not bool(_skeletal_rig.call("is_ready_for_animation")):
		remove_child(_skeletal_rig)
		_skeletal_rig.queue_free()
		_skeletal_rig = null
		return false
	_skeletal_rig.connect("external_finished",_on_skeletal_presentation_finished)
	return true


func _sync_skeletal_pose() -> void:
	if not uses_skeletal_animation() or sm == null:
		return
	var state := sm.current_name()
	var clip: StringName
	var elapsed := maxf(0,_clock-_presentation_state_since)
	var progress := -1.0
	match state:
		&"Attack":
			clip = StringName("%s_%d" % [weapon_type(),maxi(1,attack_combo)]) if weapon_type() in ["sword","hammer"] else StringName(weapon_type())
			var module := WeaponRuntime.module(weapon_type())
			elapsed = maxf(0,_clock-_last_attack_time)
			progress = clampf(elapsed/(float(module.startup)+float(module.active)+float(module.recovery)),0,1)
		&"Skill":
			clip = &"sword_3" if _current_skill == &"skill_cleave" else &"staff"
		&"Guard":
			clip = &"guard"
			var guard_cfg: Dictionary = _pixel_rig.cfg.guard
			progress = clampf(guard_pose_time/(float(guard_cfg.raise_frame_seconds)*float(guard_cfg.hold_frame)),0,1)
		&"GuardRelease":
			clip = &"guard_lower"
			var guard_cfg: Dictionary = _pixel_rig.cfg.guard
			progress = clampf(1-float(guard_release_from)/float(guard_cfg.hold_frame)+guard_pose_time/float(guard_cfg.release_seconds),0,1)
		&"Dead": clip = &"death"
		&"Jump": clip = &"jump" if velocity.y < 0 else &"fall"
		_: clip = StringName(String(state).to_lower())
	_skeletal_rig.call("sync_pose",clip,elapsed,weapon_type(),attack_combo,aim_vector(),facing,progress)


func _presentation_external_time() -> float:
	if _external_animation == &"":
		return 0.0
	if uses_skeletal_animation():
		return float(_skeletal_rig.call("get_external_time")) if _skeletal_rig.call("is_external_active") else _external_completed_time
	if sprite.sprite_frames == null:
		return 0.0
	var speed := sprite.sprite_frames.get_animation_speed(sprite.animation)
	var elapsed := 0.0
	for index in sprite.frame:
		elapsed += sprite.sprite_frames.get_frame_duration(sprite.animation,index)/speed
	return elapsed+sprite.frame_progress*sprite.sprite_frames.get_frame_duration(sprite.animation,sprite.frame)/speed


func _seek_frame_time(time: float) -> void:
	if sprite.sprite_frames == null:
		return
	var speed := sprite.sprite_frames.get_animation_speed(sprite.animation)
	var remaining := time
	if sprite.sprite_frames.get_animation_loop(sprite.animation):
		var total := 0.0
		for index in sprite.sprite_frames.get_frame_count(sprite.animation):
			total += sprite.sprite_frames.get_frame_duration(sprite.animation,index)/speed
		remaining = fposmod(remaining,maxf(total,0.001))
	for index in sprite.sprite_frames.get_frame_count(sprite.animation):
		var duration := sprite.sprite_frames.get_frame_duration(sprite.animation,index)/speed
		if remaining <= duration:
			sprite.set_frame_and_progress(index,remaining/duration)
			return
		remaining -= duration
	sprite.frame = maxi(0,sprite.sprite_frames.get_frame_count(sprite.animation)-1)


func _on_frame_presentation_finished() -> void:
	if not uses_skeletal_animation() and _external_animation != &"":
		presentation_animation_finished.emit(_external_animation)


func _on_skeletal_presentation_finished(animation: StringName) -> void:
	if uses_skeletal_animation() and _external_animation != &"":
		_external_completed_time = float(_skeletal_rig.call("get_external_time"))
		presentation_animation_finished.emit(animation)


func _sync_rig_pose() -> void:
	_pixel_rig.kind = "rifle" if weapon_type() == "rifle" and sm.current_name() == &"Attack" else "sword"
	_pixel_rig.combo = 3 if sm.current_name() == &"Skill" else attack_combo
	var module := WeaponRuntime.module(_pixel_rig.kind)
	var duration := float(module.startup)+float(module.active)+float(module.recovery)
	_pixel_rig.progress = clampf((_clock-_last_attack_time)/duration,0,1)
	if _pixel_rig.kind == "sword":
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
	_pixel_rig.release_time = maxf(-1,(_clock-_last_attack_time)-float(module.startup)) if _clock-_last_attack_time >= float(module.startup) else -1.0
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
			return &"guard"
		&"GuardRelease":
			return &"guard"
		&"Attack":
			return _attack_anim()
		&"Skill":
			match String(_current_skill):
				"skill_cleave":
					return &"sword_1"
				"skill_heal":
					return &"heal"
				"skill_slam":
					return &"staff_sweep"
				_:
					return &"cast"
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
	if sprite.visible or (is_instance_valid(_pixel_rig) and _pixel_rig.visible) or uses_skeletal_animation():
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
	var id := InventoryService.equipped_skill(GameState.selected_skill)
	if id == &"" or not try_skill(id):
		return false
	buffer_consume(&"cast_selected")
	_current_skill = id
	sm.to(&"Skill")
	return true


func _sync_weapon_sprite() -> void:
	WeaponRuntime.sync_sprite(sprite)


func _update_passive_regeneration(delta: float) -> void:
	if GameState.hp <= 0:
		return
	var attributes := RPGService.stats()
	_hp_regen_acc += float(attributes.hp_regen)*delta
	_mana_regen_acc += float(attributes.mana_regen)*delta
	var hp := floori(_hp_regen_acc)
	var mana := floori(_mana_regen_acc)
	_hp_regen_acc -= hp
	_mana_regen_acc -= mana
	GameState.hp = mini(GameState.hp_max,GameState.hp+hp)
	GameState.mana = mini(GameState.mana_max,GameState.mana+mana)


## 装备交换时结束旧武器动作，避免菜单关闭后延续旧判定。
func cancel_weapon_action() -> void:
	clear_action_buffers()
	if sm.current_name() in [&"Attack",&"Skill"]:
		sm.to(&"Idle")
	velocity.x = 0
	_update_animation()
	for child in get_children():
		if child is AttackEffect:
			child.queue_free()
