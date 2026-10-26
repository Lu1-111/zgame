class_name AttackEffect
extends Node2D
## 攻击特效实体（M1.5）：FX-B01 特效视觉 + 自带接触判定框——伤害结算在特效所在位置，
## 不再使用玩家身上的静态隐形判定框（参考书 §3.3 命中流程的实体化落地）。
## 由玩家普攻/技能发射；active_time <= 0 时为纯视觉（用于投射物命中点的冲击特效）。
##
## 视觉层：_ready 时实例化 FX-B01 的 EffectPlayer（FX_PLAYER_SCENE）播放 _effect_name，
## 播完（effect_completed）后整体释放；素材缺失或动作未知时回退 _draw() 灰盒占位。
##
## 契约（冻结，Gameplay 侧只能按此调用；视觉与容错由 FX 侧精修）：
##   var fx := AttackEffect.spawn(parent, packet, source, effect_name, global_pos,
##           aim, hitbox_size, hitbox_offset, active_time)
##   fx.hit_landed.connect(receiver)   # 命中反馈（顿帧/屏震）由调用方连接

signal hit_landed(target: Node, final_damage: int)

const FX_PLAYER_SCENE := "res://assets/PROCESSED/effects/FX-B01/v001/godot/EffectPlayer.tscn"
const HIT_FX_PHYSICAL := &"physical_hit"   ## 物理命中冲击（FX-B01）
const HIT_FX_MAGIC := &"magic_hit"         ## 法术命中冲击（FX-B01）

## FX 路径防泄漏兜底：effect_completed 迟迟不到（异常/未来加入循环动作）时到时强制释放。
## 非玩法数值不进数据表；本包最长动作 0.5s，3s 为极宽松上限。
const _FX_WATCHDOG_SEC := 3.0

var packet: DamagePacket = null
var source_actor: Node = null

var _effect_name: StringName = &""
var _aim := Vector2.RIGHT
var _hitbox_size := Vector2(44, 36)
var _hitbox_offset := Vector2.ZERO
var _active_time := 0.12
var _elapsed := 0.0
var _hitbox: HitboxComponent = null
var _effect_player: Node2D = null   ## FX-B01 播放组件实例；素材缺失/播放失败时为 null（走灰盒）
var _fx_playing := false            ## true = EffectPlayer 已接管视觉（灰盒隐藏）
var _fx_done := false               ## true = FX 已自然播完（待与判定窗收口后释放节点）


## 便捷发射：实例化、配置并挂入 parent，返回实体（供连接 hit_landed）。
static func spawn(parent: Node, p_packet: DamagePacket, p_source: Node, effect_name: StringName,
		global_pos: Vector2, aim: Vector2, hitbox_size: Vector2, hitbox_offset: Vector2,
		active_time: float) -> AttackEffect:
	var fx: AttackEffect = AttackEffect.new()
	fx.packet = p_packet
	fx.source_actor = p_source
	fx._effect_name = effect_name
	fx._aim = aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
	fx._hitbox_size = hitbox_size
	fx._hitbox_offset = hitbox_offset
	fx._active_time = active_time
	parent.add_child(fx)
	fx.global_position = global_pos
	return fx


## 纯视觉命中冲击（投射物命中点/墙上消散点调用；无判定框）。
static func play_impact(parent: Node, global_pos: Vector2, is_magic: bool) -> void:
	var name := HIT_FX_MAGIC if is_magic else HIT_FX_PHYSICAL
	if parent == null:
		return
	spawn(parent, null, null, name, global_pos, Vector2.RIGHT, Vector2.ZERO, Vector2.ZERO, 0.0)


func _ready() -> void:
	if _active_time > 0.0 and packet != null:
		_hitbox = HitboxComponent.new()
		_hitbox.name = "HitboxArea"
		_hitbox.source_actor = source_actor
		_hitbox.position = _hitbox_offset
		var cs := CollisionShape2D.new()
		cs.name = "Shape"
		var shape := RectangleShape2D.new()
		shape.size = _hitbox_size
		cs.shape = shape
		_hitbox.add_child(cs)
		add_child(_hitbox)
		_hitbox.activate(packet)
		_hitbox.hit_landed.connect(func(t: Node, d: int) -> void: hit_landed.emit(t, d))
	_setup_visual()


## 接入 FX-B01 视觉层：实例化 EffectPlayer 挂为子节点并播放 _effect_name
## （镜像按 _aim.x < 0，锚点由 EffectPlayer 自理，本地原点摆放）。
## 资源缺失或动作未知时保持 _draw() 灰盒回退，绝不阻断 spawn。
func _setup_visual() -> void:
	if _effect_name in [&"sword_slash",&"bow_release",&"staff_cast"]:
		var generated := WeaponVFX.new()
		generated.kind = {&"sword_slash":"sword",&"bow_release":"arrow",&"staff_cast":"staff"}[_effect_name]
		generated.scale.x = -1.0 if _aim.x < 0 else 1.0
		add_child(generated)
		_effect_player = generated
		_fx_playing = true
		generated.finished.connect(func() -> void: _fx_done = true)
		return
	if not ResourceLoader.exists(FX_PLAYER_SCENE):
		return   # 素材缺失：保留灰盒回退，不报错
	var scene: PackedScene = load(FX_PLAYER_SCENE)
	if scene == null:
		return
	var player := scene.instantiate() as Node2D
	if player == null:
		return
	player.position = Vector2.ZERO
	add_child(player)
	_effect_player = player
	# 父节点已在场景树内，add_child 会同步触发 EffectPlayer 的 _ready，可直接播放
	if player.play_effect(_effect_name, _aim.x < 0.0, 1.0):
		_fx_playing = true
		player.effect_completed.connect(_on_effect_completed, CONNECT_ONE_SHOT)
		queue_redraw()   # 隐藏灰盒占位
	else:
		# 未知动作名/倍率非法：丢弃播放器，回退灰盒
		_effect_player = null
		player.queue_free()


## EffectPlayer 自然播完回调（一次性动画结束必发）；节点释放统一交给 _physics_process 收口。
func _on_effect_completed(_completed: StringName) -> void:
	_fx_done = true


## 定向技能将视觉和判定一起旋转至鼠标方向，普攻不调用此接口。
func orient_to_aim() -> void:
	rotation = _aim.angle()
	if _effect_player is WeaponVFX:
		_effect_player.scale.x = 1.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var hitbox_closed := _hitbox == null or _elapsed >= _active_time
	if _hitbox != null and hitbox_closed:
		_hitbox.deactivate()
	if _fx_playing:
		# FX 路径：特效播完且判定窗收口后释放；watchdog 兜底防完成信号丢失导致节点泄漏
		if _fx_done and hitbox_closed:
			queue_free()
		elif _elapsed >= _FX_WATCHDOG_SEC:
			queue_free()
	elif _elapsed >= _lifetime():
		# 灰盒回退路径：沿用本地计时释放
		queue_free()


func _lifetime() -> float:
	return maxf(_active_time, 0.35)  # 纯视觉冲击至少播完 0.35s


## 灰盒回退：EffectPlayer 未接入/素材缺失/动作未知时的可见占位（青色框 = 判定域，白色点 = 中心）。
func _draw() -> void:
	if _fx_playing:
		return   # FX 已接管视觉，不再绘制灰盒
	if _active_time <= 0.0:
		draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.8))
		return
	var col := Color(0.5, 0.9, 1.0, 0.55) if packet != null and packet.type == DamagePacket.DamageType.MAGIC \
			else Color(1.0, 0.85, 0.4, 0.55)
	draw_rect(Rect2(_hitbox_offset - _hitbox_size / 2.0, _hitbox_size), col, true)
	draw_circle(_hitbox_offset, 3.0, Color(1, 1, 1, 0.9))


## 校准武器特效时序；砸地特效的可见最下端与角色脚底平齐。
func align_weapon_visual(rate: float, ground_contact: bool = false) -> void:
	if _effect_player == null:
		return
	if _effect_player is WeaponVFX:
		_effect_player.set_rate(rate)
	else:
		_effect_player.play_effect(_effect_name,_aim.x<0,rate)
		if ground_contact:
			var visual := _effect_player.get_node("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
			var bottom := 0.0
			for index in visual.sprite_frames.get_frame_count(_effect_name):
				var texture := visual.sprite_frames.get_frame_texture(_effect_name,index)
				var bounds := texture.get_image().get_used_rect()
				bottom = maxf(bottom,float(bounds.end.y)+visual.offset.y)
			_effect_player.position.y = -bottom
