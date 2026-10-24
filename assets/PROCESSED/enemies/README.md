# 敌人素材库：ENM-B03 / ENM-B04

最新组合索引为 `manifest_b04.json`，共 **15 个视觉类型**；游戏表已有的 **12 类敌人全部使用新素材接入**。原 `manifest.json` 的 `latestLibraryIndex` 指向该索引。

[ENM-B04 成品与说明](ENM-B04/v001/README.md) 重做旧库剩余7类，并补飞奶蛾与蜂蜜女王，含63组主体/288帧、三组弹体/18帧。可打开 [离线动作预览](ENM-B04/v001/preview.html) 与 [造型总览](ENM-B04/v001/contact_sheet.png)。

[ENM-B03](ENM-B03/v001/README.md) 保留6类42主体动作/192帧及6组攻击FX/36帧。素材包不再嵌套独立 project.godot，直接由主工程导入。主菜单 **F2 进入12类战斗演练**。

以下 v002 为历史基础记录，新交付请以 manifest_b04.json 为准。

## v002 基础阵容

基础阵容覆盖昆虫、人形、动物、魔兽和植物型。所有 v002 版本均通过 RAW 来源像素一致性、透明度、裁边、root、sheet/atlas 和 Godot SpriteFrames 实际加载验收。

| ID | 小怪 | 类型 | 动作数 | 帧数 | 固定 root |
|---|---|---|---:|---:|---|
| ENM-01 | 苔甲虫 | 昆虫型 | 7 | 38 | `(32,58)` |
| ENM-02 | 奶罐哥布林 | 人形 | 7 | 38 | `(32,58)` |
| ENM-03 | 奶滴史莱姆 | 魔兽型 | 15 | 84 | `(32,58)` |
| ENM-04 | 苔原奶狐 | 动物形 | 7 | 38 | `(32,58)` |
| ENM-05 | 霜晶冰灵 | 魔兽型 | 7 | 38 | `(32,32)` |
| ENM-06 | 暗影奶灵 | 魔兽型 | 8 | 44 | `(32,32)` |
| ENM-07 | 藤鞭花 | 植物型 | 7 | 38 | `(32,58)` |
| ENM-08 | 蜜蜡蜂 | 昆虫型 | 7 | 38 | `(32,32)` |
| **合计** | **8 种** | **5 类** | **65** | **356** | **9 套 SpriteFrames** |

## 精细动作

- 基础 7 动作 / 38 帧：idle 6 / move 8 / telegraph 4 / attack 6 / recover 3 / hurt 3 / death 8。
- 哥布林：双关节腿部和逐帧棍棒挥击；奶狐：步态、尾巴跟随和扑咬；冰灵：冰晶攻击和逐步碎裂。
- 史莱姆另有 split 8 帧和 child 全套 38 帧；暗影奶灵另有 immune 6 帧。
- telegraph 为 4 帧 / 10fps / 0.4s；attack 为 6 帧 / 14fps。攻击判定和状态切换仍由游戏逻辑配置。

## 使用

- 每种位于 `ENM-XX/v002/`；逐帧、单行 sheet、规则 atlas、manifest、QA 和离线 preview 均已提供。
- 主资源：`godot/ENM-XX_sprite_frames.tres`；史莱姆子体使用 `ENM-03_child_sprite_frames.tres`。
- 画布 64×64，右向，Nearest。以 root 对齐节点原点时，`AnimatedSprite2D.centered=false` 并设置 `offset=-root`：地面单位 `(-32,-58)`，飞行单位 `(-32,-32)`。
- 本批仅交付右向；左向镜像和游戏内手感/碰撞接入需另行验收。

## 总验收

- `manifest.json`：当前 v002 索引；`qa.json`：`passed=true`、8 种、65 套、356 帧、0 错误。
- `contact_sheet_v002.png`：八类主造型与 root 总览；各子目录提供逐动作审查图和离线播放。
- Godot 4.7.2 导入通过；9 个 SpriteFrames 实际加载、帧数、fps、循环和 64×64 atlas 格子检查通过。
- v001 保留作历史版本；`manifest_v001.json`、`qa_v001.json` 不是当前索引。

复现与验证命令见 `work/enm_pipeline/README.md`。
