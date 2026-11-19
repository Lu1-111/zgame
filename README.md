# 奶宝：银河征途

Godot 4.7.2 / GDScript 的2D横版类银河恶魔城原型。玩法与工程约定见[开发计划书](docs/开发计划书-奶龙银河征途.md)、[AGENTS.md](AGENTS.md)及[数据契约](docs/数据契约.md)。

## 运行

```bash
git clone https://github.com/Lu1-111/zgame.git
cd zgame
godot --headless --path . --import
godot --path .
```

Windows双击`run_game.cmd`，Linux执行`bash run_game.sh`；可用`GODOT_BIN`指定引擎路径。也可在Godot编辑器导入`project.godot`，等待首次导入后运行主场景。Windows测试入口采用兼容渲染和60帧上限。

- 主流程：标题 → camp_01临时据点 → forest_01 → forest_02 → forest_03；营地、森林双通道和捷径已经连接。
- `test/launchers/run_forest_01.cmd`、`test/launchers/run_forest_02.cmd`、`test/launchers/run_forest_03.cmd`：直接测试森林场景。
- `test/launchers/run_corrumpt.cmd`：测试克拉弗特600/1000生命的完整双阶段。
- `test/launchers/run_corrumpt_phase2.cmd`：直接测试克拉弗特第二阶段，使用独立测试存档。
- `test/launchers/run_cave_materials.cmd`：cave岩壁、装饰、金属宝箱、晶石光源、石笋与石台的实际素材预览；[使用说明](docs/art/cave素材包-v001.md)。

## 操作与当前内容

A/D或方向键移动，Space跳跃，Shift闪避，左键普通攻击，右键格挡，E交互；Tab行囊，I人物面板，L任务，M世界地图，Esc关闭界面/暂停。滚轮选择三个主动技能，鼠标侧键4施放，数字键1–5使用快捷物品。

开发与运行统一使用逐帧动画；现有闲置、锤、杖等原角色素材是动作形象基准。武器、装备交换、背包拖拽、灵火休息/仓库/快速旅行、任务追踪和实时世界地图已接入。十二种主动技能与八种被动技能的图标及原动作保留；未放入地图的怪物素材仍保留。

- 地图：[营地](docs/maps/camp_01-营地重制.md)、[forest_01](docs/maps/forest_01-草图实现.md)、[forest_02](docs/maps/forest_02-草图实现.md)、[forest_03](docs/maps/forest_03-草图实现.md)。
- 角色：[当前逐帧剑动作](docs/art/原形象七步逐帧剑动作-2026-10-27.md)、[格挡与成长](docs/gameplay/格挡成长与仓库更新-2026-10-28.md)、[十二技能](docs/gameplay/十二技能接入-2026-10-28.md)。
- 系统：[任务与韧性](docs/gameplay/韧性与任务系统-2026-10-31.md)、[削韧数值](docs/gameplay/削韧值填写表.md)、[怪物数值记录](docs/gameplay/怪物数值记录表.md)。
- Boss：[一阶段](docs/gameplay/corrumpt第一阶段.md)、[二阶段与最新战斗规则](docs/gameplay/corrumpt第二阶段.md)。

所有战斗与场景数值以`data/`中的JSON为准。敌怪档案按固定数字ID分为[小怪](docs/gameplay/小怪记录.md)、[精英怪](docs/gameplay/精英怪记录.md)、[Boss](docs/gameplay/Boss记录.md)，含未实装储备与待填写参数。制作人可直接填写“设定值”列，再执行`python tools/data/sync_enemy_registry.py --import-docs`校验回填JSON；直接修改JSON后执行同步命令（不带参数），校验用`--check`。新增敌怪和区域等级按[档案使用说明](docs/gameplay/敌怪档案使用说明.md)登记。

## 素材与仓库

`assets/RAW/`保留原始制作素材，`assets/PROCESSED/`保留正式动作、怪物、技能及尚未接入的内容。它们随仓库同步，无需Git LFS或额外下载。不得仅依据“运行时未引用”删除技能、怪物及NPC储备素材。

已清理弃用动作/界面/Boss试制版本，当前Boss固定母版保存在`v005/sources/approved_reference/`，正式版本为`v005/`和`phase2_v001/`。当前重建工具在`tools/`；美术重建需要Pillow和ImageMagick 7，运行已制作游戏不需要这些依赖。

Godot缓存、素材中间文件、测试存档和本次可恢复清理副本位于忽略区，不上传。清理范围、保留清单及验证结果见[仓库精简记录](docs/engineering/仓库精简记录-2026-11-03.md)。历史Git提交保持完整。

## 本地检查

```bash
godot --headless --path . --import
godot --headless --path . --script res://test/run_tests.gd
godot --headless --path . --quit-after 120
python tools/qa/validate_data.py
python tools/qa/audit_repository.py
python tools/data/sync_enemy_registry.py --check
```

Boss实测入口：`test/integration/test_corrumpt_runtime.gd`、`test/integration/test_corrumpt_phase2.gd`、`test/integration/test_corrumpt_revision.gd`、`test/integration/test_corrumpt_poise.gd`、`test/integration/test_corrumpt_sequences.gd`、`test/integration/test_corrumpt_ground_recovery.gd`，通过Godot的`--headless --script res://...`执行。后两项覆盖转阶段CG、虚空湮灭、存活胜利与死亡重试，以及落地四秒/双倍削韧和红光后的精确延迟；[实际演出预览](docs/previews/corrumpt_sequences.mp4)。

`main`为可运行版本，`dev`为开发集成分支。提交采用`type(scope): 描述`；同步前必须通过导入、单元及相关实测。


## 目录导航与版本发布

完整分类与发布规则见[项目目录与发布流程](docs/engineering/项目目录与发布流程.md)。所有演练、测试场景和直接测试启动器位于[test](test/README.md)，正式地图位于scenes/maps/。运行素材见[素材索引](assets/README.md)。

本次调整与验证见[2026-11-16项目整理记录](docs/engineering/项目整理记录-2026-11-16.md)；[五组A/B草图](docs/concepts/2026-11-16_forest_links/README.md)已按追加要求做成[十个实际试玩场景](docs/maps/forest_candidates_试玩说明.md)，选定后再接入正式世界。

仅在制作人明确版本更新并给出版本号时，完成检查、导出可执行beta并单独上传GitHub Release；源码同步和beta分开发送。普通修改不自动发布。
