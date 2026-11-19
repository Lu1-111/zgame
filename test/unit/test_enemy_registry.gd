extends RefCounted
## 验证稳定编号、储备隔离以及实际地图区域的属性解析。
func run(ctx) -> bool:
	var db = ctx.fetch_singleton("DataDB","res://scripts/autoload/data_db.gd")
	db.load_all()
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_registry.json"))
	var ids := {}
	for row: Dictionary in registry.entries:
		ctx.expect_true(str(row.numeric_id).length() == 4 and not ids.has(row.numeric_id),"%s 固定四位编号唯一" % row.runtime_id)
		ids[row.numeric_id] = true
		var definition: Dictionary = db.get_enemy(StringName(row.numeric_id))
		ctx.expect_eq(str(definition.id),str(row.runtime_id),"%s 数字编号可查询同一敌怪" % row.numeric_id)
		ctx.expect_eq(definition.numeric_id,row.numeric_id,"%s 查询保留数字编号" % row.runtime_id)
	var active: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	ctx.expect_eq(db.enemies.size(),active.enemies.size(),"储备记录不混入可战斗敌怪集合")
	ctx.expect_eq(db.get_enemy(&"0023").rank,"elite","岩穴猎手按制作人选择归入精英")
	ctx.expect_eq(db.canonical_enemy_id(&"lamp_beetle"),&"lamp_bug","历史矿灯虫别名不重复编号")
	ctx.expect_eq(db.canonical_enemy_id(&"shadow_wraith"),&"shadow_wisp","历史奶灵别名不重复编号")
	ctx.expect_eq(db.get_enemy_for_room(&"0021",&"cave_01"),{},"未设定蜘蛛不能作为零属性战斗实例出生")
	ctx.expect_eq(db.get_enemy_for_room(&"0001",&"forest_01").numeric_id,"0001","出生结果携带固定编号")
	ctx.expect_eq(db.get_boss_for_room(&"0013",&"forest_boss",1).hp,1000,"首领数字编号可解析第二阶段")
	var base := {"base_hp":20,"base_damage":8,"defense":5,"poise":100,"resist":{"physical":12,"magic":7},"exp":6,"coin_drop":[2,4]}
	var policy := {"tier_multipliers":{"2":1.5},"default_tier_multiplier":1.0,"region_multiplier_field":"enemy_multiplier","rounded_fields":["hp","damage"]}
	var final := EnemyStats.resolve(base,{"id":"cave","tier":2,"enemy_multiplier":2.0},policy)
	ctx.expect_true(final.hp == 60 and final.damage == 24,"区域等级倍率与区域修正共同决定基础生命攻击")
	ctx.expect_true(final.defense == 5 and final.poise == 100 and final.resist == base.resist and final.coin_drop == base.coin_drop,"防御韧性抗性与掉落不随区域等级增长")
	ctx.expect_true(not base.has("hp") and base.base_hp == 20,"出生计算不回写基础档案")
	ctx.expect_eq(EnemyStats.resolve(base,{"tier":3},policy),{},"未配置等级拒绝隐式生成属性")
	var map := Node.new()
	map.set_meta("layout_data","res://test/data/forest_candidates/05A.json")
	var actor := Node.new()
	map.add_child(actor)
	var context: Dictionary = db.enemy_spawn_context(actor,&"camp_01")
	ctx.expect_eq(context.region_id,&"forest","独立备选场景从实际地图读取区域")
	map.free()
	var enemy = load("res://scripts/enemies/combat_enemy.gd").new()
	enemy.definition = {"damage":8}
	enemy.tuning = {"damage_multiplier":1.0,"attack_knockback":100}
	enemy._attack_variant = {"damage_multiplier":1.5,"attack_knockback":160}
	var packet: DamagePacket = enemy._packet()
	ctx.expect_eq(packet.amount,12,"招式伤害倍率实际进入伤害包")
	ctx.expect_eq(packet.knockback,160.0,"招式击退覆盖实际进入伤害包")
	enemy.free()
	return true
