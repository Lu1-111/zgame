# 人物、武器与交互更新（2026-10-26）

按制作人本轮规格更新。双击根目录 `run_game.cmd` 进入标题屏并继续或开始旅途。正常房间、森林四个刷怪点和营地至森林的路线保留。

## 当前操作

| 输入 | 行为 |
|---|---|
| I | 打开 / 关闭人物面板，装备、属性、技能三个页签 |
| Tab | 打开 / 关闭行囊，材料独立页；人物按钮转入 I 面板 |
| Esc | 左半屏暂停选项，背景为变暗的当前游戏画面 |
| 鼠标左键 | 当前武器普通攻击；弓按住拉弓蓄力、松开射一箭 |
| 滚轮 | 在三个主动技能槽间选择，金色标记显示当前槽 |
| 鼠标侧键4 | 施放选中技能，定向技能随光标方向 |
| 1–5 / 点击右侧道具格 | 使用对应快捷物品 |
| E | NPC、篝火、宝箱等交互 |
| 对话中任意键 / 鼠标按键 | 下一句；不穿透为技能、攻击或菜单 |

旧 Q/E/R/F 技能和 T 调试换武器入口不再由玩家输入处理，武器统一在 I 面板拖拽交换。甲和两个饰品槽按要求显示锁定占位，本轮不实现其玩法。

## 人物面板与数据

装备页左侧详情、中部武器 / 护甲 / 饰品格子、右侧正式闲置角色和四个装备槽。武器拖到右侧槽会与旧装备交换；新装备离开格子，换下的回来源格。拖回空格可卸下，已装备武器不重复计入武器格。

属性页显示本级经验进度和十项当前属性。攻击力由等级、当前武器和天赋计算；减伤、吸血和每秒恢复读同一套实际战斗属性。满经验仍沿用已有成长机制升级。

技能页含十二主动和八被动。六个已有 / 新增主动有实际行为，其余六个主动为未解锁规划占位；两个初始被动为生命恢复、奶力恢复，其余六个被动为规划占位。锁定图标可查看详情，不能拖入槽。装配不允许同一技能重复占槽，拖入已有技能时交换对应位置。

物理技能只扣体力，奶术同时扣奶力与少量体力；任一资源不足时都不扣费。界面显示两种消耗、独立冷却和不可施放状态。

`data/rpg_systems.json` 管人物槽位、属性、初始测试武器和 UI 布局。`data/weapons.json` 的 `weapon_type` 区分 sword / hammer / bow / staff。`data/skills.json` 明确 category、damage_type、stamina_cost、mana_cost、unlock 和占位标记。

## 动作与特效

剑三段、锤三段为近战；弓为单段拉弓至释放，杖为独立奶术投射物。攻击期间水平速度为零。锤和杖复用已有正式角色动作；第一、二段锤特效移到武器区域，第三段按特效可见像素下端校准到脚底。新刀光、箭光和杖法球为独立特效素材，不改变人物。

制作人指出首版剑 / 弓图集人物不一致后，已撤下首版。现在仅取正式站立闲置第一帧的原始像素，画布固定 64×64、脚底锚点 (32,58)、运行时缩放 1 倍。手臂活动区以外的原人物非透明 RGBA 像素逐点相同；头、身、脚和尾巴不重画。手掌复制原图，武器放在相同像素网格。三段剑各四帧，弓八帧。

动作与特效挂点、时序和源路径在 `data/combat_presentation.json`；用 Godot 执行 `tools/build_pixel_weapon_actions.gd` 可重建原像素动作。错误人物稿隔离在 Godot 与 Git 均忽略的 `work/`，正式资源无引用。

## 物品、坐火和对话

快捷栏每格为 null 或实际 `{id,count}` 堆叠。拖入后原背包格腾空；拖回指定空格搬回，拖到已有消耗品格则交换；容量不足时保留原快捷物品。使用与丢弃直接修改对应容器。旧字符串快捷引用在加载时从原背包搬移一次，不复制物品。存档版本 3 记录三主动、两被动、当前选择与独立装备修订号，旧档装配列表自动迁移。

营地帐篷、炉子、铁砧、武器架、货箱、桌子、告示牌和植物按可见像素接地，避开透明画布留白造成的悬空。接地点在 `data/maps/camp_01_art.json`，由营地生成器写入正式场景。

坐火朝向会同步角色精灵镜像，再播放坐下与坐姿循环。NPC 对话使用半透明底部居中小窗，左头像和名字；对话冻结世界并独占输入，结束时清空动作缓冲。

## 验收

测试用户目录和存档重定向到工作区 `work/rpg_overhaul/`，不覆盖正式旅途。

```powershell
& 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --quit
& 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd
& 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tools/test_rpg_overhaul.gd
& 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/test_inventory_drag.gd
```

真实鼠标拖拽覆盖物品搬移 / 卸载、背包整理、武器装备 / 卸下和主动 / 被动技能装配。实机联动覆盖攻击锁位、弓单发蓄力、杖远程、锤三段与脚底对齐、像素身份、双资源扣费、旧档迁移、对话输入、坐火朝向和保存往返。

实机截图在 `docs/previews/rpg_*.png`，原像素同倍率对照为 `rpg_pixel_identity.png`；接地后的营地全图为 `camp_01_full.png`。

最终本机输出（Godot 4.7.2 Windows）：

```text
Import: exit=0, ERROR=0, WARNING=0
=== 汇总：passed=680 / total=680 ===
RESULT: ALL PASS
RPG OVERHAUL: 44 PASS, 0 FAIL
NATIVE DRAG: 0 failures (7 PASS)
GAMEPLAY SYSTEMS: 76 PASS, 0 FAIL
CAMP REDESIGN: 31 PASS, 0 FAIL
FOREST ENCOUNTERS: 26 PASS, 0 FAIL
FOREST PHYSICS: 0 failures (42 PASS)
CAMP/FOREST CONNECTION: 0 failures (16 PASS)
Data validation: 66 PASS, 0 FAIL
Headless smoke (120 frames): exit=0
git diff --check: exit=0
```
