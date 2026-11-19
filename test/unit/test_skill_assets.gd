extends RefCounted
## 十二技能与合作者清单逐项核对，确保完整角色、特效和图标均接入。

func run(ctx) -> bool:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/PROCESSED/skills/catalog.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skill_runtime.json"))
	var active := {}
	for row: Dictionary in data.skills:
		if str(row.category) == "active":
			active[str(row.id)] = row
	ctx.expect_eq(active.size(),12,"十二招正式主动技能替换旧技能和六个占位")
	ctx.expect_eq(runtime.skills.size(),12,"十二招都有可执行玩法配置")
	for item: Dictionary in catalog.skills:
		var id := str(item.id)
		ctx.expect_true(active.has(id),"素材清单技能已登记 "+id)
		if not active.has(id):
			continue
		var row: Dictionary = active[id]
		ctx.expect_true(not bool(row.placeholder) and ResourceLoader.exists(str(row.icon)),"真实图标且无主动占位 "+id)
		ctx.expect_true(runtime.skills.has(id) and float(row.cooldown) > 0,"玩法与冷却齐全 "+id)
	var unique := {}
	var counts := {"actor":0,"fx":0}
	for id: String in SkillLibrary.presentation().animations:
		var animation := SkillLibrary.animation(id)
		var complete: bool = animation.frames.size() > 0 and animation.frames.size() == animation.sha256.size()
		for index in animation.frames.size():
			var path := str(animation.frames[index])
			complete = complete and FileAccess.get_sha256(path) == str(animation.sha256[index]) and ResourceLoader.exists(path)
			if not unique.has(path):
				unique[path] = true
				counts[str(animation.kind)] += 1
		ctx.expect_true(complete,"原素材逐帧完整且未重绘 "+id)
		if str(animation.kind) == "actor":
			ctx.expect_eq(int(animation.root[1]),90 if str(animation.batch) == "SKL-B01" else 84,"各批次独立脚底锚点 "+id)
	ctx.expect_eq(counts.actor,96,"接入96张完整角色动作帧")
	ctx.expect_eq(counts.fx,96,"接入96张独立特效帧")
	for part: Dictionary in SkillLibrary.presentation().beam_components.values():
		ctx.expect_true(FileAccess.get_sha256(str(part.texture)) == str(part.sha256),"奶光炮组件保留原图 "+str(part.texture).get_file())
	ctx.expect_eq(SkillLibrary.canonical(&"skill_cleave"),&"skill_nb_quickdraw","旧剑气迁入拔刀")
	ctx.expect_eq(SkillLibrary.canonical(&"skill_heal"),&"skill_milk_spring","旧治疗迁入奶泉")
	return true
