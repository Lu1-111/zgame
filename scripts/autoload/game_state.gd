extends Node
## GameState —— 运行时状态容器（autoload 单例）
## 只存全局运行时状态，不含业务逻辑；存档结构见参考书 §3.9。
## 默认值是 QA 用例锚点（AGENTS.md §5）：HP 80/80、体力 100/100、奶力 60/60、
## Lv1、EXP 0、奶币 0、初始武器 hammer_01、初始房间 camp_01、初始检查点 cp_camp_01。

# ---- 等级 / 经济 ----
var level := 1            ## 当前等级（本期上限 15）
var exp := 0              ## 当前经验值
var coin := 0             ## 奶币数量

# ---- 三条资源 ----
var hp := 80              ## 生命值（80/80）
var hp_max := 80
var sta := 100            ## 体力（100/100）
var sta_max := 100
var mana := 60            ## 奶力（60/60）
var mana_max := 60

# ---- 装备与成长 ----
var weapon_id: StringName = &"hammer_01"   ## 当前武器：奶瓶锤
var abilities: Array[StringName] = []      ## 已解锁能力（本期仅 double_jump）
var talents: Array[StringName] = []        ## 已点亮天赋 id

# ---- 背包 / 快捷栏：两者各自持有实际物品堆叠，不再保存快捷引用 ----
var inventory: Array = []
var hotbar: Array = []
var materials: Array = []                   ## 材料独立页，不占行囊消耗品格
var storage: Array = []                     ## 篝火无限仓库
var bag_upgrades := 0
var owned_weapons: Array[StringName] = [&"sword_01",&"bow_01",&"milk_staff"]
var learned_skills: Array[StringName] = [&"skill_bubble"]
var equipped_skills: Array[StringName] = [&"skill_bubble",&"skill_cleave",&""]
var equipped_passives: Array[StringName] = [&"",&""]
var selected_skill := 0
var equipment_revision := 1
var map_revealed := false
var checkpoint_room: StringName = &"camp_01"
var checkpoint_position: Array = []
var saved_position: Array = []
var in_combat := false                      ## 瞬态战斗标记，不入存档

# ---- 世界进度 ----
var opened_chests: Array[StringName] = []     ## 已开启宝箱 id
var opened_shortcuts: Array[StringName] = []  ## 已从另一侧开启的捷径 id
var visited_rooms: Array[StringName] = []     ## 已到访房间 id
var defeated_bosses: Array[StringName] = []   ## 已击败 BOSS id
var current_room: StringName = &"camp_01"     ## 当前房间
var checkpoint_id: StringName = &"cp_camp_01" ## 最近检查点（篝火）
var play_time := 0.0                          ## 累计游玩秒数

func _process(delta: float) -> void:
	## 累计游玩时长（存档 meta.play_time 的数据源）
	play_time += delta

func reset() -> void:
	## 恢复全部默认值（新开局 / 读档覆盖前调用）
	level = 1
	exp = 0
	coin = 0
	hp = 80
	hp_max = 80
	sta = 100
	sta_max = 100
	mana = 60
	mana_max = 60
	weapon_id = &"hammer_01"
	abilities = []
	talents = []
	inventory = []
	hotbar = []
	materials = []
	storage = []
	bag_upgrades = 0
	owned_weapons = [&"sword_01",&"bow_01",&"milk_staff"]
	learned_skills = [&"skill_bubble"]
	equipped_skills = [&"skill_bubble",&"skill_cleave",&""]
	equipped_passives = [&"",&""]
	selected_skill = 0
	equipment_revision = 1
	map_revealed = false
	checkpoint_room = &"camp_01"
	checkpoint_position = []
	saved_position = []
	in_combat = false
	opened_chests = []
	opened_shortcuts = []
	visited_rooms = []
	defeated_bosses = []
	current_room = &"camp_01"
	checkpoint_id = &"cp_camp_01"
	play_time = 0.0

func to_save_dict() -> Dictionary:
	## 序列化上述全部字段（键名 = 字段名）。
	## StringName 统一转为 String，便于 JSON 落盘；数组一律深拷贝，防止外部误改。
	return {
		"level": level,
		"exp": exp,
		"coin": coin,
		"hp": hp,
		"hp_max": hp_max,
		"sta": sta,
		"sta_max": sta_max,
		"mana": mana,
		"mana_max": mana_max,
		"weapon_id": String(weapon_id),
		"abilities": _names_to_strings(abilities),
		"talents": _names_to_strings(talents),
		"inventory": inventory.duplicate(true),
		"hotbar": hotbar.duplicate(true),
		"materials": materials.duplicate(true),
		"storage": storage.duplicate(true),
		"bag_upgrades": bag_upgrades,
		"owned_weapons": _names_to_strings(owned_weapons),
		"learned_skills": _names_to_strings(learned_skills),
		"equipped_skills": _names_to_strings(equipped_skills),
		"equipped_passives": _names_to_strings(equipped_passives),
		"selected_skill": selected_skill,
		"equipment_revision": equipment_revision,
		"map_revealed": map_revealed,
		"checkpoint_room": String(checkpoint_room),
		"checkpoint_position": checkpoint_position.duplicate(),
		"saved_position": saved_position.duplicate(),
		"opened_chests": _names_to_strings(opened_chests),
		"opened_shortcuts": _names_to_strings(opened_shortcuts),
		"visited_rooms": _names_to_strings(visited_rooms),
		"defeated_bosses": _names_to_strings(defeated_bosses),
		"current_room": String(current_room),
		"checkpoint_id": String(checkpoint_id),
		"play_time": play_time,
	}

func load_from_dict(d: Dictionary) -> void:
	## 从存档字典恢复状态（to_save_dict 的逆操作）；缺失/类型不符的键保持当前值
	level = int(d.get("level", level))
	exp = int(d.get("exp", exp))
	coin = int(d.get("coin", coin))
	hp = int(d.get("hp", hp))
	hp_max = int(d.get("hp_max", hp_max))
	sta = int(d.get("sta", sta))
	sta_max = int(d.get("sta_max", sta_max))
	mana = int(d.get("mana", mana))
	mana_max = int(d.get("mana_max", mana_max))
	weapon_id = StringName(String(d.get("weapon_id", weapon_id)))
	abilities = _to_names(d.get("abilities", abilities), abilities)
	talents = _to_names(d.get("talents", talents), talents)
	inventory = _dup_array(d.get("inventory", inventory), inventory)
	hotbar = _dup_array(d.get("hotbar", hotbar), hotbar)
	materials = _dup_array(d.get("materials", []), [])
	storage = _dup_array(d.get("storage", []), [])
	bag_upgrades = int(d.get("bag_upgrades", 0))
	owned_weapons = _to_names(d.get("owned_weapons", ["hammer_01"]), [])
	learned_skills = _to_names(d.get("learned_skills", ["skill_bubble"]), [])
	equipped_skills = _to_names(d.get("equipped_skills", ["skill_bubble","skill_shield","skill_heal","skill_slam"]), [])
	equipped_passives = _to_names(d.get("equipped_passives", ["",""]), [])
	selected_skill = int(d.get("selected_skill",0))
	equipment_revision = int(d.get("equipment_revision",0))
	map_revealed = bool(d.get("map_revealed", false))
	checkpoint_room = StringName(d.get("checkpoint_room", "camp_01"))
	checkpoint_position = _dup_array(d.get("checkpoint_position", []), [])
	saved_position = _dup_array(d.get("saved_position", []), [])
	opened_chests = _to_names(d.get("opened_chests", opened_chests), opened_chests)
	opened_shortcuts = _to_names(d.get("opened_shortcuts", []), [])
	visited_rooms = _to_names(d.get("visited_rooms", visited_rooms), visited_rooms)
	defeated_bosses = _to_names(d.get("defeated_bosses", defeated_bosses), defeated_bosses)
	current_room = StringName(String(d.get("current_room", current_room)))
	checkpoint_id = StringName(String(d.get("checkpoint_id", checkpoint_id)))
	play_time = float(d.get("play_time", play_time))

static func _names_to_strings(arr: Array[StringName]) -> Array[String]:
	## StringName 数组 → String 数组（JSON 友好）
	var out: Array[String] = []
	for n in arr:
		out.append(String(n))
	return out

static func _to_names(v: Variant, fallback: Array[StringName]) -> Array[StringName]:
	## Variant → StringName 数组；v 不是数组时保持 fallback
	if not (v is Array):
		return fallback.duplicate()
	var out: Array[StringName] = []
	for item in v:
		out.append(StringName(String(item)))
	return out

static func _dup_array(v: Variant, fallback: Array) -> Array:
	## Variant → 数组深拷贝；v 不是数组时保持 fallback
	if v is Array:
		return (v as Array).duplicate(true)
	return fallback.duplicate(true)
