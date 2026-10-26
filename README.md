# 奶宝：银河征途

基于 Godot 4.x / GDScript 的 2D 横版类银河恶魔城原型。本期范围为奶泉营地、奶源林地、蜜乳洞窟，共 15 个房间，具体要求见 [开发计划书](docs/开发计划书-奶龙银河征途.md) 与 [工程公约](AGENTS.md)。

## 克隆与运行

仓库已公开，任何人均可直接克隆，无需登录 GitHub。安装 Git 与 Godot **4.7.2** 后执行：

```bash
git clone https://github.com/Lu1-111/zgame.git
cd zgame
godot --headless --path . --import
godot --path .
```

也可以用 Godot 编辑器导入根目录的 `project.godot`，等待素材导入完成后运行主场景。Windows 双击 `run_game.cmd`，Linux 使用 `run_game.sh`，也可通过 `GODOT_BIN` 指定引擎。正常流程为标题屏 → camp_01 → 营地右侧出口 → 新版 forest_01（巨木草图关卡）；森林左下入口可返回营地。

仓库包含脚本、场景、数据表、文档、素材处理工具，以及 `assets/RAW/` 原始素材与 `assets/PROCESSED/` 正式素材。无需 Git LFS 或另行下载素材。Godot 缓存、Python 虚拟环境、导出构建与会话临时工作区不入库，在新机器上按需生成。

## 本地检查

游戏中 I 打开装备 / 属性 / 技能人物面板，Tab 打开行囊；滚轮选择三个主动技能，鼠标侧键4施放。E 负责交互，坐火后可休息、点天赋和存取仓库。消耗品拖入快捷栏后腾出原背包格，武器拖入人物武器槽完成交换。营地补给箱提供实际道具；人物武器页提供直剑、步枪、杖供测试。说明见 [人物、武器与交互更新](docs/RPG人物武器与交互更新.md) 和 [玩法系统与魔幻 UI](docs/玩法系统与魔幻UI.md)。

最新更新：双手直剑改为纵斩、挑斩、横斩，分别使用独立刀光；原弓替换为可连续瞄准的单发步枪；斩击技能改为大型贯穿剑气；右键格挡支持举手保持与松键放下。全部界面采用简约暗色风格、简洁物品图标与油画技能图标。见 [直剑、步枪与简约界面预览](docs/直剑步枪与简约界面-2026-10-27.md)。

此前敌人索敌、平台交界、真实伤害与接触碰撞修复见 [问题修复与验收](docs/问题修复-2026-10-27.md)。

`forest_01` 草图地图可直接双击 `run_forest_01.cmd`（Windows）或执行 `bash run_forest_01.sh`（Linux）试玩。平台类型、通道、重建命令和预览见 [草图实现说明](docs/forest_01-草图实现.md)。

旧的 `tools/build_forest.gd` / `tools/build_forest_dark.gd` 统一调用新版生成器，重建时不会恢复旧森林地图。主流程往返验收：`godot --headless --path . --fixed-fps 60 --script res://tools/test_door.gd`。

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 120
```

提交前必须确保导入检查退出码为 0 且无 `ERROR`，单元测试全部通过。架构与数据说明分别见 [框架说明](docs/框架说明.md)、[数据契约](docs/数据契约.md)。

## 分支约定

- `main`：可运行的基线版本，默认克隆此分支。
- `dev`：开发集成分支，功能合并后通过本地检查再进入 `main`。
- `feat/*`：功能分支；提交信息采用 `type(scope): 描述`。
