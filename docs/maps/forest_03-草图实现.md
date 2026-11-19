# forest_03 · 藤影回廊

按制作人2026-11-12草图接入，场景为 `scenes/maps/forest_03.tscn`。布局唯一来源为 `data/maps/forest_03.json`，美术与装饰由 `data/maps/forest_03_art.json` 控制。

- 尺寸2560×1808，宽度为4个640像素屏幕，高度与forest_02相同。保留底层洞穴、右侧折返爬升、中层战场、左侧竖井、上方长廊与右侧回环。草图红框未做机关或连接。
- 灰色区域完整填实，沿用forest_02的圆角轮廓、苔岩包边与距离场过渡；蓝线20段全部为可上穿、可向下穿越的空心平台。主路每次爬升不超过96像素（基础单跳约112.36像素的85.4%）；较近的衔接台另计。所有标注的爬升路线均使用实际角色、单跳及真实碰撞验证，不需要二段跳。
- forest_02右下 `DoorEast` ↔ forest_03左下 `DoorWest`，到达后落在安全地面。
- forest_02新右上 `DoorEastShortcut` ↔ forest_03左上 `DoorWestShortcut`。只有03侧具有首次解锁权限，首次通过记录 `forest_02_canopy_link`，之后02侧屏障消失并可双向通行。两侧各用独立落点和短暂进门保护，避免上层传到底层或连续切图。
- 03右上仅保留未来出口，不连接其他地图，世界边界继续阻挡越界。
- 17只怪物：苔甲虫、飞奶蛾、藤鞭花、奶滴史莱姆共15只，苔甲卫2只。位置对应草图的三角与菱形；基础数值沿用现有登记表。
- 两组清场条件分别绑定底层5只怪和中层4只怪；必须包含对应苔甲卫死亡。两道白色动态迷雾具有实体碰撞，清场后淡出、解除阻挡，清场标记随存档保留，重进时不会因刷怪而重新封路。
- 宝箱共4个：上方长廊、回环尽头各1个普通箱；底层、中层各1个清怪箱。所有物品字段为空、数量0，开启只记录状态，不生成占位道具；清怪箱由附近同组怪物解封。
- 中层右侧1处篝火，已接入坐火菜单、复活点、解锁记录和快速旅行。世界地图同步加入03、实际双通道及捷径解锁状态。
- 32处场景装饰：复用forest系列倒木、残碑、菌簇、悬根，新增微光菌石、荚果垂藤、苔根拱3种。地面装饰按有效像素底边落地，悬挂物按顶边接顶；装饰位于层1，角色与敌人层20，不添加碰撞。[素材与生成记录](../../assets/environments/props/forest_03/README.md)，[雾墙素材](../../assets/effects/forest_mist_v1/README.md)。

`regions.json`继续保留15房规划拓扑；本图新增 `layout_data` / `playable_scene` 指向实际布局。当前可玩像素尺寸、对象、出口与未来未开放通路，以地图JSON和烘焙场景为准。

双击根目录 `test/launchers/run_forest_03.cmd` 直接测试；正常流程也可从forest_02右下进入。该入口沿用兼容渲染与60帧上限。

[布局预览](../previews/forest_03_layout.png) · [实际场景画面](../previews/forest_03_full.png)

重建与验证（Godot为本机4.7.2）：

```text
Godot --headless --path . --script res://tools/maps/process_forest_mist.gd
Godot --headless --path . --import
Godot --headless --path . --script res://tools/maps/build_forest_02.gd
Godot --headless --path . --script res://tools/maps/build_forest_03.gd
Godot --headless --path . --script res://tools/maps/gen_minimap.gd
Godot --headless --path . --script res://test/run_tests.gd
Godot --headless --path . --fixed-fps 60 --max-fps 240 --script res://test/integration/test_forest_03.gd
Godot --headless --path . --fixed-fps 60 --max-fps 240 --script res://test/integration/test_forest_02.gd
Godot --headless --path . --script res://test/integration/test_world_map.gd
python tools/data/sync_enemy_registry.py --check
python tools/qa/validate_data.py
```

2026-11-12本机验证输出摘要：

```text
Godot import: exit=0, diagnostics=0
=== 汇总：passed=1761 / total=1761 ===
RESULT: ALL PASS
FOREST_03 PHYSICS: 0 failures（25段真实单跳，雾墙/空箱/通道/存档/篝火）
FOREST_02 PHYSICS: 0 failures
WORLD MAP INTEGRATION: 0 failures
主场景与forest_03各120帧冒烟: exit=0, diagnostics=0
数据校验: 69项检查，0错误
ENEMY REGISTRY: SYNCED
REPOSITORY AUDIT: 1418 static resource references, 16 reserved batches, 0 errors
实际场景渲染: 2560x1808, error=0
```

实测使用独立测试存档目录，不改动正式游玩存档；渲染预览采用兼容模式和15帧上限，游玩入口为60帧上限。
