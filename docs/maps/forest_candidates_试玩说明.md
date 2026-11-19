# Forest 十个备选场景 — 实际试玩

制作人2026-11-16追加要求“先做成实际场景”。已将此前十张草图全部做成独立Godot场景，复用现有森林墙体、苔缘、薄平台、背景、正式角色及怪物。它们属于评审试玩，集中在test，尚未替换或连接正式01～04地图。

## 启动与操作

双击[test/launchers/run_forest_candidates.cmd](../../test/launchers/run_forest_candidates.cmd)，进入选图界面。该入口使用本机Godot4.7.2并限制60FPS，使用work/forest_candidates的独立用户目录。

| 操作 | 功能 |
|---|---|
| A/D、左右箭头 | 移动 |
| Space | 跳跃；开启二段跳后可在空中再按一次 |
| 鼠标左/右键 | 现有攻击/格挡 |
| E | 机关、升降篮、检查点、空宝箱、接口 |
| F6 | 返回十图选择界面 |
| F7 | 开关二段跳，对比能力前后的路线 |
| F8 | 完整重置当前候选的机关、清怪与箱子 |
| R | 回到本图检查点 |
| M | 当前候选地图；再次M或Esc关闭，查看时暂停世界 |

右上方也有切图、重置、地图、二段跳和回检查点按钮。所有测试场景均带disable_save标记，存档系统明确拒绝写入；本次试玩的机关/宝箱/清怪状态只在当前进程的会话中保留。通过选图入口或原有暂停菜单回到正式标题时，恢复进入前的旅途状态。

## 实际场景与玩法

| 场景文件（test/scenes/forest_candidates/） | 已接入的操作 |
|---|---|
| forest_05A.tscn 分水根庭 | A排空中渠并解除实体阻挡，B排底渠、开永久捷径；水层随机关消失 |
| forest_05B.tscn 双篮树井 | A升降左篮，B召右篮到中层，C升降右篮；两个篮筐可真实载人，停靠层有召回柄 |
| forest_06A.tscn 折光菌窟 | A开光源，B轮换镜座方向，命中C后开放通路；墙内导光槽只有视觉，不是可走的通道 |
| forest_06B.tscn 风息风琴 | A/B/C逐档导风；风叶逐级转动显示通断，三段接通后开门 |
| forest_07A.tscn 断冠攀环 | 交错跳台、跨坑落点、中段检查点、可开启的下环捷径与高架能力口 |
| forest_07B.tscn 裂谷折返 | 分段下降、谷底跨越、东岸上攀、上桥捷径和二段跳高口 |
| forest_08A.tscn 苔甲三庭 | 三庭真实战斗与分组封印；两相邻庭之间可按任一侧清场结果往返，不将反向来客锁在门外 |
| forest_08B.tscn 树心双层堂 | 下厅近战、上厅远近组合；背面开下廊，清场开出口及高架口 |
| forest_09A.tscn 断根哨营 | 西哨与两处围场、上层回访廊、额外下层空箱 |
| forest_09B.tscn 盘根防线 | 中庭精英或下沟小怪两路任选；任一路完成可开放东侧并开主奖励空箱 |

宝箱目前只记录打开，不发放尚未确定的奖励。篝火S和07的A是试玩检查点，恢复资源并更新R的落点；不打开正式坐火/仓库菜单，不登记新的正式旅行点。其余战斗、武器和技能沿用现有实现。

## 接口与反向进入

以下新候选之间已经能够通过E往返，目标组采用本次会话里已选择的A/B；没有选择过的组先沿用当前版本字母。

- 05 E3 ↔ 08 E2
- 06 E3 ↔ 09 E2
- 07 E3 ↔ 08 E3（需要二段跳）

通往01、02、03和待建04的接口，当前显示目标并保留落脚位置。正式世界没有凿新入口，既有门、存档和世界地图登记不变。

从右侧或高架进入战斗图时，先允许进入本侧战场，完全进入后再闭合封印；击败本侧怪物后能够向另一侧推进。封印也覆盖平行支口，不能通过高台绕过未清战斗。09B的两条主路不要求全部清理。

## 几何适配与资源定位

草图不是碰撞网格，因此实际场景对平台和门做了适配：常规台阶按约85世界单位升高，能力口净高约160；新增井口停靠台、机关脚下落脚台；把部分战斗门移到场地边缘，避免隔门无法击杀剩余怪物。所有实体台和轮廓都已烘焙到tscn，在编辑器内可以直接查看。

- 试玩布局与参数：test/data/forest_candidates/、test/data/forest_candidates_rules.json。
- 运行与会话：test/scripts/forest_candidates/。
- 地图参考纹理：test/assets/forest_candidates/。
- 实际Godot渲染预览：test/previews/forest_candidates/。
- 从草图转数据：python tools/maps/prepare_forest_candidates.py。
- 烘焙十图：Godot --headless --path . --script res://tools/maps/build_forest_candidates.gd。
- 真实物理验收：Godot --headless --path . --fixed-fps 60 --script res://test/integration/test_forest_candidates.gd。

装饰只补了贴在真实平台顶面的原生像素小草；机关使用简洁像素示意。选案后的最终环境装饰、完整谜题演出、奖励与正式世界接入仍需按反馈继续定稿。本轮没有触发版本发布。

## 本轮验收

```text
最终导入检查：exit=0，diagnostics=0
FOREST CANDIDATES: 10 scenes, 0 failures
130 项试玩断言通过，包含290个薄平台的真实站立检查
10处能力口：普通跳跃不可达，二段跳可实际落上
05B：左右升降篮真实载人到达停靠层
08A：上层平行通道不能绕过未清封印
09B：只清下沟路线也可开放出口，不必清中庭
05A ↔ 08A：实际切图、反向入场、重访状态保留
M地图：暂停/恢复真实玩家与场景
退出试玩：恢复进入前旅途；测试场景与选图页均禁止写正式存档
RESULT: ALL PASS — passed=1761 / total=1761
REPOSITORY AUDIT: 1836 static resource references, 16 reserved batches, 0 errors
```

这不是最终难度或完整通关平衡验收，仍需制作人在实际游玩后选案和调整。日志与结构化结果位于work/qa/candidates_physics.log和work/qa/forest_candidates.json。
