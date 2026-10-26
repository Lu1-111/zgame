class_name PlayerStates
extends RefCounted
## 全部玩家状态（内部类集中放置，便于整体调连贯性规则）。
## 状态图（参考书 §3.1）：Idle→Run→Jump→Fall→Land→Hurt→Dodge→Guard→Attack→Skill→Dead。
## 连贯性总规则：
##   - 自由态（Idle/Run/Jump/Fall/Land）：任意动作即时衔接（p.try_actions 统一裁决）。
##   - Attack：起手后不可取消；判定窗/后摇可被【连击/闪避/技能】取消（跳不可）。
##   - Skill：弹体发出后可被【闪避/普攻】取消（跳不可）。
##   - Dodge：全程锁定（0.18s 承诺），结束时若仍有缓冲则立即执行。
##   - Guard：可被【普攻/闪避/技能】取消；松键回自由态。

class Idle extends PlayerState:
	const NAME: StringName = &"Idle"

	func tick(delta: float) -> void:
		if p.try_actions():
			return
		if not p.is_on_floor():
			sm.to(&"Fall")
			return
		if absf(p.input_dir()) > 0.01:
			sm.to(&"Run")
			return
		p.velocity.x = move_toward(p.velocity.x, 0.0, PlayerTuning.GROUND_DECEL * delta)


class Run extends PlayerState:
	const NAME: StringName = &"Run"

	func tick(delta: float) -> void:
		if p.try_actions():
			return
		if not p.is_on_floor():
			sm.to(&"Fall")
			return
		var dir: float = p.input_dir()
		if absf(dir) <= 0.01:
			sm.to(&"Idle")
			return
		p.set_facing_by_input(dir)
		p.ground_accelerate(delta)


class Jump extends PlayerState:
	const NAME: StringName = &"Jump"

	func tick(delta: float) -> void:
		# 松键短跳：上升期松开 → 一次性 ×0.45（二段跳免除，保证固定跳高不缩水）
		if p.velocity.y < 0.0 and not Input.is_action_pressed(&"jump") and not p._jump_cut_done:
			p.velocity.y *= PlayerTuning.JUMP_CUT_MULT
			p._jump_cut_done = true
		p.air_accelerate(delta)
		if p.try_actions():
			return
		if p.is_on_floor():
			sm.to(&"Land", {"impact": p.velocity.y})
			return
		if p.velocity.y >= 0.0:
			sm.to(&"Fall")


class Fall extends PlayerState:
	const NAME: StringName = &"Fall"

	func tick(delta: float) -> void:
		p.air_accelerate(delta)
		if p.try_actions():
			return
		if p.is_on_floor():
			sm.to(&"Land", {"impact": p.velocity.y})


class Land extends PlayerState:
	const NAME: StringName = &"Land"
	var _t := 0.0

	func enter(msg: Dictionary) -> void:
		_t = PlayerTuning.LAND_TIME
		p.on_landed(float(msg.get("impact", 0.0)))

	func tick(delta: float) -> void:
		_t -= delta
		if p.try_actions():
			return  # 落地缓冲期间任何输入立即衔接
		if _t <= 0.0:
			sm.to(&"Run" if absf(p.input_dir()) > 0.01 else &"Idle")


class Dodge extends PlayerState:
	const NAME: StringName = &"Dodge"
	var _t := 0.0

	func enter(msg: Dictionary) -> void:
		var dir := float(msg.get("dir", float(p.facing)))
		if absf(dir) < 0.01:
			dir = float(p.facing)
		p.set_facing(int(signf(dir)))
		p.begin_dodge()
		p.gravity_enabled = false  # 闪避期间冻结重力（水平位移承诺）
		p._dodge_air = not p.is_on_floor()  # 选动画：地面闪避 vs 空中闪避
		_t = PlayerTuning.DODGE_TIME
		p.velocity = Vector2(dir * PlayerTuning.DODGE_SPEED, 0.0)
		p.attack_phase = &""
		# 残影特效（FX-B01 dodge_afterimage，纯视觉无判定）：留在起闪位置
		AttackEffect.spawn(get_tree().current_scene, null, self, &"dodge_afterimage",
				p.global_position, Vector2(dir, 0.0), Vector2.ZERO, Vector2.ZERO, 0.0)

	func tick(delta: float) -> void:
		_t -= delta
		var elapsed := PlayerTuning.DODGE_TIME - _t
		p.dodge_iframe = elapsed >= PlayerTuning.DODGE_IFRAME_START and elapsed <= PlayerTuning.DODGE_IFRAME_END
		if _t <= 0.0:
			p.dodge_iframe = false
			p.velocity.x = 0.0  # 取消惯性：闪避结束即停，不带残余滑行
			sm.to(&"Fall" if not p.is_on_floor() else &"Idle")

	func exit() -> void:
		p.dodge_iframe = false
		p.gravity_enabled = true


class Guard extends PlayerState:
	const NAME: StringName = &"Guard"

	func enter(_msg: Dictionary) -> void:
		p.is_guarding = true
		p.guard_pose_time = 0.0
		p.guard_perfect = PlayerTuning.PERFECT_GUARD_WINDOW
		p.velocity.x = 0.0

	func tick(delta: float) -> void:
		p.guard_pose_time += delta
		if not p.is_on_floor():
			sm.to(&"Fall")
			return
		if not Input.is_action_pressed(&"guard"):
			sm.to(&"GuardRelease")
			return
		# 防御中缓慢移动（40%）
		var dir: float = p.input_dir()
		if absf(dir) > 0.01:
			p.set_facing_by_input(dir)
		p.velocity.x = move_toward(p.velocity.x,
				dir * PlayerTuning.MAX_SPEED * PlayerTuning.GUARD_MOVE_MULT,
				PlayerTuning.GROUND_ACCEL * delta)
		# 防御可取消：普攻 / 闪避 / 技能（防反衔接）
		if p.buffer_consume(&"attack") and not p.weapon_cfg().is_empty():
			sm.to(&"Attack", {"combo": p.next_combo()})
			return
		if p.buffer_consume(&"dodge") and p.can_dodge():
			sm.to(&"Dodge", {"dir": dir})
			return
		if p.try_selected_skill():
			return

	func exit() -> void:
		p.is_guarding = false


class GuardRelease extends PlayerState:
	const NAME: StringName = &"GuardRelease"
	func enter(_msg: Dictionary) -> void:
		p.guard_release_from = maxi(0,mini(p.sprite.frame,int(p._pixel_rig.cfg.guard.hold_frame))-1)
		p.guard_pose_time = 0.0
		p.is_guarding = false
	func tick(delta: float) -> void:
		p.guard_pose_time += delta
		p.velocity.x = 0
		if Input.is_action_pressed(&"guard") and p.is_on_floor():
			sm.to(&"Guard")
			return
		if p.guard_pose_time >= float(p._pixel_rig.cfg.guard.release_seconds):
			sm.to(&"Idle" if p.is_on_floor() else &"Fall")


class Attack extends PlayerState:
	const NAME: StringName = &"Attack"
	var _t := 0.0
	var _combo := 1
	var _opened := false
	var _module: Dictionary

	func enter(msg: Dictionary) -> void:
		_combo = clampi(int(msg.get("combo",1)),1,p.max_combo())
		_t = 0.0
		_opened = false
		_module = WeaponRuntime.module(p.weapon_type())
		p.velocity.x = 0.0
		p.attack_charge = 0.0
		p.attack_release_t = -1.0
		p.set_facing(int(signf(p.aim_vector().x)))
		p.attack_combo = _combo
		p.attack_chain = false
		p._last_attack_time = p._clock

	func tick(delta: float) -> void:
		_t += delta
		p.velocity.x = 0.0
		if p.weapon_type() == "rifle":
			p.set_facing(int(signf(p.aim_vector().x)))
		var active_start := float(_module.get("startup",PlayerTuning.ATK_STARTUP))
		var active_end := active_start+float(_module.get("active",PlayerTuning.ATK_ACTIVE))
		p.attack_phase = &"startup" if _t < active_start else (&"active" if _t < active_end else &"recovery")
		if not _opened and _t >= active_start:
			_opened = true
			if p.weapon_is_ranged():
				p.spawn_weapon_projectile()
			else:
				p.spawn_melee_effect(_combo)
		if _t >= active_end:
			if _combo < p.max_combo() and p.attack_chain:
				sm.to(&"Attack",{"combo":_combo+1})
				return
			if p.buffer_peek(&"dodge") and p.can_dodge():
				p.buffer_consume(&"dodge")
				sm.to(&"Dodge",{"dir":p.input_dir()})
				return
			if p.try_selected_skill():
				return
		if _t >= active_end+float(_module.get("recovery",PlayerTuning.ATK_RECOVERY)):
			# 步枪单次按下只开火一次；长按保留双手瞄准姿势，松键后结束。
			if p.weapon_type() == "rifle" and Input.is_action_pressed(&"attack"):
				return
			_finish()

	func _finish() -> void:
		sm.to(&"Fall" if not p.is_on_floor() else (&"Run" if absf(p.input_dir())>0.01 else &"Idle"))

	func exit() -> void:
		p.hitbox.deactivate()
		p.attack_phase = &""
		p.attack_chain = false


class Skill extends PlayerState:
	const NAME: StringName = &"Skill"
	var _t := 0.0
	var _fired := false

	func enter(_msg: Dictionary) -> void:
		_t = 0.0
		_fired = false
		if p._current_skill == &"skill_cleave":
			p._last_attack_time = p._clock
		p.set_facing(int(signf(p.aim_vector().x)))  # M1.5 鼠标自动转向：施法朝鼠标方位
		p.velocity.x = 0.0  # 施放期间锁定水平位移

	func tick(delta: float) -> void:
		_t += delta
		p.velocity.x = 0.0
		if not _fired and _t >= PlayerTuning.SKILL_STARTUP:
			_fired = true
			p.fire_skill(p._current_skill)  # 分派：奶泡弹/治愈之乳/挤奶冲击
		if _fired:
			# ---- 弹已出手/效果已结算：可被闪避/普攻取消后摇 ----
			if p.buffer_peek(&"dodge") and p.can_dodge():
				p.buffer_consume(&"dodge")
				sm.to(&"Dodge", {"dir": p.input_dir()})
				return
			if p.buffer_peek(&"attack") or p.attack_chain:
				sm.to(&"Attack", {"combo": p.next_combo()})
				return
		if _t >= PlayerTuning.SKILL_STARTUP + PlayerTuning.SKILL_RECOVERY:
			sm.to(&"Fall" if not p.is_on_floor()
					else (&"Run" if absf(p.input_dir()) > 0.01 else &"Idle"))

	func exit() -> void:
		p.hitbox.deactivate()  # 静态判定节点兜底关闭（slam 判定已走 AttackEffect，自会关闭）


class Hurt extends PlayerState:
	const NAME: StringName = &"Hurt"
	var _t := 0.0

	func enter(msg: Dictionary) -> void:
		_t = float(msg.get("stun", PlayerTuning.HURT_STUN))
		p._invuln = PlayerTuning.HURT_INVULN
		p._hurt_break = bool(msg.get("break", false))  # 选动画：破防 vs 普通受击
		var dir := int(msg.get("kb_dir", 1))
		if dir != 0:
			p.velocity = Vector2(dir * PlayerTuning.HURT_KNOCKBACK, -100.0)

	func tick(delta: float) -> void:
		_t -= delta
		p.velocity.x = move_toward(p.velocity.x, 0.0, PlayerTuning.GROUND_DECEL * delta * 0.5)
		if _t <= 0.0:
			sm.to(&"Fall" if not p.is_on_floor() else &"Idle")


class Dead extends PlayerState:
	const NAME: StringName = &"Dead"
	var _t := 0.0

	func enter(_msg: Dictionary) -> void:
		_t = 0.0
		p.gravity_enabled = false
		p.velocity = Vector2.ZERO
		p.hitbox.deactivate()
		EventBus.player_died.emit()  # TODO(M2)：1.5s 演出 + 奶滴掉落

	func tick(delta: float) -> void:
		_t += delta
		if _t >= 1.5:
			p.respawn()
			sm.to(&"Idle")
