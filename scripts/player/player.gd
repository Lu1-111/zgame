class_name Player
extends CharacterBody2D
## 玩家控制器（M1，参考书 §3.1）：移动/跳跃三件套/二段跳/闪避/防御/普攻/技能/受击/死亡。
## 数值来源：手感参数 = PlayerTuning（计划书 §3.1 表，契约约定手感不进数据表）；
## 武器/技能数值 = DataDB（data/weapons.json、data/skills.json）；
## 三资源（HP/STA/奶力）权威在 GameState，本脚本只做读写与规则结算。

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
var guard_perfect := 0.0            ## 完美格挡剩余窗口
var dodge_iframe := false           ## Dodge 状态维护
var attack_combo := 0               ## 当前连击段（0=未在连击中）
var attack_chain := false           ## 连击中再按攻击 → 下一拍（深度 1 的动作队列）
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
	for id in [&"skill_bubble", &"skill_heal", &"skill_slam"]:
		_skill_cfgs[id] = DataDB.get_skill(id)
	_setup_sprite()
	sm = StateMachine.new()
	sm.name = "StateMachine"
	add_child(sm)
	var list: Array = [
		PlayerStates.Idle.new(), PlayerStates.Run.new(),
		PlayerStates.Jump.new(), PlayerStates.Fall.new(),
		PlayerStates.Land.new(), PlayerStates.Dodge.new(),
		PlayerStates.Guard.new(), PlayerStates.Attack.new(),
		PlayerStates.Skill.new(), PlayerStates.Hurt.new(),
		PlayerStates.Dead.new(),
	]
	sm.setup(self, &"Idle", list)
	checkpoint_position = global_position


## 注入 CHR-01 精灵帧；资源缺失时保持 _draw() 灰盒回退（素材容错约定）。
func _setup_sprite() -> void:
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null:
		push_warning("Player：主角精灵帧缺失，回退灰盒色块 —— %s" % SPRITE_FRAMES_PATH)
		sprite.visible = false
		return
	sprite.sprite_frames = frames
	sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	_clock += delta
	_update_timers(delta)
	_update_input()
	sm.tick(delta)
	# 半步重力（leapfrog）：tick 先行（含跳跃脉冲赋速），随后 g·dt/2 → 位移 → 再 g·dt/2，
	# 使离散跳高逼近连续解析值（§3.1 验收 4）；Dodge/Dead 等可整体关闭重力。
	if gravity_enabled:
		_last_g = PlayerTuning.GRAVITY_UP if velocity.y < 0.0 else PlayerTuning.GRAVITY_DOWN
		velocity.y = minf(velocity.y + _last_g * delta * 0.5, PlayerTuning.MAX_FALL)
	_update_collision_mask()   # 位移前更新：上升帧当帧即放行平台
	move_and_slide()
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
	for action in [&"jump", &"dodge", &"attack", &"skill_1", &"skill_3", &"skill_4"]:
		if Input.is_action_just_pressed(action):
			if action == &"attack" and sm.current_name() == &"Attack":
				attack_chain = true
			elif action == &"jump":
				_buffers[action] = PlayerTuning.JUMP_BUFFER
			else:
				_buffers[action] = PlayerTuning.ATTACK_BUFFER
	# 武器切换：即时生效（M2 由背包/装备界面接管）
	if Input.is_action_just_pressed(&"weapon_next"):
		_cycle_weapon()
	# 快捷栏道具：数字键 1–5 使用对应槽位
	for i in 5:
		if Input.is_action_just_pressed(StringName("item_%d" % (i + 1))):
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
	if buffer_peek(&"attack"):
		buffer_consume(&"attack")
		sm.to(&"Attack", {"combo": next_combo()})
		return true
	if buffer_peek(&"skill_1") and try_skill(&"skill_bubble"):
		buffer_consume(&"skill_1")
		_current_skill = &"skill_bubble"
		sm.to(&"Skill")
		return true
	if buffer_peek(&"skill_3") and try_skill(&"skill_heal"):
		buffer_consume(&"skill_3")
		_current_skill = &"skill_heal"
		sm.to(&"Skill")
		return true
	if buffer_peek(&"skill_4") and try_skill(&"skill_slam"):
		buffer_consume(&"skill_4")
		_current_skill = &"skill_slam"
		sm.to(&"Skill")
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
	velocity.x = move_toward(velocity.x, dir * PlayerTuning.MAX_SPEED,
			(PlayerTuning.GROUND_ACCEL if absf(dir) > 0.01 else PlayerTuning.GROUND_DECEL) * delta)


## 空中加减速。
func air_accelerate(delta: float) -> void:
	var dir := input_dir()
	velocity.x = move_toward(velocity.x, dir * PlayerTuning.MAX_SPEED,
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
	_dodge_cd = PlayerTuning.DODGE_COOLDOWN
	if not is_on_floor():
		_air_dodge_used = true


## 技能施放条件（Q=奶泡弹 / R=治愈之乳 / F=挤奶冲击）：冷却完毕且奶力充足。
func try_skill(skill_id: StringName = &"skill_bubble") -> bool:
	var cfg: Dictionary = _skill_cfgs.get(skill_id, {})
	if cfg.is_empty():
		return false
	if float(_skill_ready.get(skill_id, 0.0)) > _clock:
		return false
	var cost := int(cfg.get("mana_cost", 8))
	if GameState.mana < cost:
		return false
	GameState.mana -= cost
	_skill_ready[skill_id] = _clock + float(cfg.get("cooldown", 0.6))
	return true


## 技能生效点（Skill 状态起手结束调用）：按技能 id 分派效果。
func fire_skill(id: StringName) -> void:
	var cfg: Dictionary = _skill_cfgs.get(id, {})
	match String(id):
		"skill_bubble":
			spawn_bubble()
		"skill_heal":
			var pct := float(cfg.get("heal_pct", 30))
			GameState.hp = mini(GameState.hp_max, GameState.hp + int(GameState.hp_max * pct / 100.0))
		"skill_slam":
			# 挤奶冲击：伤害判定实体化为 AttackEffect（64×48 法术判定窗 0.12s）
			spawn_slam_effect()


## 生成奶泡弹投射物（skill_bubble）。
func spawn_bubble() -> void:
	var bubble := BUBBLE_SCENE.instantiate()
	var cfg: Dictionary = _skill_cfgs.get(&"skill_bubble", {})
	var pkt := DamagePacket.new(attack_damage(float(cfg.get("damage_mult", 1.0))),
			DamagePacket.DamageType.MAGIC, PlayerTuning.SKILL_KB,
			global_position, &"skill_bubble")
	bubble.setup(aim_vector().normalized(), pkt)
	bubble.source_actor = self
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = _bubble_spawn.global_position


## 当前武器是否远程（决定普攻走特效实体还是投射物）。
func weapon_is_ranged() -> bool:
	return String(weapon_cfg().get("range_type", "melee")) == "ranged"


## 远程普攻发射（奶弹枪 speed 420 / 星乳法球 speed 260，伤害类型随武器表）。
func spawn_weapon_projectile() -> void:
	var w := weapon_cfg()
	var proj: Dictionary = w.get("projectile", {})
	var type := DamagePacket.DamageType.MAGIC \
			if String(w.get("damage_type", "physical")) == "magic" else DamagePacket.DamageType.PHYSICAL
	var pkt := DamagePacket.new(attack_damage(1.0), type,
			PlayerTuning.ATTACK_KB, global_position, GameState.weapon_id)
	var bubble := BUBBLE_SCENE.instantiate()
	bubble.setup(aim_vector().normalized(), pkt)
	bubble.speed = float(proj.get("speed", 380.0))
	bubble.source_actor = self
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = _bubble_spawn.global_position


## 近战普攻特效实体（M1.5 伤害判定实体化）：判定框随特效发射、伤害结算在特效位置；
## 玩家身上的静态 $AttackPivot/Hitbox 不再激活（判定已移至 AttackEffect，节点保留兼容）。
func spawn_melee_effect(combo_idx: int) -> void:
	var aim := aim_vector()
	var cfg: Dictionary = weapon_cfg().get("hitbox", {})
	var aim_y := clampf(aim.normalized().y * MELEE_FX_OFFSET_Y, -MELEE_FX_OFFSET_Y, MELEE_FX_OFFSET_Y_DOWN)
	# 特效挂玩家节点下（跟随移动），位置=武器持握点；判定框相对武器点前伸
	var weapon_local := Vector2(float(facing) * WEAPON_FX_X, WEAPON_FX_Y + aim_y * 0.5)
	var fx := AttackEffect.spawn(self, build_attack_packet(combo_idx), self,
			melee_effect_name(combo_idx), global_position + weapon_local, aim,
			Vector2(float(cfg.get("w", 44)), float(cfg.get("h", 36))),
			Vector2(float(facing) * MELEE_FX_OFFSET_X, aim_y),
			PlayerTuning.ATK_ACTIVE)
	fx.hit_landed.connect(_on_hit_landed)


## 挤奶冲击特效实体（skill_slam 判定实体化）：前方 64×48 法术判定窗，数值读 skills.json。
func spawn_slam_effect() -> void:
	var cfg: Dictionary = _skill_cfgs.get(&"skill_slam", {})
	var aim := aim_vector()
	var aim_y := clampf(aim.normalized().y * MELEE_FX_OFFSET_Y, -MELEE_FX_OFFSET_Y, MELEE_FX_OFFSET_Y_DOWN)
	var weapon_local := Vector2(float(facing) * WEAPON_FX_X, WEAPON_FX_Y + aim_y * 0.5)
	var fx := AttackEffect.spawn(self,
			DamagePacket.new(attack_damage(float(cfg.get("damage_mult", 1.5))),
					DamagePacket.DamageType.MAGIC, float(cfg.get("knockback", 200.0)),
					global_position, &"skill_slam"),
			self, &"hammer_slam_3", global_position + weapon_local, aim,
			Vector2(64, 48), Vector2(float(facing) * MELEE_FX_OFFSET_X, aim_y),
			PlayerTuning.ATK_ACTIVE)
	fx.hit_landed.connect(_on_hit_landed)


## 武器 + 连击段 → 攻击特效动画名（FX-B01；无专属特效的近战武器借用锤击 1 段）。
func melee_effect_name(combo_idx: int) -> StringName:
	if String(GameState.weapon_id) == "hammer_01":
		match combo_idx:
			1:
				return &"hammer_swing_1"
			2:
				return &"hammer_swing_2"
			_:
				return &"hammer_slam_3"
	return &"hammer_swing_1"


## 调试：T 键按 DataDB 登记顺序循环切换武器（M2 由装备界面接管）。
func _cycle_weapon() -> void:
	var order: Array = DataDB.weapons.keys()
	if order.is_empty():
		return
	var idx := order.find(GameState.weapon_id)
	GameState.weapon_id = StringName(String(order[(idx + 1) % order.size()]))


## 使用快捷栏槽位道具（M1.5 调试通路；M2 接背包/快捷栏正式 UI 与堆叠规则）。
func use_hotbar_slot(slot: int) -> bool:
	if slot < 0 or slot >= GameState.hotbar.size():
		return false
	var item_id := String(GameState.hotbar[slot])
	if item_id.is_empty():
		return false
	for entry in GameState.inventory:
		if entry is Dictionary and String(entry.get("id", "")) == item_id \
				and int(entry.get("count", 0)) > 0:
			return _consume_item(item_id, entry)
	return false


## 扣减背包数量并结算道具效果（效果键见 docs/数据契约.md §4）。
func _consume_item(item_id: String, entry: Dictionary) -> bool:
	var item := DataDB.get_item(StringName(item_id))
	if item.is_empty():
		return false
	entry["count"] = int(entry.get("count", 0)) - 1
	if int(entry["count"]) <= 0:
		GameState.inventory.erase(entry)
	var effect: Dictionary = item.get("effect", {})
	var used_anim := &"cast"
	if effect.has("restore_hp"):
		GameState.hp = mini(GameState.hp_max, GameState.hp + int(effect.get("restore_hp", 0)))
		used_anim = &"heal"
	elif effect.has("restore_mana"):
		GameState.mana = mini(GameState.mana_max, GameState.mana + int(effect.get("restore_mana", 0)))
	elif effect.has("restore_sta"):
		GameState.sta = mini(GameState.sta_max, GameState.sta + int(effect.get("restore_sta", 0)))
	elif effect.has("damage"):
		# 奶弹：投掷物（物理包，效果值即伤害）
		var pkt := DamagePacket.new(int(effect.get("damage", 15)),
				DamagePacket.DamageType.PHYSICAL, PlayerTuning.ATTACK_KB,
				global_position, StringName(item_id))
		var bubble := BUBBLE_SCENE.instantiate()
		bubble.setup(aim_vector().normalized(), pkt)
		bubble.speed = 300.0
		bubble.source_actor = self
		get_tree().current_scene.add_child(bubble)
		bubble.global_position = _bubble_spawn.global_position
	EventBus.item_picked.emit(StringName(item_id), -1)  # count -1 表示消耗（M2 统一信号语义）
	_item_anim = used_anim
	_item_anim_t = 0.35
	return true


# ============================================================
# 武器 / 数值
# ============================================================

func weapon_cfg() -> Dictionary:
	var w := DataDB.get_weapon(GameState.weapon_id)
	return w if not w.is_empty() else DataDB.get_weapon(&"hammer_01")


func max_combo() -> int:
	return int(weapon_cfg().get("combo", 3))


## 连击下一拍：连击窗口内 +1，否则回到第 1 段。
func next_combo() -> int:
	if attack_combo > 0 and attack_combo < max_combo():
		return attack_combo + 1
	return 1


func attack_damage(mult: float = 1.0) -> int:
	return CombatMath.compute_attack(int(weapon_cfg().get("attack", 12)), GameState.level, mult)


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
	global_position = checkpoint_position
	velocity = Vector2.ZERO
	_invuln = 1.0
	gravity_enabled = true
	on_landed(0.0)


# ============================================================
# 内部：计时器 / 落地检测 / 下穿
# ============================================================

func _update_timers(delta: float) -> void:
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
		collision_mask = PlayerTuning.BODY_MASK & ~128
	else:
		collision_mask = PlayerTuning.BODY_MASK


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
	if not sprite.visible:
		return
	var anim := _pick_animation()
	if anim != &"" and sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0


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
			return &"parry" if guard_perfect > 0.0 else &"guard"
		&"Attack":
			return _attack_anim()
		&"Skill":
			match String(_current_skill):
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


## 武器 id → 普攻动画名（连击段仅锤系有 1/2/3 段）。
func _attack_anim() -> StringName:
	var combo_idx := clampi(attack_combo if attack_combo > 0 else 1, 1, 3)
	match String(GameState.weapon_id):
		"hammer_01":
			return StringName("hammer_%d" % combo_idx)
		"milk_gun":
			return &"blaster_fire"
		"milk_staff":
			return &"staff_sweep"
		"star_orb":
			return &"orb_cast"
	return &"hammer_1"


func _draw() -> void:
	# 精灵帧已注入时不画灰盒（回退路径专用）
	if sprite.visible:
		return
	# 灰盒视觉：奶白色圆角方块 + 朝向眼睛 + 状态描边（§3.13）
	var body := Rect2(-10, -17, 20, 34)
	draw_rect(body, Color(0.85, 0.78, 0.66), true)
	draw_rect(body, Color(0.2, 0.16, 0.12), false, 1.5)
	var eye_x := facing * 3.0
	draw_rect(Rect2(-10 + eye_x + 1, -10, 2.5, 4), Color(0.15, 0.12, 0.1))
	draw_rect(Rect2(-10 + eye_x + 5, -10, 2.5, 4), Color(0.15, 0.12, 0.1))
