# 已实装怪物攻击动作核查

2026-11-17。逐一追踪正式camp/forest_01/02/03和森林十个候选的地图数据、PackedScene、运行控制器与目录清单。正式森林场景中未显式写enemy_id的节点沿用默认moss_beetle，已计入。营地无敌人；场景路由只允许进入存在的地图场景，旧15房定义不等于已经落地的15张图。

结论：本轮已实装的五种敌怪都已有真实、互不相同的攻击帧，属于已有素材需要正常发挥的情况，不应重生成来掩盖接入/触发问题。

| 实装敌怪 | 已有动作与数量 | 直接读取的素材清单 |
|---|---|---|
| 苔甲虫 moss_beetle | telegraph4 / attack4 / recover4，另有idle/move/hurt/death | ENM-B03/v001/catalog.json（ENM-01） |
| 飞奶蛾 milk_moth | telegraph4 / attack4 / recover4，另有idle/move/hurt/death | ENM-B04/v001/catalog.json（ENM-11） |
| 奶滴史莱姆 milk_slime | 普通telegraph4 / attack4 / recover4；触手grab_ready4 / grab_attack8 / grab_recover4 | ENM-B04/v001/catalog.json（ENM-03）+ ENM-SLIME-GRAB/v001/catalog.json |
| 藤鞭花 vine_flower | telegraph4 / attack4 / recover4，另有idle/move/hurt/death | ENM-B04/v001/catalog.json（ENM-07） |
| 苔甲卫 moss_guard | telegraph4 / attack4 / recover4，另有idle/move/hurt/death | ENM-B03/v001/catalog.json（ELT-01） |

完整相对路径前缀为assets/PROCESSED/enemies；每帧实际RGBA像素哈希、画布、可见范围、锚点及RAW源文件存在性均登记在同名JSON中。普通attack均4个不同像素帧，触手抓取攻击8个不同像素帧，未拿复制静帧/文件元数据差异冒充动画。

## 真实运行链路

上述地图的敌人均实例化scenes/enemies/combat_enemy.tscn，由CombatEnemy控制，CombatEnemyVisual直接遍历B03/B04和触手补充catalog，装配AnimatedSprite2D。state从chase进入telegraph、attack、recover；史莱姆按数据依次映射两套攻击。相同动作每帧不会重置播放，动作时长会按数据窗口完整适配。

仓库中的GameEnemy/EnemyVisual使用旧版备用资源映射，属于演练/旧Showcase路径；当前自然地图未发现GameEnemy实例。其idle-only备用资源不能据此断言当前地图没有攻击素材。

已登记但尚未摆入上述自然地图的矿灯虫、暗影奶灵、酸液蛞、蜜蜡蜂、蜂巢守卫、酸液母体和蜂蜜女王共7类也逐一查到了4帧attack资源；它们与地图实装5类分开登记。奶罐哥布林、苔原奶狐、霜晶冰灵另属已有美术储备，未混称成已经摆进地图的怪物。

## 修复内容

旧条件拿敌人身体中心到玩家原点的距离与attack_range直接比较。苔甲卫44×70实体和玩家20×34实体即使已互相碰到，中心最小距离也约36.7px，大于数据中的30px；飞奶蛾实体半宽12加玩家半宽10恰为22px，数据阈值22px又没有容纳物理安全边距和上下浮动，因而难以正常起手。

CombatEnemy现在使用双方实体矩形的边缘间隙与原有数据范围比较，并对普通近战再核实下一招的真实攻击矩形与玩家受击体有正面积重叠。这样大体型不会因中心偏移卡住，普通近战也不会因为按边缘比较而提前在判定外空挥。冲锋与弹幕招式仍保留原来的类别判断；没有增加攻击力、攻速、框尺寸或新平衡数值。

## 验收入口

```text
godot --headless --path . --fixed-fps 60 --script res://test/integration/test_enemy_attack_animation.gd
```

脚本使用真实玩家实体与hurtbox，逐一自然索敌追击，不手工强制attack。检查全部预备/攻击/收招帧有实际推进，史莱姆两套攻击都会播放，而且攻击能实际扣玩家生命。固定玩家站位时仅在测试中清除冻结的受击无敌计时，避免第二招因测试时钟冻结而被误判。结构化结果写入work/qa/enemy_attack_animation.json。

根任务统一执行后的准确输出：

```text
enemy_attack_natural exit=0 diagnostics=0 peakMB=166.4
ENEMY ATTACK ANIMATION: 33 checks / 0 failures / 5 map enemy types
```

原始日志work/qa/enemy_attack_natural.log与.err；完整状态序列、实见帧号与伤害结果同时写入同名审计JSON。五类均在自然AI中出现完整预备、攻击和收招，并实际命中玩家；史莱姆抓取8帧和普通攻击4帧都已验证。
