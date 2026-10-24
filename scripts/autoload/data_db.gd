extends Node
## DataDB —— 数据驱动核心（autoload 单例）
## 启动时把 data/*.json 载入内存并按 id 建索引；查询缺失一律返回 {}。
## 灰盒期数据表可能由关卡 Agent 并行生成：文件缺失只警告、不报错、不崩溃。

const REGIONS_PATH := "res://data/world/regions.json"

## 集合名 → 数据文件路径（每个文件顶层为 {"<集合名>": [...]}）
const COLLECTION_PATHS := {
	"items": "res://data/items.json",
	"weapons": "res://data/weapons.json",
	"skills": "res://data/skills.json",
	"talents": "res://data/talents.json",
	"enemies": "res://data/enemies.json",
}

var loaded := false          ## regions.json 载入成功即为 true
var regions: Array = []      ## 区域列表（保持表内顺序，供地图生成用）
var rooms: Dictionary = {}   ## 房间 id → 房间 dict
var items: Dictionary = {}   ## 道具 id → 道具 dict
var weapons: Dictionary = {} ## 武器 id → 武器 dict
var skills: Dictionary = {}  ## 技能 id → 技能 dict
var talents: Dictionary = {} ## 天赋 id → 天赋 dict
var enemies: Dictionary = {} ## 敌人 id → 敌人 dict

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
	skills = {}
	talents = {}
	enemies = {}
	var err := _load_regions()
	if err != OK:
		return err
	for coll_name in COLLECTION_PATHS:
		_load_collection(coll_name, COLLECTION_PATHS[coll_name])
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

func get_skill(id: StringName) -> Dictionary:
	## 按 id 查询技能定义；缺失返回 {}
	return skills.get(id, {}) as Dictionary

func get_talent(id: StringName) -> Dictionary:
	## 按 id 查询天赋定义；缺失返回 {}
	return talents.get(id, {}) as Dictionary

func get_enemy(id: StringName) -> Dictionary:
	## 按 id 查询敌人定义；缺失返回 {}
	return enemies.get(id, {}) as Dictionary

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
