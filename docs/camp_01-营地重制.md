# camp_01 小队临时据点重制（2026-10-26）

按制作人本轮要求，营地在现有平地路线之上新增交易台地。地图为 1280×640，安全区，无敌人、陷阱和左出口；下层右侧仍通往新版 forest_01 的左下入口。游戏默认初始房间及检查点名称不变，初始坐标为 (112,527)。

## 两层布局

下层地面 y=544，两顶不同帐篷分别在 x=164 / 816；篝火在 x=352，奶兔在 x=426，含初始药剂与奶弹的补给箱在 x=662。学者与野外书桌位于左侧帐篷旁；信使在右侧帐篷与告示板旁；守卫看守右侧林径。宝箱 ID 仍为 camp_supplies，已领取存档不会重新刷出。

中段两级空心平台顶面依次为 y=448 / 352，各高差 96px，约现有单跳高度的 85%；可以上穿、落脚及按 S 下穿。第二级与二层岩台间留有 16px 横向开口，按右方向起跳即可攀上，不需要二段跳。二层地基为 y=256、48px 厚的实心苔岩平台，碰撞与外观均和薄台分开标识。

二层左侧为奶鼠铁匠，配石炉、风箱、铁砧、工具桌与武器架；右侧为奶牛商人，配青布货摊、包裹及货箱。六位 NPC 全部使用 NPC-S01–S06/v002 正式 idle/talk 动作，并可按 E 交谈；NPC 的 E 交互优先于第二技能，交谈内容写在地图 JSON。

## 美术与运行

地形完全复用 forest_01 的苔藓、岩石、树根、细枝平台与墙体过渡 shader；新增精细道具图集和月夜繁茂树林背景使用内置 image_gen 生成，完整提示词及来源见两个素材目录的 README。蕨叶蘑菇复用 ENV-B01 正式素材。背景 z=-25、地形 0、装饰 1、主角及所有 NPC 20，装饰不会遮住角色。

场景加载时恢复镜头边界，避免旧营地存储时丢失镜头限制而露出灰底。首次进入营地记录可跨房间使用的初始重生坐标；坐火后更新为篝火位置。世界地图同步更新两图大小和连接高度。

唯一关卡数据源为 `data/maps/camp_01.json`；美术区域与比例在 `data/maps/camp_01_art.json`。`tools/build_camp.gd` 复用森林构建器的地形方法。重建场景、预览和检查：

```text
godot --headless --path . --import --quit
godot --headless --path . --script res://tools/build_camp.gd
godot --headless --path . --script res://tools/gen_minimap.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_camp.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_door.gd
godot --path . --fixed-fps 60 --script res://tools/preview_camp.gd -- full
```

实际渲染预览：`docs/previews/camp_01_full.png`、`camp_01_ground.png`、`camp_01_trade.png`、`camp_01_rest.png`。双击 `run_game.cmd` 从标题屏开启旅途。

## 本机最终验收

Godot 4.7.2，沙箱内 APPDATA / LOCALAPPDATA 指向 work/camp_01 下的独立测试目录，测试不改动正式存档。

```text
Import: exit=0, ERROR=0, WARNING=0
=== 汇总：passed=670 / total=670 ===
RESULT: ALL PASS
CAMP REDESIGN: 31 PASS, 0 FAIL
GAMEPLAY SYSTEMS: 76 PASS, 0 FAIL
CAMP/FOREST CONNECTION: 0 failures (16 PASS)
FOREST PHYSICS: 0 failures (42 PASS)
Data validation: 64 PASS, 0 FAIL
camp_01 headless smoke (120 frames): exit=0
```

营地专项检查包括从下层连续单跳上到交易层、S 下穿、六名 NPC 的正式动画与层级、补给入包、E 交互优先、交谈与背包互斥、坐火和跨房间初始重生。
