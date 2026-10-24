# 奶宝：银河征途

基于 Godot 4.x / GDScript 的 2D 横版类银河恶魔城原型。本期范围为奶泉营地、奶源林地、蜜乳洞窟，共 15 个房间，具体要求见 [开发计划书](docs/开发计划书-奶龙银河征途.md) 与 [工程公约](AGENTS.md)。

## 克隆与运行

仓库为私有仓库，需要使用拥有访问权限的 GitHub 账号。安装 Git 与 Godot **4.7.2** 后执行：

```bash
git clone https://github.com/Lu1-111/zgame.git
cd zgame
godot --headless --path . --import
godot --path .
```

也可以用 Godot 编辑器导入根目录的 `project.godot`，等待素材导入完成后运行主场景。本机 Linux 环境可双击 `run_game.sh`；引擎默认路径为 `~/.local/bin/godot`，也可通过 `GODOT_BIN` 指定。

仓库包含脚本、场景、数据表、文档、素材处理工具，以及 `assets/RAW/` 原始素材与 `assets/PROCESSED/` 正式素材。无需 Git LFS 或另行下载素材。Godot 缓存、Python 虚拟环境、导出构建与会话临时工作区不入库，在新机器上按需生成。

## 本地检查

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
