extends RefCounted
## 削韧清单与基础池采用叶节点验证，不依赖自动加载或真实关卡。
func run(ctx) -> bool:
	var cfg := PoiseRules.config()
	ctx.expect_eq(int(cfg.enemy_max),100,"怪物初始内置韧性100")
	ctx.expect_eq(cfg.attacks.size(),29,"全部29项真实攻击均建立独立削韧键")
	ctx.expect_eq(float(cfg.attacks["normal:hammer_01:1"].poise_damage),40.0,"同步制作人填写的锤第一击40削韧")
	ctx.expect_eq(float(cfg.attacks["skill_omni_slash:hit_6"].poise_damage),100.0,"同步制作人填写的霸斩终结100削韧")
	ctx.expect_true(cfg.attacks["normal:bow_01:1"].poise_damage == null,"未填写的旧步枪条目不擅自赋值")
	for key: String in cfg.attacks:
		var value: Variant = cfg.attacks[key].poise_damage
		ctx.expect_true(value == null or ((value is int or value is float) and float(value) >= 0),key+" 削韧值为待填或非负数")
	var packet := DamagePacket.new(1)
	packet.poise_key = &"normal:hammer_01:1"
	var original: Variant = cfg.attacks[str(packet.poise_key)].poise_damage
	cfg.attacks[str(packet.poise_key)].poise_damage = null
	var pool := EnemyPoise.new()
	pool.configure()
	ctx.expect_true(not pool.receive(packet) and pool.current == 100,"未填写值不从生命伤害推导削韧")
	cfg.attacks[str(packet.poise_key)].poise_damage = 35
	ctx.expect_true(not pool.receive(packet) and pool.current == 65,"未破韧只扣除韧性")
	cfg.attacks[str(packet.poise_key)].poise_damage = 65
	ctx.expect_true(pool.receive(packet) and pool.current == 0 and pool.broken,"恰好归零触发首次破韧")
	ctx.expect_true(not pool.receive(packet),"硬直中重复命中不重启硬直")
	pool.recover()
	ctx.expect_true(pool.current == 100 and not pool.broken,"硬直结束恢复满韧性")
	cfg.attacks[str(packet.poise_key)].poise_damage = original
	var quests: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	ctx.expect_eq(quests.category_order,["main","side","exploration"],"全部分类按主线支线探索排序")
	var ids := {}
	for quest: Dictionary in quests.quests:
		ctx.expect_true(not ids.has(quest.id) and quests.category_order.has(quest.category) and not quest.conditions.is_empty(),str(quest.id)+" 唯一编号、分类和条件完整")
		ids[quest.id] = true
	ctx.expect_true(ProjectSettings.get_setting("input/quests").events[0].physical_keycode == KEY_L,"L绑定任务面板")
	return true
