extends Node
## 正式人物与受击框的武器倍率、能力、连段和存档迁移回归。
var checks := 0
var failures := 0

class Dummy extends Node:
	var hp := 1000
	var poise := {"broken":false}
	var last := 0
	func hit(packet: DamagePacket) -> int:
		last=packet.amount
		hp=maxi(0,hp-packet.amount)
		return packet.amount

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := get_tree().root
	var stage := Node2D.new()
	root.add_child(stage)
	var state := root.get_node("GameState")
	state.reset()
	var player: Variant=(load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://test/scripts/weapon_demo_player.gd"))
	stage.add_child(player)
	player.set_physics_process(false)
	player.cam.enabled=false
	var db := root.get_node("DataDB")
	_near(WeaponAttributes.duration(db.get_weapon(&"sword_01")),0.53,"1倍攻速保持0.53秒")
	_near(WeaponAttributes.duration(db.get_weapon(&"sword_03")),0.6625,"阔剑0.8倍攻速应变慢至0.6625秒")
	_near(WeaponAttributes.duration(db.get_weapon(&"sword_06")),0.3533333333,"切割者1.5倍攻速应加快至约0.3533秒")
	_near(WeaponAttributes.duration(db.get_weapon(&"hammer_04")),0.625,"巨剑0.8倍攻速每段0.625秒")
	var values := {
		"sword_01":[20,1.0,1.0],"sword_02":[18,0.9,1.0],"sword_03":[25,1.3,0.8],
		"sword_04":[18,1.0,0.9],"sword_05":[17,0.6,1.2],"sword_06":[15,0.8,1.5],
		"hammer_01":[30,1.0,1.0],"hammer_02":[30,0.8,1.2],"hammer_03":[40,1.3,0.8],
		"hammer_04":[42,1.5,0.8],"hammer_05":[36,1.2,1.2]}
	for id: String in values:
		var weapon: Dictionary=db.get_weapon(StringName(id))
		for field in 3:_near(float(weapon[["attack","poise_multiplier","attack_speed_multiplier"][field]]),float(values[id][field]),"完整用户数值 "+id)
		state.weapon_id=StringName(id)
		player.reset_weapon_traits()
		var kind := str(weapon.weapon_type)
		var base: Dictionary=WeaponAttributes.config().types[kind]
		var module := WeaponRuntime.attack_module(weapon)
		for phase: String in base.base_attack_time:
			_near(module[phase],base.base_attack_time[phase]/weapon.attack_speed_multiplier,"阶段时长除以攻速倍率")
		for segment in int(weapon.combo):
			var packet: DamagePacket=player.build_attack_packet(segment+1)
			_near(PoiseRules.damage(packet),base.base_poise[segment]*weapon.poise_multiplier,"每段削韧乘倍率")
		_expect(player.attack_damage()==8+int(weapon.attack),"武器攻击力直接进入最终伤害")
		# 完整三段都必须经过收招；用正式Attack状态进行固定小步推进。
		player.sm.to(&"Attack",{"combo":1})
		var elapsed := 0.0
		var entered := {1:true}
		while player.sm.current_name()==&"Attack" and elapsed<5:
			player.attack_chain=true
			player._clock+=0.001
			player.sm.tick(0.001)
			player._update_animation()
			elapsed+=0.001
			entered[player.attack_combo]=true
		_near(elapsed,WeaponAttributes.duration(weapon)*int(weapon.combo),"完整连招逐段使用倍率时间",0.006)
		_expect(entered.size()==int(weapon.combo),"完整连招经过所有段 "+id)
		for child in player.get_children():
			if child is AttackEffect or child is SwordAttackEffect:child.queue_free()
	# 同一真实时间下，快锤推进到第2帧、慢锤仍在第1帧；特效同向加速。
	for sample: Dictionary in [{"id":"hammer_05","frame":1},{"id":"hammer_04","frame":0}]:
		state.weapon_id=StringName(sample.id)
		player.sm.to(&"Attack",{"combo":1})
		player._clock+=0.15
		player.sm.tick(0.15)
		player._update_animation()
		_expect(player.sprite.frame==int(sample.frame),"实际逐帧推进随攻速加快/减慢 "+str(sample.id))
		player.spawn_melee_effect(1)
		for child in player.get_children():
			if not child is AttackEffect or child.is_queued_for_deletion():continue
			var fx := child as AttackEffect
			var visual: AnimatedSprite2D=fx._effect_player.visual if fx._effect_player is WeaponVFX else fx._effect_player.get_node("VisualRoot/AnimatedSprite2D")
			_near(visual.speed_scale,float(WeaponRuntime.module("hammer").effect_rate)*float(player.weapon_cfg().attack_speed_multiplier),"锤特效播放速度乘攻速倍率")
			fx.queue_free()
		player.sm.to(&"Idle")
	# 步枪还原到原姿态时间域，快慢倍率均在相同比例处进入同一射击/后坐帧。
	state.weapon_id=&"bow_01"
	var rifle: Dictionary=db.get_weapon(&"bow_01")
	var original_speed := float(rifle.attack_speed_multiplier)
	for speed in [0.8,1.5]:
		rifle.attack_speed_multiplier=speed
		player.sm.to(&"Attack",{"combo":1})
		player._clock=player._last_attack_time+0.18/speed
		player._sync_rig_pose()
		_near(player._pixel_rig.release_time,0.04,"步枪射击/后坐按攻速正确推进")
		player.sm.to(&"Idle")
	rifle.attack_speed_multiplier=original_speed
	var target := Dummy.new()
	stage.add_child(target)
	var hurtbox := HurtboxComponent.new()
	hurtbox.owner_actor=target
	hurtbox.hit_callback=target.hit
	target.add_child(hurtbox)
	state.weapon_id=&"sword_06"
	player.reset_weapon_traits()
	for stack in 8:
		player.begin_weapon_attack()
		var packet: DamagePacket=player.build_attack_packet(1)
		_near(packet.weapon_ticket.damage_multiplier,1.0+mini(stack,6)*0.05,"动能逐段冻结并封顶")
		packet.amount=100
		target.hp=1000
		hurtbox.receive_hit(packet)
		var expected := mini(stack+1,6)
		_expect(player._kinetic_stacks==expected,"首次有效命中增加一层")
		hurtbox.receive_hit(packet)
		_expect(player._kinetic_stacks==expected,"同段多个目标/碰撞不重复叠层")
		player.finish_weapon_attack()
	player.begin_weapon_attack()
	player.finish_weapon_attack()
	_expect(player._kinetic_stacks==0,"挥空清除全部动能")
	player.begin_weapon_attack()
	player.weapon_attack_landed(player._weapon_ticket,10)
	state.weapon_id=&"sword_01"
	player.begin_weapon_attack()
	_expect(player._kinetic_stacks==0,"换装清除动能")
	player.finish_weapon_attack()
	state.weapon_id=&"sword_05"
	player.reset_weapon_traits()
	state.hp=40
	player.begin_weapon_attack()
	var leech: DamagePacket=player.build_attack_packet(1)
	leech.amount=200
	target.hp=7
	hurtbox.receive_hit(leech)
	_expect(state.hp==40,"过量击杀只计实际7点损失，治疗小数未满1")
	target.hp=13
	hurtbox.receive_hit(leech)
	_expect(state.hp==41,"实际20点生命损失累计回复1点")
	state.hp=state.hp_max
	target.hp=1000
	hurtbox.receive_hit(leech)
	state.hp=40
	target.hp=1
	hurtbox.receive_hit(leech)
	_expect(state.hp==40,"满血不储存过量治疗")
	state.hp=0
	target.hp=1000
	hurtbox.receive_hit(leech)
	_expect(state.hp==0,"吸血不能复活已死亡玩家")
	player.finish_weapon_attack()
	state.hp=state.hp_max
	state.weapon_id=&"hammer_02"
	player.begin_weapon_attack()
	var mace: DamagePacket=player.build_attack_packet(1)
	mace.amount=100
	target.hp=1000
	target.poise.broken=false
	hurtbox.receive_hit(mace)
	_expect(target.last==100,"未破韧不享受流星锤加成")
	target.poise.broken=true
	hurtbox.receive_hit(mace)
	_expect(target.last==120,"已破韧伤害增加20%")
	_expect(mace.amount==100,"独立目标处理不污染原伤害包")
	player.finish_weapon_attack()
	for id: String in ["sword_02","sword_04","hammer_03","hammer_05"]:
		for effect: Dictionary in db.get_weapon(StringName(id)).special_effects:
			if effect.kind == "status":
				_expect(bool(effect.implemented), "武器的流血或中毒已接入")
			else:
				_expect(not bool(effect.implemented), "武器技能保留占位")
				_expect(WeaponAttributes.effect(db.get_weapon(StringName(id)),effect.kind).is_empty(),"占位不能触发实际效果")
	var skill := DamagePacket.new(100)
	skill.poise_key=&"skill_omni_slash:hit_1"
	var independent := PoiseRules.damage(skill)
	_expect(independent>0,"技能使用已有非空独立削韧数据")
	state.weapon_id=&"sword_06"
	_expect(PoiseRules.damage(skill)==independent and skill.weapon_ticket==null and skill.normal_poise<0,"技能削韧与武器倍率独立")
	# 旧档一次迁移不改变装备、重复调用不重复授予。
	state.weapon_id=&"bow_01"
	state.owned_weapons.clear()
	state.equipment_revision=1
	RPGService.ensure_state()
	var migrated: Array=state.owned_weapons.duplicate()
	RPGService.ensure_state()
	_expect(state.owned_weapons==migrated and state.weapon_id==&"bow_01","一次迁移保持当前装备且不重复授予")
	for id: String in values:
		if id=="hammer_01":continue # 旧初始武器不在本次九把新武器授予批次内。
		_expect(id==str(state.weapon_id) or state.owned_weapons.has(StringName(id)),"新武器进入可测试装备库 "+id)
	# 实际地面上的格挡受击：0生命伤害，体力仍消耗与破防。
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(300,20)
	collision.shape=shape
	floor_body.add_child(collision)
	floor_body.position=Vector2(0,100)
	stage.add_child(floor_body)
	player.position=Vector2(0,70)
	player.set_physics_process(true)
	for i in 8:await get_tree().physics_frame
	player.set_physics_process(false)
	_expect(player.is_on_floor(),"格挡验收人物已接地")
	state.weapon_id=&"hammer_04"
	state.hp=80
	state.sta=100
	player.sm.to(&"Guard")
	player.guard_pose_time=1.0
	Input.action_press(&"guard")
	var incoming := DamagePacket.new(20)
	_expect(player.apply_hit(incoming)==0 and state.hp==80 and state.sta<100,"巨剑格挡0伤害仍消耗体力")
	state.sta=1
	_expect(player.apply_hit(incoming)==0 and state.hp==80 and player.sm.current_name()==&"Hurt","巨剑体力不足仍破防，本次防御不损生命")
	Input.action_release(&"guard")
	player._invuln=0
	_expect(player.apply_hit(incoming)>0 and state.hp<80,"退出防御后正常受伤")
	player.reset_weapon_traits()
	_expect(player._kinetic_stacks==0 and player._weapon_heal_fraction==0,"重置清除全部能力暂态")
	stage.queue_free()
	await get_tree().process_frame
	print("WEAPON ATTRIBUTES: %d checks / %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _expect(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+label)

func _near(actual: float,expected: float,label: String,tolerance: float=0.00001) -> void:
	_expect(absf(actual-expected)<tolerance,"%s (%.4f / %.4f)" % [label,actual,expected])
