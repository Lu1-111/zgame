# 玩法系统与魔幻 UI（2026-10-25）

2026-10-26 操作、人物面板和武器更新见 [人物、武器与交互更新](RPG人物武器与交互更新.md)，以下操作说明已同步为当前版本。

本轮补齐 forest_01 外圈填墙和边缘过渡、常驻 HUD、坐火、背包、仓库、天赋及存档。正常路线仍为标题屏 → camp_01 → 营地右侧出口 → forest_01。

## 操作与试用

Windows 双击 `run_game.cmd`。营地右半侧原有木箱现为可打开的补给箱，E 获得奶瓶、奶力药剂、体力药剂和奶弹；新旅程背包初始仍为空，没有自动授予预览物品。

| 操作 | 结果 |
|---|---|
| Tab | 打开 / 关闭行囊，暂停世界 |
| 点击格子 | 右侧显示详情、使用与丢弃；空格清空详情 |
| 拖动行囊物品 | 移动、交换或合并同类堆叠 |
| 拖到下方快捷栏 | 搬入真实消耗品堆叠，腾出原背包格 |
| 从快捷栏拖回行囊 | 搬回指定背包格；满包时保留物品 |
| 数字 1–5 / 点击右侧快捷格 | 使用已注册物品 |
| I | 人物面板：装备 / 属性 / 技能 |
| 滚轮 / 鼠标侧键4 | 选择三个主动技能之一 / 朝光标施放 |
| E | 交互；新规格下不再施放技能 |
| E 坐火 | 坐下、恢复三资源、设置复活点并保存，打开休息菜单 |
| 休息菜单 | 休息 / 天赋 / 仓库 / 离开；离火有起身动作 |
| Esc | 关闭当前菜单；游戏中打开暂停菜单，可保存并返回主菜单 |

## 地图与表现

forest_01 仍为 1280×1856、31 段独立平台；四块新增墙填实外部空白，共 16 块墙。三个通道均保留，去掉所有通道说明文字。墙体边缘一格依据占用遮罩做暗部、苔色和微小不规则透明过渡，平台落脚线与碰撞层不变。

HUD 左上为主角头像连接生命 / 体力 / 奶力条，0.15 秒平滑、低血量脉冲、体力回复高亮、奶力不足灰显及受击红边。右侧五格快捷栏，底部三个主动技能带选中标记、独立冷却扇形和解锁状态，最后使用的物品格放大到 110%。16:9 / 16:10 下保持边缘和中心定位。

界面为本轮原创代码绘制的 10 张 SVG（古金边框、符文、宝石量条和技能图标），通过 `tools/build_magic_ui_assets.py` 重建。头像、坐姿、物品图标复用 CHR-01 / ITM-B01 正式素材，文字和控件由 Godot 实时绘制。

## 背包、仓库和天赋

`scripts/core/inventory_service.gd` 为统一规则入口：15 格起步，最多扩容三次，每次五格；基础界面四列十六格，未扩容时末格锁定。消耗品每堆最多 5，材料独立页每堆最多 99；武器进入独立装备列表。扩容后自动增加可滚动行。

接收物品先做整批容量检查。满包时不改变背包、宝箱开启状态或场上掉落；`WorldPickup` 接收成功后才消失，不能重复结算。拖拽与仓库存取保持数量守恒。快捷栏独立持有真实堆叠，使用和丢弃均只扣除所在格的数量。资源已满时使用回复品不扣数量；碎片、地图、扩容及能力道具依物品表生效。

仓库无限格，独立于行囊。取回前检查容量，失败时保持仓库原样。天赋要求前置、点数和奶币，重置收取 200 奶币、退点不退购买奶币，属性和战斗修正实时生效。三段跳仍按计划书预留禁用。技能装配移到 I 面板，支持三个主动和两个被动槽。

## 坐火与存档

坐火使用 `rest_enter` → `rest` → `rest_exit` 正式动作。暂停世界时只让界面与坐姿动画继续，离开清除输入缓冲。休息恢复资源和冷却、刷新普通敌人，已击败 BOSS 不复活。检查点记录房间与实际坐下位置，死亡可跨房间返回。

每个档位为 A/B 双槽轮换，带版本、序号、CRC32 和 `.bak`；先写临时文件再替换。加载最高序号的有效记录，损坏时回退另一槽或备份。坐火、切房、保存回主菜单和关闭窗口时保存，战斗中禁止自动保存，演练场不写正式旅途。标题屏检测到有效存档会显示“继续旅途”。新增状态字段均支持旧存档默认值恢复。

数值入口：`data/gameplay_ui.json`；关卡：`data/maps/forest_01.json`；地形表现：`data/maps/forest_01_art.json`。

## 验证与预览

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_gameplay_ui.gd
godot --path . --fixed-fps 60 --script res://tools/test_inventory_drag.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_forest_sketch.gd
godot --headless --path . --fixed-fps 60 --script res://tools/test_door.gd
```

拖拽用例向 Godot Viewport 发送真实的鼠标按下、移动和释放事件，验证注册、卸载与格子移动；不会通过直接改模型来代替拖拽。

`tools/preview_game_ui.gd` 渲染 hud / inventory / rest / talents / storage，追加 `16_10` 参数检查另一种比例；预览使用独立测试数据，不是新旅程的默认物品。文件位于 `docs/previews/ui_*.png`。

本机验证使用 Godot 4.7.2 Windows 控制台程序，沙箱内的 APPDATA / LOCALAPPDATA 指向工作区独立测试目录；正常启动使用用户目录。最终结果：

```text
Import: exit=0, ERROR=0, WARNING=0
=== 汇总：passed=670 / total=670 ===
RESULT: ALL PASS
GAMEPLAY SYSTEMS: 76 PASS, 0 FAIL
FOREST PHYSICS: 0 failures (42 PASS)
CAMP/FOREST CONNECTION: 0 failures (16 PASS)
NATIVE DRAG: 0 failures (3 PASS)
Data validation: 64 PASS, 0 FAIL
Headless smoke (120 frames): exit=0
git diff --check: exit=0
```

实际渲染截图尺寸为 1280×720 和 1280×800，后者通过 expand 拉伸策略增加纵向视野；模态窗口居中，快捷栏贴右，技能栏贴底。
