extends Node
## M1 手感自动化模拟（参考书 §3.1 验收 1/2/4）：固定步长物理模拟。
## 运行：~/.local/bin/godot --headless --path . res://tests/sim_player.tscn
## 退出码 0 = 全过；非 0 = 有失败。与 run_tests.gd 分离（本模拟需要真实物理帧）。

const TOL_APEX := 2.0          ## 跳高误差容忍（验收 4：±2px）
const APEX_EXPECT := 112.36    ## v²/2g = 636²/(2×1800)，制作人调参后跳高（原 56.25 的 2 倍）

var _fails: Array[String] = []
var _passes := 0


func _ready() -> void:
	_run()


func _run() -> void:
	await _frames(3)
	_check_constants()
	var player: CharacterBody2D = _build_world()
	await _frames(5)

	# ---- 验收 4：满跳跳高 56.25px，误差 ≤±2px ----
	var y0 := player.global_position.y
	Input.action_press(&"jump")
	var min_y := y0
	for i in 60:
		await _frames(1)
		min_y = minf(min_y, player.global_position.y)
		if i >= 20:
			break
	Input.action_release(&"jump")
	var apex := y0 - min_y
	_check(absf(apex - APEX_EXPECT) <= TOL_APEX,
			"跳高 %.2fpx（期望 %.2f±%.0f）" % [apex, APEX_EXPECT, TOL_APEX])
	await _settle(player)

	# ---- 验收 2：落地前 ~0.1s 按跳 → 落地瞬间起跳（缓冲）----
	player.global_position = Vector2(100, -30)
	player.velocity = Vector2.ZERO
	await _frames(2)
	var pressed := false
	for i in 40:
		await _frames(1)
		if not pressed and player.velocity.y > 0.0 and player.global_position.y >= -38.0:
			Input.action_press(&"jump")
			pressed = true
		if pressed and player.velocity.y < -300.0:
			break
	Input.action_release(&"jump")
	_check(pressed and player.velocity.y < -300.0,
			"跳跃缓冲：落地前按跳生效（vy=%.0f）" % player.velocity.y)
	await _settle(player)

	# ---- 验收 1a：土狼时间——走出平台 0.03s 后按跳仍起跳 ----
	player.global_position = Vector2(150, -17)
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press(&"move_right")
	var left_ground := false
	for i in 60:
		await _frames(1)
		if not player.is_on_floor():
			left_ground = true
			break
	if left_ground:
		await _frames(2)  # 0.033s < 土狼 0.10s
		Input.action_press(&"jump")
		await _frames(2)
		_check(player.velocity.y < -300.0, "土狼时间：离台 0.03s 内起跳（vy=%.0f）" % player.velocity.y)
		Input.action_release(&"jump")
	else:
		_check(false, "土狼测试前置：未能走出平台")
	Input.action_release(&"move_right")
	await _settle(player)

	# ---- 验收 1b：土狼超时（离台 0.15s 后）按跳不再起跳 ----
	player.global_position = Vector2(150, -17)
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press(&"move_right")
	left_ground = false
	for i in 60:
		await _frames(1)
		if not player.is_on_floor():
			left_ground = true
			break
	if left_ground:
		await _frames(9)  # 0.15s > 土狼 0.10s
		Input.action_press(&"jump")
		var vy_min := 0.0
		for i in 6:
			await _frames(1)
			vy_min = minf(vy_min, player.velocity.y)
		Input.action_release(&"jump")
		_check(vy_min > -50.0, "土狼超时：不再起跳（vy_min=%.0f）" % vy_min)
	else:
		_check(false, "土狼超时测试前置：未能走出平台")
	Input.action_release(&"move_right")
	await _settle(player)

	# ---- 手感回归：松键衰减一次性 / 二段跳免衰减 ----
	# 此刻起授予二段跳（在缓冲/土狼用例之后，避免改变它们"仅单跳"的语义）
	if not GameState.abilities.has(&"double_jump"):
		GameState.abilities.append(&"double_jump")
	# A. 一次性衰减：释放后第一帧 ×0.45，第二帧起纯重力（指数急停则第二帧继续 ×0.45）
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(1)
	var v1 := player.velocity.y
	await _frames(1)
	var v2 := player.velocity.y
	_check(v2 < v1 * 0.6 + 10.0,
			"松键短跳一次性衰减（v1=%.0f v2=%.0f；指数急停 v2≈v1×0.45+30）" % [v1, v2])
	await _settle(player)
	# B. 二段跳点按：免衰减（点按后仍保持显著上升速度多帧）
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(1)
	Input.action_press(&"jump")   # 二段跳（点按）
	await _frames(1)
	Input.action_release(&"jump")
	var min_vy := 0.0
	var vy_third := 0.0
	for i in 4:
		await _frames(1)
		min_vy = minf(min_vy, player.velocity.y)
		if i == 2:
			vy_third = player.velocity.y
	_check(min_vy <= -350.0 and vy_third < -200.0,
			"二段跳免衰减（min vy=%.0f 第3帧=%.0f；指数急停第3帧≈-15）" % [min_vy, vy_third])
	await _settle(player)

	# ---- 回归：普攻/施法绝不命中自己（归属过滤）----
	var hp0: int = GameState.hp
	Input.action_press(&"attack")
	await _frames(16)  # 覆盖起手 0.10s + 判定窗 0.12s + 部分后摇
	Input.action_release(&"attack")
	await _frames(5)
	_check(GameState.hp == hp0, "普攻不命中自己（HP %d → %d）" % [hp0, GameState.hp])
	await _settle(player)
	Input.action_press(&"skill_1")
	await _frames(10)  # 起手 0.08s + 弹体穿身
	Input.action_release(&"skill_1")
	await _frames(15)
	_check(GameState.hp == hp0, "技能弹不命中自己（HP %d → %d）" % [hp0, GameState.hp])
	await _settle(player)

	# ---- 回归：武器切换 / 治愈之乳 / 道具使用 ----
	Input.action_press(&"weapon_next")
	await _frames(2)
	Input.action_release(&"weapon_next")
	_check(String(GameState.weapon_id) == "milk_gun", "T 键切换武器 → milk_gun（实际 %s）" % String(GameState.weapon_id))
	var hp_keep: int = GameState.hp
	Input.action_press(&"attack")
	await _frames(16)  # 远程弹发射 + 穿身
	Input.action_release(&"attack")
	await _frames(8)
	_check(GameState.hp == hp_keep, "远程普攻不命中自己（HP %d → %d）" % [hp_keep, GameState.hp])
	await _settle(player)
	var mana0: int = GameState.mana
	Input.action_press(&"skill_3")  # 治愈之乳：满血不溢出，扣奶力 25
	await _frames(3)
	Input.action_release(&"skill_3")
	await _frames(20)
	_check(GameState.mana == mana0 - 25, "治愈之乳扣奶力 25（%d → %d）" % [mana0, GameState.mana])
	_check(GameState.hp == hp_keep, "满血时治愈不溢出（HP %d）" % GameState.hp)
	await _settle(player)
	GameState.inventory = [
		{"id": "potion_mana", "count": 1},
		{"id": "milk_bomb", "count": 1},
	]
	GameState.hotbar = ["", "potion_mana", "", "milk_bomb", ""]
	Input.action_press(&"item_2")
	await _frames(2)
	Input.action_release(&"item_2")
	await _frames(3)
	_check(GameState.mana == mana0 - 5, "奶力药剂 +20（MANA=%d）" % GameState.mana)
	Input.action_press(&"item_4")
	await _frames(2)
	Input.action_release(&"item_4")
	await _frames(12)
	_check(GameState.hp == hp_keep, "投掷奶弹不命中自己（HP %d）" % GameState.hp)
	_check(GameState.inventory.is_empty(), "道具使用后背包扣减完毕")
	await _settle(player)

	# ---- 单向平台：①自下而上跳穿并落于其上 ②站立按 S 下穿到下一层 ----
	# ① 平台顶面 y=-62，站上后中心 y=-79；从地面（-17）起跳应穿过平台并落其上
	player.global_position = Vector2(100, -17)
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press(&"jump")
	await _frames(45)
	Input.action_release(&"jump")
	_check(player.is_on_floor() and absf(player.global_position.y + 79.0) < 4.0,
			"自下而上跳穿单向平台并落于其上（y=%.1f 期望 -79）" % player.global_position.y)
	# ② 站在平台上按 S：屏蔽 oneway 碰撞位下落到地面（-17）
	Input.action_press(&"move_down")
	await _frames(30)
	Input.action_release(&"move_down")
	_check(player.is_on_floor() and absf(player.global_position.y + 17.0) < 4.0,
			"站立按 S 穿过平台下落（y=%.1f 期望 -17）" % player.global_position.y)
	await _settle(player)

	# ---- 上台辅助（mantle）：脚部比平台顶低 4px 时吸附上台（无辅助会穿过去落回地面）----
	player.global_position = Vector2(-100, -17)
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press(&"jump")
	await _frames(50)
	Input.action_release(&"jump")
	_check(player.is_on_floor() and absf(player.global_position.y + 133.0) < 4.0,
			"上台辅助：差 4px 起跳登上平台（y=%.1f 期望 -133）" % player.global_position.y)
	await _settle(player)

	# ---- 闪避：地面（体力/时长）与空中（跳跃过程中可闪避）----
	var sta0: int = GameState.sta
	Input.action_press(&"move_left")
	Input.action_press(&"dodge")
	await _frames(2)
	var waited := 0
	while player.sm.current_name() != &"Dodge" and waited < 5:
		await _frames(1)
		waited += 1
	var dodge_frames := 0
	while player.sm.current_name() == &"Dodge" and dodge_frames < 30:
		await _frames(1)
		dodge_frames += 1
	_check(player.sm.current_name() != &"Dodge" and dodge_frames <= 9,
			"地面闪避按时结束（持续 %d 帧，期望 ≤9 = 6 帧 + 边沿余量）" % dodge_frames)
	_check(sta0 - GameState.sta == 12, "地面闪避扣体力 12（%d → %d）" % [sta0, GameState.sta])
	Input.action_release(&"dodge")
	Input.action_release(&"move_left")
	# 体力回复：停手 0.8s 后 12/s，2.8s 内应从 88 回满 100（封顶）
	await _frames(175)
	_check(GameState.sta == GameState.sta_max,
			"闪避耗尽的体力可回复（停手 2.8s 后 STA=%d/%d）" % [GameState.sta, GameState.sta_max])
	await _settle(player)
	await _frames(30)  # 烧完 0.45s 闪避冷却，避免污染空中闪避用例
	Input.action_press(&"jump")
	await _frames(8)
	Input.action_press(&"move_left")
	Input.action_press(&"dodge")   # 空中闪避
	await _frames(2)
	var air_dodged: bool = player.sm.current_name() == &"Dodge"
	Input.action_release(&"dodge")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	_check(air_dodged, "跳跃过程中可闪避（空中进入 Dodge 状态）")
	await _settle(player)

	# ---- 汇总 ----
	var total := _passes + _fails.size()
	if _fails.is_empty():
		print("=== SIM RESULT: ALL PASS（%d/%d）===" % [_passes, total])
		get_tree().quit(0)
	else:
		for f in _fails:
			print("❌ FAIL: %s" % f)
		print("=== SIM RESULT: FAILED（%d/%d）===" % [_passes, total])
		get_tree().quit(1)


## 手感常量自洽抽查（§3.1 数值表；场景模式可安全加载 Player）。
func _check_constants() -> void:
	_check(PlayerTuning.JUMP_VELOCITY == 636.0, "跳跃初速 636（制作人调参：跳高翻倍）")
	_check(PlayerTuning.COYOTE_TIME == 0.10, "土狼时间 0.10s")
	_check(PlayerTuning.JUMP_BUFFER == 0.12, "跳跃缓冲 0.12s")
	_check(PlayerTuning.JUMP_CUT_MULT == 0.45, "松键短跳 ×0.45")
	_check(PlayerTuning.DODGE_SPEED == 1100.0, "闪避速度 1100（制作人调参）")
	_check(PlayerTuning.DODGE_TIME == 0.10, "闪避时长 0.10s（制作人调参：距离调低）")
	_check(PlayerTuning.DODGE_IFRAME_START == 0.03 and PlayerTuning.DODGE_IFRAME_END == 0.09,
			"闪避无敌帧窗口 0.03–0.09s")
	_check(PlayerTuning.PERFECT_GUARD_WINDOW == 0.12, "完美格挡窗口 0.12s")
	_check(PlayerTuning.HURT_INVULN == 0.8, "受击无敌 0.8s")
	_check(absf(PlayerTuning.JUMP_VELOCITY * PlayerTuning.JUMP_VELOCITY
			/ (2.0 * PlayerTuning.GRAVITY_UP) - 112.36) < 0.01, "理论跳高 112.36px 与常量自洽")


## 搭建最小世界：地面（x∈[-200,200]，顶 y=0）+ 玩家。
func _build_world() -> CharacterBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(400, 40)
	cs.shape = shape
	floor_body.add_child(cs)
	floor_body.position = Vector2(0, 20)
	add_child(floor_body)
	# 单向平台（x=40..160，顶面 y=-62）：验证 ①自下而上跳穿 ②站立按 S 下穿
	# （置于地板 x 范围内，下穿后要有地面可落）
	var one_way := StaticBody2D.new()
	one_way.collision_layer = 128
	one_way.position = Vector2(100, -55)
	var ocs := CollisionShape2D.new()
	var oshape := RectangleShape2D.new()
	oshape.size = Vector2(120, 14)
	ocs.shape = oshape
	ocs.one_way_collision = true
	one_way.add_child(ocs)
	add_child(one_way)
	# 单向平台 2（x=-160..-40，顶面 y=-116，比满跳脚部顶点 -112 高 4px）：验证上台辅助 mantle
	var one_way2 := StaticBody2D.new()
	one_way2.collision_layer = 128
	one_way2.position = Vector2(-100, -109)
	var ocs2 := CollisionShape2D.new()
	var oshape2 := RectangleShape2D.new()
	oshape2.size = Vector2(120, 14)
	ocs2.shape = oshape2
	ocs2.one_way_collision = true
	one_way2.add_child(ocs2)
	add_child(one_way2)
	var player: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector2(100, -17)
	add_child(player)
	return player


## 复位到地面静止（断开各测试之间的状态耦合）。
## 必须清空动作缓冲：上一用例的跳跃缓冲会在落地瞬间"补跳"，污染后续计时。
func _settle(player: CharacterBody2D) -> void:
	Input.action_release(&"jump")
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	player._buffers.clear()
	player.global_position = Vector2(100, -17)
	player.velocity = Vector2.ZERO
	for i in 30:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	await _frames(4)


func _check(ok: bool, msg: String) -> void:
	if ok:
		_passes += 1
		print("  ✅ PASS: %s" % msg)
	else:
		_fails.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
