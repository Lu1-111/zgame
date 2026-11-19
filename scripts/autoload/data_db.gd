extends Node
## DataDB —— 数据驱动核心（autoload 单例）
## 启动时把 data/*.json 载入内存并按 id 建索引；查询缺失一律返回 {}。
## 灰盒期数据表可能由关卡 Agent 并行生成：文件缺失只警告、不报错、不崩溃。

const REGIONS_PATH := "res://data/world/regions.json"

## 集合名 → 数据文件路径（每个文件顶层为 {"<集合名>": [...]}）
const COLLECTION_PATHS := {
	"items": "res://data/items.json",
	"weapons": "res://data/weapons.json",
	"accessories": "res://data/accessories.json",
	"skills": "res://data/skills.json",
	"talents": "res://data/talents.json",
	"enemies": "res://data/enemies.json",
}

var loaded := false          ## regions.json 载入成功即为 true
var regions: Array = []      ## 区域列表（保持表内顺序，供地图生成用）
var rooms: Dictionary = {}   ## 房间 id → 房间 dict
var items: Dictionary = {}   ## 道具 id → 道具 dict
var weapons: Dictionary = {} ## 武器 id → 武器 dict
var accessories: Dictionary = {} ## 饰品 id → 饰品定义
var skills: Dictionary = {}  ## 技能 id → 技能 dict
var talents: Dictionary = {} ## 天赋 id → 天赋 dict
var enemies: Dictionary = {} ## 敌人 id → 敌人 dict
var bosses: Dictionary = {}  ## 独立首领档案；与旧12种怪物兼容，按阶段解析基础生命。
var enemy_records: Dictionary = {} ## 固定数字ID登记，含尚未实装的储备。
var enemy_aliases: Dictionary = {}
var enemy_drafts: Dictionary = {} ## 储备档案也读取登记来源，填写后查询与文档保持一致。

func _ready() -> void:
	## 启动自动载入一次
	load_all()

func load_all() -> Error:
	## 载入全部数据表（可重复调用，先清空再载入）。
	## - regions.json 成功 → loaded=true 并返回 OK（其余表缺失仅 push_warning 一次）
	## - regions.json 缺失 → 返回 ERR_FILE_NOT_FOUND 且 loaded=false
	## - regions.json 解析失败 → 返回 ERR_PARSE_ERROR 且 loaded=false
	loaded = false
	regions = []
	rooms = {}
	items = {}
	weapons = {}
	accessories = {}
	skills = {}
	talents = {}
	enemies = {}
	bosses = {}
	enemy_records = {}
	enemy_aliases = {}
	enemy_drafts = {}
	var err := _load_regions()
	if err != OK:
		return err
	for coll_name in COLLECTION_PATHS:
		_load_collection(coll_name, COLLECTION_PATHS[coll_name])
	var boss_data: Variant = _read_json("res://data/bosses/claffert.json")
	if boss_data is Dictionary and boss_data.has("id"):
		bosses[StringName(str(boss_data.id))] = boss_data
	var registry: Variant = _read_json("res://data/enemy_registry.json")
	if registry is Dictionary:
		for row: Dictionary in registry.entries:
			var key := StringName(str(row.runtime_id))
			enemy_records[key] = row
			enemy_aliases[str(row.numeric_id)] = key
			for alias: String in row.aliases:enemy_aliases[alias] = key
			if not enemies.has(key) and not bosses.has(key):
				var draft: Dictionary = row.draft.duplicate(true)
				if row.get("source") is Dictionary:
					var source: Dictionary = row.source
					var catalog: Variant = _read_json("res://"+str(source.file))
					if catalog is Dictionary and source.has("collection"):
						for entry: Dictionary in catalog.get(str(source.collection),[]):
							if str(entry.id) == str(source.id):draft.merge(entry,true)
				enemy_drafts[key] = draft
	loaded = true
	return OK

func get_region(id: StringName) -> Dictionary:
	## 按 id 查询区域定义；缺失返回 {}
	for r in regions:
		if r is Dictionary and String(r.get("id", "")) == String(id):
			return r
	return {}

func get_room(id: StringName) -> Dictionary:
	## 按 id 查询房间定义；缺失返回 {}
	return rooms.get(id, {}) as Dictionary

func get_item(id: StringName) -> Dictionary:
	## 按 id 查询道具定义；缺失返回 {}
	return items.get(id, {}) as Dictionary

func get_weapon(id: StringName) -> Dictionary:
	## 按 id 查询武器定义；缺失返回 {}
	return weapons.get(id, {}) as Dictionary

## 按稳定ID查询饰品定义。
func get_accessory(id: StringName) -> Dictionary:
	return accessories.get(id, {}) as Dictionary

func get_skill(id: StringName) -> Dictionary:
	## 按 id 查询技能定义；缺失返回 {}
	return skills.get(SkillLibrary.canonical(id), {}) as Dictionary

func get_talent(id: StringName) -> Dictionary:
	## 按 id 查询天赋定义；缺失返回 {}
	return talents.get(id, {}) as Dictionary

func get_enemy(id: StringName) -> Dictionary:
	## 按 id 查询敌人定义；缺失返回 {}
	id = canonical_enemy_id(id)
	var result: Dictionary = enemies.get(id,bosses.get(id,{})).duplicate(true)
	if result.is_empty() and enemy_records.has(id):
		result = enemy_drafts.get(id,{}).duplicate(true)
		result["id"] = str(id)
		result["name"] = enemy_records[id].name
		result["rank"] = enemy_records[id].category
	if enemy_records.has(id):result["numeric_id"] = enemy_records[id].numeric_id
	return result

## 数字ID及明确别名映射到稳定运行标识；不把有歧义的ENM素材号用作运行ID。
func canonical_enemy_id(id: StringName) -> StringName:
	return StringName(str(enemy_aliases.get(str(id),id)))

## 从实际地图祖先读取房间和区域，备选场景同样使用显式region而非玩家旧房间。
func enemy_spawn_context(actor: Node, fallback_room: StringName) -> Dictionary:
	var room_id := fallback_room
	var region_id := ""
	var node := actor.get_parent()
	while node != null:
		if node.has_meta("layout_data"):
			var layout: Variant = _read_json(str(node.get_meta("layout_data")))
			if layout is Dictionary:
				room_id = StringName(str(layout.get("id",room_id)))
				region_id = str(layout.get("region",""))
				break
		node = node.get_parent()
	if region_id.is_empty():region_id = str(get_room(room_id).get("region",""))
	return {"room_id":room_id,"region_id":StringName(region_id)}

## 读取首领原始档案；美术文件夹保留旧命名，运行ID使用制作人指定占位名。
func get_boss(id: StringName) -> Dictionary:
	return bosses.get(canonical_enemy_id(id),{}) as Dictionary

## 首领按阶段生成独立最终属性，只有基础生命与基础攻击乘区域倍率。
func get_boss_for_room(id: StringName, room_id: StringName, phase_index: int = 0, region_hint: StringName = &"") -> Dictionary:
	id = canonical_enemy_id(id)
	var base := get_boss(id).duplicate(true)
	if base.is_empty() or phase_index < 0 or phase_index >= base.phases.size():
		return {}
	base.base_hp = base.phases[phase_index].base_hp
	base.poise = base.phases[phase_index].get("poise",base.poise)
	var room := get_room(room_id)
	base["numeric_id"] = enemy_records.get(id,{}).get("numeric_id","")
	return EnemyStats.resolve(base,get_region(region_hint if region_hint != &"" else StringName(str(room.get("region","")))))

## 放入实际房间时解析区域倍率；数据表里的基础属性不会被运行时改写。
func get_enemy_for_room(id: StringName, room_id: StringName, region_hint: StringName = &"") -> Dictionary:
	id = canonical_enemy_id(id)
	if bosses.has(id):
		return get_boss_for_room(id,room_id,0,region_hint)
	if not enemies.has(id):return {} # 仅美术/未设定参数的记录不能作为可战斗实例出生。
	var room := get_room(room_id)
	var region := get_region(region_hint if region_hint != &"" else StringName(str(room.get("region",""))))
	return EnemyStats.resolve(get_enemy(id),region)

func get_rooms() -> Array:
	## 全部房间定义列表
	return rooms.values()

func _load_regions() -> Error:
	## 载入 regions.json（顶层 {"regions": [...], "rooms": [...]}）
	if not FileAccess.file_exists(REGIONS_PATH):
		push_warning("DataDB: 数据表缺失 %s（可能尚未生成），世界数据未载入" % REGIONS_PATH)
		return ERR_FILE_NOT_FOUND
	var data: Variant = _read_json(REGIONS_PATH)
	if not (data is Dictionary):
		push_warning("DataDB: %s 解析失败，世界数据未载入" % REGIONS_PATH)
		return ERR_PARSE_ERROR
	var d := data as Dictionary
	if d.get("regions") is Array:
		for entry in d["regions"]:
			if entry is Dictionary and entry.has("id"):
				regions.append(entry)
	if d.get("rooms") is Array:
		for entry in d["rooms"]:
			if entry is Dictionary and entry.has("id"):
				rooms[StringName(String(entry["id"]))] = entry
	return OK

func _load_collection(coll_name: String, path: String) -> void:
	## 载入单个集合表，按 "id" 建索引；文件缺失/结构异常只 push_warning 一次并跳过
	if not FileAccess.file_exists(path):
		push_warning("DataDB: 数据表缺失 %s，%s 表为空" % [path, coll_name])
		return
	var data: Variant = _read_json(path)
	if not (data is Dictionary) or not (data as Dictionary).has(coll_name):
		push_warning("DataDB: %s 结构异常（缺顶层键 \"%s\"），忽略该表" % [path, coll_name])
		return
	var rows: Variant = (data as Dictionary)[coll_name]
	if not (rows is Array):
		push_warning("DataDB: %s 顶层键 \"%s\" 不是数组，忽略该表" % [path, coll_name])
		return
	var into: Dictionary = _collection_dict(coll_name)
	for entry in rows:
		if entry is Dictionary and entry.has("id"):
			into[StringName(String(entry["id"]))] = entry

func _collection_dict(coll_name: String) -> Dictionary:
	## 集合名 → 对应的索引字典（Dictionary 为引用类型，写入直接生效）
	match coll_name:
		"items":
			return items
		"weapons":
			return weapons
		"accessories":
			return accessories
		"skills":
			return skills
		"talents":
			return talents
		"enemies":
			return enemies
	return {}

func _read_json(path: String) -> Variant:
	## 读取并解析一个 JSON 文件；失败返回 null（警告文案由调用方决定）
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)
