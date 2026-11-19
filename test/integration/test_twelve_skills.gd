extends SceneTree
## 确定性实机验收：真实玩家、物理空间、输入、伤害包、独立实体和旧档迁移。
var actor: Node
var gs: Node
var ui: Node
var room: Node2D
var target: Node2D
var passed := 0
var failed := 0
var rpg: GDScript
var entity_script: GDScript

class Dummy extends Node2D:
	var hp := 10000
	var enemy_id := &"moss_beetle"
	var packets: Array = []
	var hurtbox: HurtboxComponent
	func _ready() -> void:
		add_to_group(&"enemies")
		hurtbox = HurtboxComponent.new()
		hurtbox.owner_actor = self
		hurtbox.collision_layer = 32
		hurtbox.collision_mask = 0
		hurtbox.hit_callback = receive_hit
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(20,30)
		shape.shape = rectangle
		shape.position.y = -15
		hurtbox.add_child(shape)
		add_child(hurtbox)
	func receive_hit(packet: DamagePacket) -> int:
		packets.append(packet)
		var amount := packet.amount if packet.ignore_defense else roundi(packet.amount*0.5)
		hp = maxi(0,hp-amount)
		return amount

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(50,true,false,true).timeout.connect(func() -> void: quit(2))
	rpg = load("res://scripts/core/rpg_service.gd")
	entity_script = load("res://scripts/player/skill_entity.gd")
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	gs.reset()
	room = Node2D.new()
	root.add_child(room)
	current_scene = room
	_floor(Rect2(0,300,900,30))
	actor = load("res://scenes/player/player.tscn").instantiate()
	actor.set_script(load("res://test/fixtures/aimed_skill_player.gd"))
	actor.position = Vector2(100,283)
	room.add_child(actor)
	target = Dummy.new()
	target.position = Vector2(190,300)
	room.add_child(target)
	await _frames(8)
	while ui.player != actor:
		await process_frame
	actor.set_physics_process(false)
	actor.skills.set_physics_process(false)
	_check(actor.is_on_floor(),"玩家在真实地面就位")
	await _migration_and_ui()
	await _quickdraw()
	await _beam()
	await _slash_and_dash()
	await _fields()
	await _mirror()
	await _buffs()
	await _orb()
	await _slam()
	await _edge_cases()
	ui._force_close()
	actor.skills.clear_effects()
	Engine.time_scale = 1
	print("TWELVE SKILLS: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _migration_and_ui() -> void:
	var old: Dictionary = gs.to_save_dict()
	old.equipped_skills = ["skill_bubble","skill_cleave","skill_heal"]
	old.learned_skills = ["skill_bubble","skill_heal","skill_heal"]
	gs.load_from_dict(old)
	_check(gs.equipped_skills == [&"skill_giga_milk_beam",&"skill_nb_quickdraw",&"skill_milk_spring"],"旧档三主动槽对应迁移")
	_check(gs.learned_skills.count(&"skill_milk_spring") == 1,"迁移不复制已学技能")
	ui.open_character()
	ui._character.open("skills")
	var count := 0
	var real_icons := true
	for slot in ui._character._slots:
		if slot.kind == "active_skill":
			count += 1
			real_icons = real_icons and slot.icon != null and not slot.locked and slot.icon.resource_path.contains("PROCESSED/skills/")
	_check(count == 12 and real_icons,"技能页十二真实图标全部可装备")
	_check(rpg.equip_skill(&"skill_nb_void_milk",2) and gs.equipped_skills[2] == &"skill_nb_void_milk","新技能拖装服务生效")
	ui._force_close()
	await _frames(2)

func _quickdraw() -> void:
	_reset()
	gs.weapon_id = &"hammer_01"
	_check(not actor.try_skill(&"skill_nb_quickdraw"),"拔刀拒绝非剑武器")
	gs.weapon_id = &"sword_01"
	gs.sta = 19
	_check(not actor.try_skill(&"skill_nb_quickdraw") and gs.sta == 19,"拔刀体力不足不收费")
	gs.sta = 100
	_check(actor.cast_ui_skill(&"skill_nb_quickdraw") and gs.sta == 80 and gs.mana == 60,"拔刀起架势消耗20体力")
	actor.skills.tick(0.1)
	var hp: int = gs.hp
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 0 and gs.hp == hp,"0.2秒架势免触发伤害")
	_check(target.packets.size() == 1 and target.packets[0].ignore_defense,"位移居合只命中一次且无视防御")
	_check(target.packets[0].poise_key == &"skill_nb_quickdraw:hit","居合伤害携带独立削韧键")
	_check(actor.position.x > 100 and actor.position.x < target.position.x,"居合位移合理且不穿过目标")
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 20,"反击之后没有额外全程无敌")
	await _frames(2)

func _beam() -> void:
	_reset()
	Input.action_press("cast_selected")
	_check(actor.cast_ui_skill(&"skill_giga_milk_beam") and gs.mana == 60,"奶光炮蓄力不预扣资源")
	actor.skills.tick(0.7)
	actor._update_animation()
	_check(actor.sprite.animation == &"skill_giga_milk_beam__charge_grow" and actor.sprite.offset.y == -90,"奶光炮读取本批逐帧和90px脚底锚点")
	Input.action_release("cast_selected")
	actor.skills.tick(0.01)
	_check(gs.mana == 40 and actor.skill_cooldown(&"skill_giga_milk_beam") > 0,"中蓄释放扣20奶力并进入冷却")
	_check(target.packets.size() == 1 and target.packets[0].type == DamagePacket.DamageType.MAGIC,"光束对同一目标只造成一次奶术伤害")
	_check(target.packets[0].poise_key == &"skill_giga_milk_beam:charged","光炮按实际中蓄档携带削韧键")
	_reset()
	Input.action_press("cast_selected")
	actor.cast_ui_skill(&"skill_giga_milk_beam")
	actor.skills.tick(0.1)
	actor.sm.to(&"Idle")
	Input.action_release("cast_selected")
	_check(gs.mana == 60 and actor.skill_cooldown(&"skill_giga_milk_beam") == 0,"蓄力取消不收费且不进入冷却")
	var wall := _floor(Rect2(155,210,12,90))
	await _frames(2)
	var length: float = actor.skills.clipped_beam_length(Vector2(114,270),360,48)
	_check(length <= 41,"炮口上下沿一起被最近墙体裁短")
	var hp: int = target.hp
	actor.skills.hit_region(Vector2(190,280),Vector2(200,70),false,&"skill_omni_slash",1,0)
	_check(target.hp == hp,"近战范围覆盖墙后目标也不会隔墙命中")
	wall.queue_free()
	await _frames(2)

func _slash_and_dash() -> void:
	_reset()
	actor.cast_ui_skill(&"skill_omni_slash")
	_check(gs.mana == 60,"霸斩起手未提交不收费")
	actor.skills.tick(0.24)
	for step in 5:
		actor.skills.tick(0.1201)
	_check(target.packets.size() == 6 and gs.mana == 28,"霸斩五短斩和一次终结分别结算，共扣32奶力")
	var keys_ok := true
	for index in target.packets.size():
		keys_ok = keys_ok and str(target.packets[index].poise_key) == "skill_omni_slash:hit_%d" % (index+1)
	_check(keys_ok,"霸斩六次真实命中各带独立削韧键")
	_check(not actor.skills.can_cancel(),"霸斩连斩阶段不可主动取消")
	actor.skills.tick(0.19)
	_check(actor.skills.can_cancel(),"霸斩收招阶段允许闪避")
	_reset()
	actor.cast_ui_skill(&"skill_comet_dash")
	actor.skills.tick(0.1)
	_check(gs.mana == 50 and absf(actor.velocity.x) > 0,"彗星冲开始真实水平推进并扣10奶力")
	actor.skills.tick(0.05)
	_check(actor.skills._dash_distance <= 110 and not actor.dodge_iframe,"彗星冲限制距离且不提供无敌")
	await _frames(2)

func _fields() -> void:
	_reset()
	gs.hp = 20
	actor.cast_ui_skill(&"skill_milk_spring")
	actor.skills.tick(0.3)
	var spring := _entity("spring")
	_check(spring != null and gs.mana == 36,"奶泉生成独立地面实体并扣24奶力")
	spring.set_physics_process(false)
	for step in 4:
		spring._physics_process(1)
	_check(gs.hp == 45,"四次奶泉累计恢复32%最大HP并保留小数余量")
	_reset()
	gs.hp = 20
	actor.cast_ui_skill(&"skill_milk_spring")
	actor.skills.tick(0.3)
	spring = _entity("spring")
	spring.set_physics_process(false)
	actor.position.x = 300
	spring._physics_process(1)
	_check(gs.hp == 20,"离开奶泉不补发治疗")
	_reset()
	actor.cast_ui_skill(&"skill_star_milk_prison")
	actor.skills.tick(0.24)
	var prison := _entity("prison")
	prison.set_physics_process(false)
	prison._physics_process(0.01)
	_check(target.packets.size() == 1 and target.packets[0].non_interrupting,"星牢出现伤害不强制打断动作")
	_check(target.get_node_or_null("SkillControl") != null and SkillControl.movement_ratio(target) == 0,"星牢对普通目标先定身")
	prison._physics_process(2)
	_check(target.packets.size() == 2,"星牢消散结算第二次伤害")
	_check(target.packets[0].poise_key == &"skill_star_milk_prison:hit_1" and target.packets[1].poise_key == &"skill_star_milk_prison:hit_2","星牢展开与终结削韧分别登记")
	await _frames(2)

func _mirror() -> void:
	_reset()
	target.position.x = 145
	await _frames(2)
	actor.cast_ui_skill(&"skill_mirror_milk_guard")
	actor.skills.tick(0.12)
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 0 and target.packets.size() >= 1,"镜盾展开精准窗口零伤并反击")
	_reset()
	await _frames(2)
	actor.cast_ui_skill(&"skill_mirror_milk_guard")
	actor.skills.tick(0.12)
	var shot := _incoming(20)
	shot.origin_actor = target
	actor._invuln = 0
	actor.apply_hit(shot)
	_check(target.packets.size() == 1 and target.packets[0].amount == 6,"镜返对近战反击范围外的原始攻击者反弹30%，不误伤其他目标")
	_check(target.packets[0].poise_key == &"skill_mirror_milk_guard:reflect","镜返反弹与盾击使用不同削韧键")
	_reset()
	actor.cast_ui_skill(&"skill_mirror_milk_guard")
	actor.skills.tick(0.5)
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 0,"镜盾维持期间使用吸收池")
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 8,"镜盾超过32点吸收池的伤害正常溢出")
	_reset()
	actor.cast_ui_skill(&"skill_mirror_milk_guard")
	actor.skills.tick(0.5)
	actor._invuln = 0
	var back := DamagePacket.new(20,DamagePacket.DamageType.PHYSICAL,0,actor.position-Vector2(40,0),&"moss_beetle")
	_check(actor.apply_hit(back) == 20,"镜盾背后攻击正常受击")
	await _frames(2)

func _buffs() -> void:
	_reset()
	var base: int = rpg.attack_power("physical")
	actor.cast_ui_skill(&"skill_nb_laughter")
	actor.skills.tick(0.4)
	_check(gs.skill_buffs.has("frenzy") and rpg.attack_power("physical") == roundi(base*1.3),"大笑获得20秒狂击且实际伤害+30%")
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 24,"狂击承伤提高20%")
	gs.hp = 20
	target.hp = 1
	actor.skills.damage(target.hurtbox,&"skill_omni_slash",1,0)
	_check(gs.hp == 44,"狂击击杀回复30%最大HP")
	actor._on_hit_landed(target.hurtbox,1)
	_check(gs.hp == 44,"同一敌人不会重复结算击杀恢复")
	var ranged_target := Dummy.new()
	room.add_child(ranged_target)
	ranged_target.hp = 0
	actor._on_hit_landed(ranged_target,1)
	_check(gs.hp == 68,"狂击也接收远程普攻的敌人实体回调")
	ranged_target.queue_free()
	actor._invuln = 0
	actor.sm.to(&"Idle")
	gs.sta = 100
	gs.mana = 60
	actor.cast_ui_skill(&"skill_nb_endurance")
	actor.skills.tick(0.35)
	_check(gs.skill_buffs.has("endurance") and not gs.skill_buffs.has("frenzy"),"忍耐替换狂击，互斥生效")
	_check(not actor.can_dodge() and float(rpg.stats().damage_reduction) == 30,"忍耐减伤30%并禁止闪避")
	actor._invuln = 0
	_check(actor.apply_hit(_incoming(20)) == 14,"忍耐真实受击按70%结算")
	actor.sm.to(&"Idle")
	gs.sta = 100
	gs.mana = 60
	var physical: int = actor.attack_damage()
	actor.cast_ui_skill(&"skill_nb_arcane_source")
	actor.skills.tick(0.35)
	_check(gs.skill_buffs.has("arcane") and gs.skill_buffs.has("endurance"),"奥术可与忍耐并存")
	var packet: DamagePacket = actor.build_attack_packet(1)
	_check(packet.type == DamagePacket.DamageType.MAGIC and packet.amount == physical,"奥术转换普攻类型并保留原伤害基底")
	actor.skills._physics_process(21)
	_check(gs.skill_buffs.is_empty() and actor.can_dodge(),"增益到期清除且恢复闪避")
	await _frames(2)

func _orb() -> void:
	_reset()
	actor.cast_ui_skill(&"skill_nb_void_milk")
	actor.skills.tick(0.99)
	_check(gs.mana == 60 and actor.skill_cooldown(&"skill_nb_void_milk") == 0,"光球蓄力阶段不提前收费")
	actor.skills.tick(0.011)
	var orb: Node = actor.skills.orb
	_check(is_instance_valid(orb) and gs.mana == 20 and actor.skill_cooldown(&"skill_nb_void_milk") == 0,"1秒后发球扣40奶力，爆炸前不启动冷却")
	orb.set_physics_process(false)
	orb.global_position = Vector2(185,282)
	orb._physics_process(0.01)
	_check(target.packets.size() == 1,"光球飞行接触造成伤害")
	orb._physics_process(0.1)
	_check(target.packets.size() == 1,"光球同目标接触伤害遵守间隔")
	var mana: int = gs.mana
	_check(actor.skills.detonate_selected(&"skill_nb_void_milk") and orb.mode == "explosion","再次施放引爆现有光球")
	_check(gs.mana == mana and actor.skill_cooldown(&"skill_nb_void_milk") > 19,"提前引爆不再收费且爆炸后开始20秒冷却")
	var hits: int = target.packets.size()
	orb.detonate()
	_check(target.packets.size() == hits and hits == 2,"爆炸只结算一次且独立于接触伤害")
	_check(target.packets[0].poise_key == &"skill_nb_void_milk:contact" and target.packets[1].poise_key == &"skill_nb_void_milk:explosion","光球接触与爆炸的实际伤害包分离削韧")
	_reset()
	actor.cast_ui_skill(&"skill_nb_void_milk")
	actor.skills.tick(1.01)
	orb = actor.skills.orb
	orb.set_physics_process(false)
	orb._physics_process(2.01)
	_check(orb.mode == "explosion","光球2秒自动爆炸")
	actor.skills.clear_effects()
	_check(gs.skill_buffs.is_empty(),"独立实体和增益有统一清理入口")
	await _frames(2)

func _slam() -> void:
	_reset()
	target.position.x = 165
	await _frames(2)
	gs.weapon_id = &"sword_01"
	_check(not actor.try_skill(&"skill_nb_king_slam"),"王从天降拒绝非锤武器")
	gs.weapon_id = &"hammer_01"
	actor.cast_ui_skill(&"skill_nb_king_slam")
	actor.skills.tick(0.18)
	_check(gs.sta == 60 and actor.velocity.y < 0,"王从天降扣40体力并产生向上速度")
	actor.set_physics_process(true)
	actor.skills.set_physics_process(true)
	await _frames(60)
	actor.set_physics_process(false)
	actor.skills.set_physics_process(false)
	_check(actor.is_on_floor() and target.get_node_or_null("SkillControl") == null,"王从天降真实跃起落地，未破韧不会强制中断目标")
	_check(target.packets.size() == 1,"下砸落地伤害只结算一次")
	_reset()
	actor.cast_ui_skill(&"skill_nb_endurance")
	actor.skills.tick(0.4)
	var saved: Dictionary = gs.to_save_dict()
	_check(not saved.has("skill_buffs"),"技能临时状态不写入存档")
	gs.load_from_dict(saved)
	_check(gs.skill_buffs.is_empty(),"读档清除临时技能状态")
	await _frames(2)

func _reset() -> void:
	Input.action_release("cast_selected")
	actor.skills.clear_effects()
	actor.sm.to(&"Idle")
	actor.clear_action_buffers()
	actor.reset_cooldowns()
	actor._invuln = 0
	actor.velocity = Vector2.ZERO
	actor.position = Vector2(100,283)
	actor.set_facing(1)
	gs.hp = 80
	gs.mana = 60
	gs.sta = 100
	gs.weapon_id = &"hammer_01"
	target.hp = 10000
	target.position.x = 190
	target.packets.clear()
	if target.get_node_or_null("SkillControl") != null:
		target.get_node("SkillControl").free()
	Engine.time_scale = 1

func _edge_cases() -> void:
	_reset()
	var wall := _floor(Rect2(158,210,12,90))
	await _frames(2)
	actor.cast_ui_skill(&"skill_nb_void_milk")
	actor.skills.tick(1.01)
	var ball: Node = actor.skills.orb
	ball.set_physics_process(false)
	ball._physics_process(0.5)
	_check(ball.mode == "explosion" and ball.global_position.x <= 132.1,"光球以实体半径撞墙引爆，不让球心穿墙")
	_check(target.packets.is_empty(),"光球爆炸不伤害墙后目标")
	wall.queue_free()
	await _frames(2)
	_reset()
	wall = _floor(Rect2(115,210,12,90))
	await _frames(2)
	actor.cast_ui_skill(&"skill_nb_void_milk")
	actor.skills.tick(1.01)
	ball = actor.skills.orb
	_check(ball.mode == "explosion" and ball.global_position.x <= 110 and target.packets.is_empty(),"贴墙施放不会把光球生成到墙后，出生受阻就原地引爆")
	wall.queue_free()
	await _frames(2)
	_reset()
	actor.cast_ui_skill(&"skill_nb_void_milk")
	actor.skills.tick(1.01)
	ball = actor.skills.orb
	ball.set_physics_process(false)
	gs.equipped_skills[0] = &"skill_nb_void_milk"
	gs.selected_skill = 0
	gs.mana = 0
	Input.action_press("cast_selected")
	actor._update_input()
	Input.action_release("cast_selected")
	_check(ball.mode == "explosion" and gs.mana == 0,"真实侧键输入在奶力耗尽时仍可免费引爆现有光球")
	_reset()
	actor.cast_ui_skill(&"skill_nb_void_milk")
	actor.skills.tick(1.01)
	ball = actor.skills.orb
	ball.set_physics_process(false)
	gs.current_room = &"forest_01"
	actor.skills._physics_process(0.01)
	_check(ball.is_queued_for_deletion() and actor.skill_cooldown(&"skill_nb_void_milk") > 0,"切房回收光球并结算冷却，不能跨房留伤害")
	gs.current_room = &"camp_01"
	actor.skills._physics_process(0.01)
	await _frames(2)
	_reset()
	gs.mana = 15
	Input.action_press("cast_selected")
	actor.cast_ui_skill(&"skill_giga_milk_beam")
	actor.skills.tick(1.3)
	Input.action_release("cast_selected")
	actor.skills.tick(0.01)
	_check(gs.mana == 1,"蓄满但奶力不足时退至可支付的最低档，只扣14")
	_reset()
	gs.talents.assign([&"milk_4"])
	actor.cast_ui_skill(&"skill_omni_slash")
	actor.skills.tick(0.841)
	_check(target.packets.size() == 6 and gs.mana == 30,"六段技能同次施放只触发一次2点天赋回奶")
	gs.talents.clear()
	_reset()
	var enemy: Node2D = load("res://scripts/enemies/combat_enemy.gd").new()
	enemy.enemy_id = &"moss_beetle"
	enemy.target = actor
	enemy.position = Vector2(450,300)
	room.add_child(enemy)
	await _frames(3)
	SkillControl.apply(enemy,0,0,0,3)
	var start_x: float = enemy.position.x
	var action_time: float = enemy.elapsed
	await _frames(6)
	_check(is_equal_approx(enemy.position.x,start_x) and is_equal_approx(enemy.elapsed,action_time) and enemy.visual.process_mode == Node.PROCESS_MODE_DISABLED,"真实敌人眩晕同时暂停AI行动和角色动画")
	enemy.get_node("SkillControl").stun_left = 0
	await _frames(3)
	_check(enemy.visual.process_mode == Node.PROCESS_MODE_INHERIT and enemy.elapsed > action_time,"眩晕解除后敌人恢复AI和动画")
	enemy.queue_free()
	_reset()
	actor.cast_ui_skill(&"skill_nb_endurance")
	actor.skills.tick(0.4)
	gs.hp = 0
	actor.skills._physics_process(0.01)
	_check(gs.skill_buffs.is_empty() and actor.skills._auras.is_empty(),"死亡清除增益与持续光效")
	gs.hp = 80
	await _frames(2)

func _entity(mode: String) -> Node:
	for child in room.get_children():
		if child.get_script() == entity_script and child.mode == mode and not child.is_queued_for_deletion():
			return child
	return null

func _incoming(amount: int) -> DamagePacket:
	return DamagePacket.new(amount,DamagePacket.DamageType.PHYSICAL,0,actor.position+Vector2(40,0),&"moss_beetle")

func _floor(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	room.add_child(body)
	return body

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS "+message)
	else:
		failed += 1
		print("FAIL "+message)
