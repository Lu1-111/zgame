# forest_01 草图关卡（2026-10-25）

按制作人本次草图和八项说明重建，可玩场景为 `scenes/rooms/forest_01.tscn`。尺寸 1280×1856，即两屏宽；图块为 16×16。保留底部营地入口、右下锁闭捷径、两侧实体墙、中轴攀爬、宝箱与篝火横台、右上 forest_02 出口及树冠分散平台。对草图中的较大竖向空档补入薄台，并按角色当前跳跃参数重排高度。

## 试玩

新版已替换正式 `forest_01` 场景并接入主流程。Windows 双击根目录 `run_game.cmd`，标题屏按 Enter 后进入 camp_01，向右走过营地东门，进入本图左下的 `DoorWest`。从该入口向左可返回营地。旧森林生成命令也统一转到新版生成器，避免后续重建覆盖回旧图。

- Windows 双击根目录 `run_forest_01.cmd`；使用本机 Godot 4.7.2，也支持 `GODOT_BIN`。
- Linux：`bash run_forest_01.sh`。
- 编辑器：打开 `scenes/rooms/forest_01.tscn`，F6 运行当前场景。
- A/D 移动，空格跳跃，Shift 闪避，S/↓ 下穿薄台，E 交互，M 地图。

## 数据与代码识别

本次几何的唯一数据源为 `data/maps/forest_01.json`。`regions.json` 的 forest_01 新增 `layout_data` 与 `playable_scene` 指针；原有 M0 的 `size/platforms/doors/map_rect` 继续服务旧的 15 房规划校验。本次可玩地图的尺寸、通道、物件以 `layout_data` 为准，不能把旧几何与新场景叠加使用。

| 对象 | 场景节点 | 标记 / 碰撞 |
|---|---|---|
| 实心平台，32px 厚 | `Platform_<id>`，TileMapLayer | `platform_id`、`platform_type=solid`；world 层 1 |
| 薄平台，4px 厚 | `Platform_<id>`，TileMapLayer | `platform_type=oneway`；子节点 `OneWayBody` 使用 oneway 层 8，单向碰撞 |
| 草图红框墙体 | `Wall_<id>`，TileMapLayer | `platform_type=solid`、`surface_role=wall`、原始多边形；区域已填实 |
| 篝火 | `Campfire` | `checkpoint_id=cp_forest_01_tree`；E 恢复状态并设置本房间复活位置 |
| 宝箱 | `Chest` | `chest_id=chest_f01`；E 获得 potion_small×2，仅一次 |
| 捷径门 | `DoorEastShortcut` / `ShortcutGate` | `shortcut_id=forest_01_roots` |

TileSet 图块还带 `platform_type` 与 `surface_role` 自定义数据；平台节点分别加入 `solid_platforms/oneway_platforms` 组，墙体加入 `solid_walls` 组。每个平台有独立 ID，不需要靠颜色反推逻辑。薄台的 TileMap 物理关闭，由整段 StaticBody2D 负责碰撞，以兼容现有角色的 S 下穿与 mantle 查询，避免重复碰撞。

31 段平台、16 块墙、3 处通道。24 段标注的上升路线高差均 96px；当前单跳理论高度 112.36px，比例 0.854，水平净缺口最大 48px，小于两次闪避的 220px。中段实心悬台需要从右缘外侧起跳再横移上台；真实物理用例覆盖此路线。制作人 2026-10-26 指定的四个叉号已实装小怪：苔甲虫 (460,864)、奶滴史莱姆 (650,864)、苔甲虫 (640,1056)、奶滴史莱姆 (460,1152)。出生点与平台内巡逻边界位于 `data/maps/forest_01.json` 的 `enemies`，均使用 ENM-B04 正式战斗动作，可攻击、受击和击杀；休息后在原位置刷新，保留巡逻范围与玩家目标。

## 通道与范围

- `DoorWest` ↔ camp_01 的 `DoorEast`。
- `DoorEast` ↔ forest_02 的 `DoorWest`，落在巨木篝火层。
- 右下捷径初始由实心门阻挡。经上方出口进入 forest_02，走到黄色开关按 E 解锁，再从 `DoorWestShortcut` 返回树根。解锁状态写入 `GameState.opened_shortcuts`，支持 `to_save_dict/load_from_dict` 往返；旧存档缺字段时默认关闭。转场后有短暂入场保护，避免持续方向输入导致立即折返。
- forest_02 使用已有 ENV-B01 美术地图增加可玩衔接预览，仅用于验证两个出入口与捷径，不代表 forest_02 的最终关卡设计。其余 forest_03/04 接口尚未接入此预览。
- 篝火现已接入坐下、休息 / 天赋 / 仓库菜单、起身、跨房间复活点及双槽 CRC 存档；详见《玩法系统与魔幻UI.md》。

## 背景与预览

2026-10-25 素材精细化：实心平台改为苔岩与盘根断面，薄平台改为细枝与苔藓边，墙体使用连续岩根贴图；加入少量蕨叶、苔石、藤蔓，捷径挡门改为木纹栅栏。原 TileMapLayer 保留碰撞和类型数据，精细平台通过端帽与中段拼接对齐顶面，墙面使用世界坐标采样，跨图块保持连续。根须与苔藓允许少量延伸到碰撞体外，落脚面不变。表现数据为 `data/maps/forest_01_art.json`，素材及完整提示词见 `assets/terrain/forest_01/README.md`。

巨树为本轮通过内置 image_gen 生成的图片：`assets/backgrounds/forest_01/ancient_tree_v1.png`，提示词与来源记录在同目录 README。背景 z=-25，地形 z=0，物件 z=1，角色 z=20。

- `docs/previews/forest_01_full.png`：Godot 实际渲染的全图。
- `docs/previews/forest_01_rest.png`：640×360 游戏视口截图。
- `docs/previews/forest_01_layout.png`：M 键地图，红色为实心、蓝色为薄台、黄色为篝火、紫色为宝箱。
- 旧的小地图与世界拼图由 `tools/gen_minimap.gd` 同步更新；现支持带位置偏移的独立平台层。

## 重建与验收命令

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://tools/build_forest_sketch.gd
godot --headless --path . --script res://tools/gen_minimap.gd
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_door.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_forest_sketch.gd
godot --headless --path . res://scenes/rooms/forest_01.tscn --quit-after 120
godot --path . --script res://tools/preview_forest_sketch.gd -- full
```

Windows 沙箱内验证时，将 APPDATA/LOCALAPPDATA 临时指向 `work/forest_01/host/` 子目录，避免引擎向受限的宿主配置目录写入。正式双击启动使用用户正常的 Godot 配置目录。

## 本轮验证输出

Godot 4.7.2；导入、单元、物理和冒烟命令均退出 0，日志无 ERROR / WARNING。

```text
Import: exit=0, ERROR=0, WARNING=0
=== 汇总：passed=670 / total=670 ===
RESULT: ALL PASS
GAMEPLAY SYSTEMS: 76 PASS, 0 FAIL
NATIVE DRAG: 0 failures (3 PASS)
FOREST PHYSICS: 0 failures (42 PASS)
CAMP/FOREST CONNECTION: 0 failures (16 PASS)
main: exit=0
forest_01: exit=0
forest_02: exit=0
结果：全部通过（64 项检查，0 错误）
```

物理验收覆盖 24 段单跳、薄台上穿落脚与 S 下穿、实心顶面和底面阻挡、篝火与一次性宝箱、三个通道、从另一侧解锁捷径及 M 键地图。

## 四个叉号小怪（2026-10-26）

按照制作人标注，现有 forest_01 中段加入两只苔甲虫和两只奶滴史莱姆，forest_02 不增加小怪。上方实心台两只，中间薄台一只，下方左侧实心台一只。每个出生点具有独立 spawn_id、platform_id 和数据驱动水平巡逻范围；主动巡逻与追击不会自行越过平台边缘，受击击退仍保留。敌人使用已有 ENM-B04 战斗动画和原有数值，坐火刷新时保留出生位置、玩家目标及活动范围。

`tools/test_forest_enemies.gd` 检查四只实际实体、指定平台落脚、连续二十秒巡逻、真实攻击伤害、受击与击杀单次奖励、篝火刷新。纯路线用例冻结敌人 AI，战斗单独验收。

```text
Import: exit=0, ERROR=0, WARNING=0
passed=670 / total=670
FOREST ENCOUNTERS: 26 PASS, 0 FAIL
FOREST PHYSICS: 0 failures (42 PASS)
GAMEPLAY SYSTEMS: 76 PASS, 0 FAIL
forest_01 smoke (120 frames): exit=0
```

实际渲染的中段预览：`docs/previews/forest_01_encounters.png`。全图 `forest_01_full.png` 也已同步四只小怪。
