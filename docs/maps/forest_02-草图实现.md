# forest_02 · 古根回廊

制作人 2026-10-29 草图的新可玩场景为 `scenes/maps/forest_02.tscn`，替换原来的连接预览房。布局唯一来源为 `data/maps/forest_02.json`，美术配置为 `data/maps/forest_02_art.json`。

- 尺寸 2768 × 1808 像素，横向约 4.33 个 640 像素屏幕。保留上层长廊、双竖井、左侧回环、中央洞厅和底部通路。
- 42 段平台全部为 `oneway`，独立标签、碰撞层 128，可上穿、按 S 下穿。可站立的厚地形属于实体墙体，没有独立实心平台。中层长廊至西侧上层竖井之间增加一段返回踏台，将 192 像素落差拆为两次 96 像素单跳。
- 当前基础跳高约 112.36 像素。指定爬升路线高差为约 0.5–0.9 跳高，并以真实角色单跳验证。灰色区域填满；斜坡边界采用裁切碰撞多边形，避免格子台阶卡住行走。
- 背景、墙体、平台、苔藓、藤蔓和植物均复用 forest_01 素材。两幅相邻巨树背景镜像拼接，保持树木比例；地面道具按有效像素底边落地，藤蔓按有效顶边接顶。
- 普通宝箱 3 个，战斗封印箱 2 个，篝火 1 处。机关开关加大并显示绿色晶体，同一开关打开两处绿晶封印门，状态写入存档。
- 当前不放怪物与 NPC。战斗箱保持封印，后续通过 `encounters[].spawn_ids` 关联清怪条件，空遭遇组不会被误判为清场。
- 左上 `DoorWest` ↔ forest_01 `DoorEast`。左下 `DoorWestShortcut` ↔ forest_01 `DoorEastShortcut`；首次从 forest_02 左下穿过会永久记录 `forest_01_roots`，forest_01 的根部封堵随之消失。
- 2026-11-12：右下通道现已连接 forest_03 左下入口；右上按制作人标记切开墙体，接入 forest_03 左上捷径。该捷径必须先从03侧通过一次，之后双向通行；解锁前02侧有白雾屏障。
- `regions.json` 保留规划阶段的逻辑房格及未来拓扑，通过 `layout_data` / `playable_scene` 指向本次实际地图；实际像素尺寸、道具和通道落点以本地图 JSON 和场景为准。

双击 `test/launchers/run_forest_02.cmd` 可以直接测试本图。游戏内按 M 查看布局；从正常游戏的 forest_01 上层或已解锁的根部通道也可进入。

2026-10-29 后续修整：开关使用独立的透明遗迹机关贴图 `assets/environments/props/forest_02/ancient_ruin_switch_v1.png`，由内置 image_gen 绘制，完整提示词保存在同目录的 `.prompt.txt` 文件。有效底边落地，外观宽 104 像素；激活后调整亮度，与同色门逻辑关联。

洞室先合并并保留回环内部的实体墙孔洞，再按 20 像素半径切出圆滑轮廓；渲染和物理使用同一轮廓，额外的距离场负责墙边的软过渡。图中窄井、箱子和篝火地面的基本位置保持不变。

M 现由全局 GameUI 统一打开总览，涵盖 camp_01、forest_01、forest_02、forest_03；五条实际配对通道分别显示，两条未解锁捷径以暗色连接及锁标记表示。位置标记逐帧读取当前房间 Player 坐标；世界地图坐标和房间局部坐标统一换算。地图打开时沿用其他模态界面的暂停规则，支持滚轮缩放、鼠标拖动、总览复位，M 和 Esc 均关闭地图并恢复游戏。原房间内独立地图输入已移除，避免一键同时弹出两个地图或暂停菜单。

墙缘与装饰修整：参照 forest_01 的厚苔岩表层，使用同一平台图集中的 `solid` 岩根素材绘制纯视觉墙顶包边，表层厚度 24 像素；沿轮廓连续展开纹理，每段曲线不再重新压缩左右端帽，保留根须自然垂落。侧壁和洞顶使用同色材质，距离场改为带符号编码，使透明过渡从真实轮廓开始。此调整不添加实心平台，也不改变已有地形碰撞和返回踏台。

新增四种独立绘制的装饰，放置 34 处（倒木、残碑、菌簇、洞顶悬根）；素材及提示词见 `assets/environments/props/forest_02/DECORATIONS.md`。地面与悬挂物分别按有效像素底边及顶边连接地形，全部位于角色下方，无碰撞，不干扰通道、开关、箱子和篝火交互。

构建和验证：

```text
Godot --headless --path . --script res://tools/maps/build_forest_02.gd
Godot --headless --path . --import
Godot --headless --path . --script res://test/run_tests.gd
Godot --headless --path . --fixed-fps 60 --max-fps 0 --script res://test/integration/test_forest_02.gd
Godot --headless --path . --script res://tools/maps/gen_minimap.gd
```

`build_forest_sketch.gd` 已停止生成旧连接预览，重新构建 forest_01 不会覆盖本图。
