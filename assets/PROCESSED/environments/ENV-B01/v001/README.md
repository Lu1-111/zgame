# ENV-B01 v001 地图美术交付

日期：2026-10-24。内置 image_gen 生图，三个美术子代理分工制作，主代理统一编排地图并进行 Godot 与离线预览验证。

直接打开 [preview.html](preview.html)。页面自包含图像，无需联网；支持世界连接、逐房切换、16px 网格、角色比例、设计标记、图层与缩放。美术场景可在当前 Godot 工程中打开，不需要安装插件。

## 文件入口

- `ENV-01/` 奶泉营地：营地与商人室内背景、9 件模块（含小型回营光纹）。
- `ENV-02/` 奶源林地：横向/竖向背景、中景、9 件模块。
- `ENV-03/` 蜜乳洞窟：背景、4 件模块。
- `ENV-04/` 蜂巢分区：背景、专用 1280×360 大厅背景、4 件模块。
- `godot/ENV-01.tres`～`ENV-04.tres`：四套 16×16 TileSet，每套16张基础图块，带 world 层方形碰撞。当前采用明确索引绘制，不是完整 47 格自动地形。
- `maps/<room_id>/`：15 房完整地图与分层图。`map.png` 完整美术，`design.png` 设计标记版；背景、中景、地形、装饰、危险、标记分别保存。
- 每房 `<room_id>.tscn`：可编辑 TileMapLayer 美术场景。按原平台矩形生成精确碰撞，非整格端部用裁片；独立图块碰撞在这些场景中关闭，避免重复碰撞。
- 每房 `layout.json`：原房间、来源校验和、平台图块位置、道具锚点与层级。`map.tmj` 是 Tiled 可打开的图像分层与碰撞对象图，不宣称已绘制 Tiled tilelayer。
- `world_atlas.png`：带连线的 15 房静态总览。位置来自 `map_rect`，表示拓扑，不是连续世界坐标。
- `delivery_preview.png`：四套环境同规格总览。
- `VALIDATION.json`、`verification.txt`：实际验证范围、输出与限制。

RAW 共12张，位于 `assets/RAW/environments/ENV-B01/v001/`。每套保留完整 prompt、来源、尺寸和 SHA-256；本批使用内置工具，没有调用 API fallback。成品共64张基础图块、26件透明模块、15房地图。原画从未被后处理覆盖。

## 箱庭设计如何落地

研究记录在 `docs/地图设计研究-ENV-B01.md`，含开发者访谈与官方文档来源。设计以巨木、奶泉、荧矿、采集蜂巢建立地标；林地小回环、断桥能力回访和女王后的回营大回环在连接图中区分。每房都有构图与节奏说明。

为避免视觉误导，断桥使用单独桥面锚点对齐 y=340；森林出口洞口与边界门对齐；大株植物和岩石放在地形后方；回营小提示适配顶部落点；女王大厅采用新生成的宽背景，使中部战斗空间保持空净。背景不直接横向拉伸覆盖宽房。

## 如何重建

在项目根目录依次运行：

```bash
.venv/bin/python tools/build_environment_maps.py
~/.local/bin/godot --headless --path . --import
~/.local/bin/godot --headless --path . --script res://tools/build_environment_maps.gd
~/.local/bin/godot --headless --path . --script res://tools/check_environment_maps.gd
.venv/bin/python tools/validate_environment_maps.py
~/.local/bin/godot --headless --path . --script res://tests/run_tests.gd
```

`tools/environment_map_design.json` 管理逐房构图和视觉配置；世界定义仍只读 `data/world/regions.json`。原画加工步骤、裁片和锚点在各套 `kit.json` 内。

## 交付边界

本批完成地图素材与独立美术场景，未替换现有可玩关卡。现有营地/巨木森林场景与15房数据表有差异，合并应另行处理。地图中的门、怪物、篝火、奖励是构图素材或语义标记；不包含新的门触发、敌人AI、交互、存档和BOSS封门逻辑。危险是独立静态设计覆盖，未制作酸池动画。

平台位置与宽高忠实保留世界表，局部16px图块不改变跳跃距离。逻辑可达验证不代表物理通关；尤其当前单跳高度已经制作人调整，二段跳门仍需实际能力前后走查。参考书要求更多“看得见摸不着”的奖励点，当前数据尚未全部覆盖，研究文档已列为后续关卡建议。
