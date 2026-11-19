# Boss记录

<!-- enemy-source-sha256: 3f32eae418d96c5af78d81cfe758a6db074eb24d8c0e6e9ea62119bc7f21a957 -->
数字ID全局固定不复用；运行标识与素材ENM编号另列。只改参数表的“设定值”列，未设定保留“待填写”。填写后执行 `python tools/data/sync_enemy_registry.py --import-docs` 校验并回填JSON；类型错误、共享值冲突或原数据已变化会拒绝写入。

生命/攻击等base_属性在出生时乘“区域等级倍率×区域修正”；目前等级0/1/2均1.0，未擅自加成长。防御、韧性、抗性、时序和掉落不隐式增长。素材FPS/时长为预览数据，不冒充已实装战斗时间。

本册2种。

| 数字ID | 名称 | 运行标识 | 状态 |
|---|---|---|---|
| 0012 | 蜂蜜女王 | `honey_queen` | 已注册战斗 |
| 0013 | 奶化病毒催化体-克拉弗特 | `corrumpt` | 已注册战斗 |

## 区域等级与倍率（共用，可填写）

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `scaling.tier.0` | 区域等级0倍率 | 1.0 | 等级成长尚未另行指定，初始均1.0。 |
| `scaling.tier.1` | 区域等级1倍率 | 1.0 | 等级成长尚未另行指定，初始均1.0。 |
| `scaling.tier.2` | 区域等级2倍率 | 1.0 | 等级成长尚未另行指定，初始均1.0。 |
| `region.camp.tier` | 奶泉营地等级 | 0 | 三份文档共用同一配置，改一份即可。 |
| `region.camp.enemy_multiplier` | 奶泉营地区域修正倍率 | 1.0 | 三份文档共用同一配置，改一份即可。 |
| `region.forest.tier` | 奶源林地等级 | 1 | 三份文档共用同一配置，改一份即可。 |
| `region.forest.enemy_multiplier` | 奶源林地区域修正倍率 | 1.0 | 三份文档共用同一配置，改一份即可。 |
| `region.cave.tier` | 蜜乳洞窟等级 | 2 | 三份文档共用同一配置，改一份即可。 |
| `region.cave.enemy_multiplier` | 蜜乳洞窟区域修正倍率 | 1.0 | 三份文档共用同一配置，改一份即可。 |

## 0012 蜂蜜女王

运行标识：`honey_queen`；别名：无。
世界规划：cave_06。
当前实际攻击类型：冲撞；伤害按各招式倍率结算。features中的分裂/召唤/喷射等声明不等于通用控制器已实装这些招式。

### 基础属性与掉落

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `base.base_hp` | 基础生命 | 1800 |  |
| `base.base_damage` | 基础攻击 | 18 |  |
| `base.defense` | 防御 | 11 |  |
| `base.poise` | 韧性 | 100 |  |
| `base.resist.physical` | 物理抗性（%） | 0 |  |
| `base.resist.magic` | 奶术抗性（%） | 0 |  |
| `base.tier` | 设计等级 | 2 |  |
| `base.exp` | 击杀经验 | 400 |  |
| `base.coin_drop` | 奶币数量范围 | [250,250] |  |
| `loot.item_drops` | 物品掉落表 | 待填写 | 待填列表：item_id、数量范围、概率、条件。当前通用击杀只给经验/奶币，物品抽取尚未接入。 |
| `loot.drop_rolls` | 物品抽取次数 | 待填写 |  |

### 招式：攻击

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `moves.attack.damage_multiplier` | 伤害倍率 | 1.0 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.attack_duration` | 动作秒数 | 0.4 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.recover_duration` | 收招秒数 | 0.45 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.attack_hit_start` | 有效判定开始秒数 | 0.12 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.attack_hit_end` | 有效判定结束秒数 | 0.38 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.attack_range` | 起手距离px | 240 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.hitbox_size` | 命中框宽高px | [40,28] | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.hitbox_offset` | 命中框偏移px | [24,-14] | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.attack_knockback` | 击退速度px/s | 160 | 当前有效值；改此格创建本怪覆盖。 |
| `moves.attack.telegraph_duration` | 实际准备秒数 | 0.6 | 实际取准备值和最短预警的较大值。 |
| `moves.attack.cycle_seconds` | 准备+动作+收招秒数 | 1.45 | 只读；不含独立idle间隔。；只读 |
| `moves.attack.damage_type` | 伤害类型 | physical | 当前通用运行逻辑为物理攻击。；只读 |
| `moves.attack.poise_damage` | 攻击削韧 | 待填写 | 待设定；不得擅填。 |

### 运动、碰撞与投射物

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `combat.sprite_scale` | sprite_scale | 1.0 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.gravity` | gravity | 1200.0 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.detect_range` | detect_range | 144 | 共用感知；改动影响其他普通敌人。 |
| `combat.lose_range` | lose_range | 208 | 共用感知；改动影响其他普通敌人。 |
| `combat.patrol_distance` | patrol_distance | 90.0 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.body_size` | body_size | [24,28] | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.fly_body_size` | fly_body_size | [72,78] | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.hurt_duration` | hurt_duration | 0.2 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.death_duration` | death_duration | 1.2 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.attack_duration` | attack_duration | 0.4 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.recover_duration` | recover_duration | 0.45 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.attack_hit_start` | attack_hit_start | 0.12 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.attack_hit_end` | attack_hit_end | 0.38 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.hitbox_size` | hitbox_size | [40,28] | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.hitbox_offset` | hitbox_offset | [24,-14] | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.knockback_decay` | knockback_decay | 600.0 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.defense_constant` | defense_constant | 120 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.minimum_telegraph` | minimum_telegraph | 0.25 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.ranged_threshold` | ranged_threshold | 80 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.attack_knockback` | attack_knockback | 160 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.flying_vertical_speed` | flying_vertical_speed | 90 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.sine_amplitude` | sine_amplitude | 12 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.sine_frequency` | sine_frequency | 3 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.slow_multiplier` | slow_multiplier | 0.7 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.slow_duration` | slow_duration | 1.5 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.projectile_speed` | projectile_speed | 260 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.projectile_lifetime` | projectile_lifetime | 2.5 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.projectile_radius` | projectile_radius | 6 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.projectile_color` | projectile_color | [0.65,0.9,0.28,1] | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.projectile_catalog_path` | projectile_catalog_path | res://assets/PROCESSED/enemies/ENM-B04/v001/projectiles.json | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.charge_speed` | charge_speed | 600 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.idle_duration` | idle_duration | 0.6 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.damage_multiplier` | damage_multiplier | 1.0 | 本怪覆盖；未覆盖项继承公共值。 |
| `combat.projectile_visual_id` | projectile_visual_id | milk_bolt | 本怪覆盖；未覆盖项继承公共值。 |

### AI与声明机制

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `ai.type` | type | fly |  |
| `ai.patrol_speed` | patrol_speed | 60 |  |
| `ai.chase_speed` | chase_speed | 140 |  |
| `ai.attack_range` | attack_range | 240 |  |
| `ai.telegraph_time` | telegraph_time | 0.6 |  |
| `ai.features` | features | ["summon","dive","spray"] |  |

### 旧演练覆盖（只读）

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `legacy.fly_body_size` | fly_body_size | [72,78] | 旧GameEnemy读取enemy_presentation；正式自然地图读取B04。；只读 |
| `legacy.projectile_visual_id` | projectile_visual_id | milk_bolt | 旧GameEnemy读取enemy_presentation；正式自然地图读取B04。；只读 |
| `legacy.charge_speed` | charge_speed | 600 | 旧GameEnemy读取enemy_presentation；正式自然地图读取B04。；只读 |

### 未实装声明招式：召唤（待实装）

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `moves.planned_summon.damage_multiplier` | 伤害倍率 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.damage_type` | 伤害类型 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.windup_seconds` | 准备秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.active_seconds` | 攻击有效秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.recovery_seconds` | 收招秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.cooldown_seconds` | 冷却秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.attack_hit_start` | 有效判定开始秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.attack_hit_end` | 有效判定结束秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.attack_range` | 起手距离px | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.hitbox_size` | 命中框宽高px | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.hitbox_offset` | 命中框偏移px | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.attack_knockback` | 击退速度px/s | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.poise_damage` | 攻击削韧 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.projectile_id` | 弹幕标识 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.count` | count | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.lifetime_seconds` | lifetime_seconds | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_summon.probability` | probability | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |

### 未实装声明招式：喷射（待实装）

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `moves.planned_spray.damage_multiplier` | 伤害倍率 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.damage_type` | 伤害类型 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.windup_seconds` | 准备秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.active_seconds` | 攻击有效秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.recovery_seconds` | 收招秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.cooldown_seconds` | 冷却秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.attack_hit_start` | 有效判定开始秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.attack_hit_end` | 有效判定结束秒数 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.attack_range` | 起手距离px | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.hitbox_size` | 命中框宽高px | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.hitbox_offset` | 命中框偏移px | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.attack_knockback` | 击退速度px/s | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.poise_damage` | 攻击削韧 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.projectile_id` | 弹幕标识 | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.count` | count | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.lifetime_seconds` | lifetime_seconds | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |
| `moves.planned_spray.probability` | probability | 待填写 | 源features声明，尚无独立战斗实装；预留填写。 |

### 共用感知、接触与反馈

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `encounter.perception.detect_range` | perception.detect_range | 144 | 共用，改动影响其他普通敌人。 |
| `encounter.perception.lose_range` | perception.lose_range | 208 | 共用，改动影响其他普通敌人。 |
| `encounter.perception.ground_vertical_range` | perception.ground_vertical_range | 42 | 共用，改动影响其他普通敌人。 |
| `encounter.perception.ground_lose_vertical_range` | perception.ground_lose_vertical_range | 58 | 共用，改动影响其他普通敌人。 |
| `encounter.perception.fly_vertical_range` | perception.fly_vertical_range | 144 | 共用，改动影响其他普通敌人。 |
| `encounter.perception.line_of_sight_mask` | perception.line_of_sight_mask | 129 | 共用，改动影响其他普通敌人。 |
| `encounter.navigation.floor_snap` | navigation.floor_snap | 6 | 共用，改动影响其他普通敌人。 |
| `encounter.navigation.floor_probe_ahead` | navigation.floor_probe_ahead | 5 | 共用，改动影响其他普通敌人。 |
| `encounter.navigation.floor_probe_above` | navigation.floor_probe_above | 10 | 共用，改动影响其他普通敌人。 |
| `encounter.navigation.floor_probe_below` | navigation.floor_probe_below | 18 | 共用，改动影响其他普通敌人。 |
| `encounter.navigation.home_deadzone` | navigation.home_deadzone | 4 | 共用，改动影响其他普通敌人。 |
| `encounter.contact.bounce_speed` | contact.bounce_speed | 170 | 共用，改动影响其他普通敌人。 |
| `encounter.contact.bounce_time` | contact.bounce_time | 0.14 | 共用，改动影响其他普通敌人。 |
| `encounter.contact.cooldown` | contact.cooldown | 0.32 | 共用，改动影响其他普通敌人。 |
| `encounter.contact.vertical_impulse` | contact.vertical_impulse | 70 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.flash_seconds` | feedback.flash_seconds | 0.12 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_seconds` | feedback.health_seconds | 2.5 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_bar_width` | feedback.health_bar_width | 32 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_bar_height` | feedback.health_bar_height | 4 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_bar_gap` | feedback.health_bar_gap | 7 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.trail_speed` | feedback.trail_speed | 1.8 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.number_seconds` | feedback.number_seconds | 0.7 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.number_rise` | feedback.number_rise | 26 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.number_font_size` | feedback.number_font_size | 12 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_border` | feedback.health_border | #ba9b65 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_fill` | feedback.health_fill | #c9504d | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.health_trail` | feedback.health_trail | #f1cb86 | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.number_physical` | feedback.number_physical | #ffe6af | 共用，改动影响其他普通敌人。 |
| `encounter.feedback.number_magic` | feedback.number_magic | #bfdefa | 共用，改动影响其他普通敌人。 |

### 共用韧性规则

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `poise_rules.enemy_max` | enemy_max | 100 |  |
| `poise_rules.direct_stun_on_attack` | direct_stun_on_attack | false |  |
| `poise_rules.unfilled_policy` | unfilled_policy | 已填写28项按制作人表格同步；空白旧bow_01条目仍为null，按0处理，不从生命伤害推导 |  |

### 共用削韧受击反馈

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `poise_feedback.seconds` | seconds | 0.12 | 所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。 |
| `poise_feedback.amplitude` | amplitude | 1.6 | 所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。 |
| `poise_feedback.frequency` | frequency | 22 | 所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。 |

### 动作素材与原生规格（只读）

| 动作 | 帧数 | fps | 单轮秒数 | 循环 | 画布 / 锚点 | 来源 |
|---|---:|---:|---:|---|---|---|
| idle | 4 | 8 | 0.5 | true | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| move | 4 | 10 | 0.4 | true | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| telegraph | 4 | 10 | 0.4 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| attack | 4 | 14 | 0.285714 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| recover | 4 | 10 | 0.4 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| hurt | 4 | 12 | 0.333333 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| death | 8 | 10 | 0.8 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |

### 全部保留素材版本（只读）

| 动作 | 帧数 | fps | 单轮秒数 | 循环 | 画布 / 锚点 | 来源 |
|---|---:|---:|---:|---|---|---|
| idle | 4 | 8 | 0.5 | true | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| move | 4 | 10 | 0.4 | true | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| telegraph | 4 | 10 | 0.4 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| attack | 4 | 14 | 0.285714 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| recover | 4 | 10 | 0.4 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| hurt | 4 | 12 | 0.333333 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |
| death | 8 | 10 | 0.8 | false | [176, 136] / [88, 68] | `assets/PROCESSED/enemies/ENM-B04/v001/catalog.json` |

## 0013 奶化病毒催化体-克拉弗特

运行标识：`corrumpt`；别名：claffert、BOSS-CLAFFERT。
暂无地图放置记录。
所有有伤害招式暂按物理类型，未改变已确认倍率和时序。
抗性单位为百分数，0表示不减伤，100表示该类免疫。
攻击距离、层高容差、速度、碰撞尺寸、非指定起手/收招、演练场与界面布局为调试值。
防御暂为0；经验与奶币未定，演练场暂不发放奖励。

### 基础属性与掉落

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `base.base_hp` | 各阶段基础生命 | [600,1000] | 只读汇总；分别填写阶段属性表。；只读 |
| `base.base_damage` | 基础攻击 | 10.0 |  |
| `base.defense` | 防御 | 0.0 |  |
| `base.poise` | 韧性 | 300 |  |
| `base.resist.physical` | 物理抗性（%） | 0.0 |  |
| `base.resist.magic` | 奶术抗性（%） | 0.0 |  |
| `base.tier` | 设计等级 | 待填写 |  |
| `base.exp` | 击杀经验 | 待填写 | 未定；演练运行占位为0，不发最终奖励。 |
| `base.coin_drop` | 奶币数量范围 | 待填写 | 未定；演练运行占位为0，不发最终奖励。 |
| `loot.item_drops` | 物品掉落表 | 待填写 | 待填列表：item_id、数量范围、概率、条件。当前通用击杀只给经验/奶币，物品抽取尚未接入。 |
| `loot.drop_rolls` | 物品抽取次数 | 待填写 |  |

### 首领美术与原生规格（只读）

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `art.anchor_modes.phase_1_idle` | anchor_modes.phase_1_idle | root | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.anchor_modes.phase_2_idle` | anchor_modes.phase_2_idle | flower_center | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.anchors.phase_1_idle` | anchors.phase_1_idle | [[64,112],[64,112],[64,112],[64,112],[64,112],[64,112],[64,112],[64,112]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.anchors.phase_2_idle` | anchors.phase_2_idle | [[64,64],[64,64],[64,64],[64,64],[64,64],[64,64],[64,64],[64,64]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.arm_idle` | combat_anchors.arm_idle | [[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.slam` | combat_anchors.slam | [[48,288],[48,288],[48,288],[48,288],[48,288],[48,288],[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.slam_downstroke` | combat_anchors.slam_downstroke | [[48,288],[48,288],[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.spikes` | combat_anchors.spikes | [[48,288],[48,288],[48,288],[48,288],[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.needles` | combat_anchors.needles | [[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.gravity` | combat_anchors.gravity | [[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.spores` | combat_anchors.spores | [[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_anchors.repel` | combat_anchors.repel | [[48,288],[48,288],[48,288],[48,288]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.gravity` | combat_native_widths.gravity | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.needles` | combat_native_widths.needles | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.phase_1_idle` | combat_native_widths.phase_1_idle | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.repel` | combat_native_widths.repel | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.slam` | combat_native_widths.slam | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.slam_downstroke` | combat_native_widths.slam_downstroke | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.spikes` | combat_native_widths.spikes | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_native_widths.spores` | combat_native_widths.spores | 320 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_reference.central_height` | combat_reference.central_height | 330.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_reference.native_width` | combat_reference.native_width | 444.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.anchor_x` | combat_sheets.gravity.anchor_x | 0.5 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.body` | combat_sheets.gravity.body | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.columns` | combat_sheets.gravity.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.count` | combat_sheets.gravity.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.fps` | combat_sheets.gravity.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.path` | combat_sheets.gravity.path | combat/phase_1_spells.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.rows` | combat_sheets.gravity.rows | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity.start` | combat_sheets.gravity.start | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.columns` | combat_sheets.gravity_ring.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.count` | combat_sheets.gravity_ring.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.fps` | combat_sheets.gravity_ring.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.loop` | combat_sheets.gravity_ring.loop | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.path` | combat_sheets.gravity_ring.path | combat/phase_1_entities.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.row_edges` | combat_sheets.gravity_ring.row_edges | [0.0,225.0,490.0,773.0,1030.0,1323.0,1536.0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.rows` | combat_sheets.gravity_ring.rows | 6.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.gravity_ring.start` | combat_sheets.gravity_ring.start | 12.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.columns` | combat_sheets.impact.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.count` | combat_sheets.impact.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.fps` | combat_sheets.impact.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.loop` | combat_sheets.impact.loop | false | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.path` | combat_sheets.impact.path | combat/phase_1_entities.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.row_edges` | combat_sheets.impact.row_edges | [0.0,225.0,490.0,773.0,1030.0,1323.0,1536.0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.rows` | combat_sheets.impact.rows | 6.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.impact.start` | combat_sheets.impact.start | 20.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.columns` | combat_sheets.needle.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.count` | combat_sheets.needle.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.fps` | combat_sheets.needle.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.loop` | combat_sheets.needle.loop | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.path` | combat_sheets.needle.path | combat/phase_1_entities.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.row_edges` | combat_sheets.needle.row_edges | [0.0,225.0,490.0,773.0,1030.0,1323.0,1536.0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.rows` | combat_sheets.needle.rows | 6.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needle.start` | combat_sheets.needle.start | 0.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.anchor_x` | combat_sheets.needles.anchor_x | 0.5 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.body` | combat_sheets.needles.body | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.columns` | combat_sheets.needles.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.count` | combat_sheets.needles.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.fps` | combat_sheets.needles.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.path` | combat_sheets.needles.path | combat/phase_1_spells.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.rows` | combat_sheets.needles.rows | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.needles.start` | combat_sheets.needles.start | 0.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.anchor_x` | combat_sheets.repel.anchor_x | 0.5 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.body` | combat_sheets.repel.body | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.columns` | combat_sheets.repel.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.count` | combat_sheets.repel.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.fps` | combat_sheets.repel.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.path` | combat_sheets.repel.path | combat/phase_1_spells.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.rows` | combat_sheets.repel.rows | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel.start` | combat_sheets.repel.start | 12.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.columns` | combat_sheets.repel_ring.columns | 2.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.count` | combat_sheets.repel_ring.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.fps` | combat_sheets.repel_ring.fps | 10.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.loop` | combat_sheets.repel_ring.loop | false | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.path` | combat_sheets.repel_ring.path | combat/phase_1_repel.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.rows` | combat_sheets.repel_ring.rows | 2.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.repel_ring.start` | combat_sheets.repel_ring.start | 0.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.anchor_x` | combat_sheets.slam.anchor_x | 0.35 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.body` | combat_sheets.slam.body | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.columns` | combat_sheets.slam.columns | 2.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.count` | combat_sheets.slam.count | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.fps` | combat_sheets.slam.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.path` | combat_sheets.slam.path | combat/phase_1_slam_long.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.row_edges` | combat_sheets.slam.row_edges | [0.0,264.0,476.0,685.0,887.0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.rows` | combat_sheets.slam.rows | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.slam.start` | combat_sheets.slam.start | 0.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.columns` | combat_sheets.spike.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.count` | combat_sheets.spike.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.fps` | combat_sheets.spike.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.loop` | combat_sheets.spike.loop | false | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.path` | combat_sheets.spike.path | combat/phase_1_entities.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.row_edges` | combat_sheets.spike.row_edges | [0.0,225.0,490.0,773.0,1030.0,1323.0,1536.0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.rows` | combat_sheets.spike.rows | 6.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spike.start` | combat_sheets.spike.start | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.anchor_x` | combat_sheets.spikes.anchor_x | 0.5 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.body` | combat_sheets.spikes.body | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.columns` | combat_sheets.spikes.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.count` | combat_sheets.spikes.count | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.fps` | combat_sheets.spikes.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.path` | combat_sheets.spikes.path | combat/phase_1_tendrils.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.rows` | combat_sheets.spikes.rows | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spikes.start` | combat_sheets.spikes.start | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.columns` | combat_sheets.spore.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.count` | combat_sheets.spore.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.fps` | combat_sheets.spore.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.loop` | combat_sheets.spore.loop | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.path` | combat_sheets.spore.path | combat/phase_1_entities.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.row_edges` | combat_sheets.spore.row_edges | [0.0,225.0,490.0,773.0,1030.0,1323.0,1536.0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.rows` | combat_sheets.spore.rows | 6.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spore.start` | combat_sheets.spore.start | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.anchor_x` | combat_sheets.spores.anchor_x | 0.5 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.body` | combat_sheets.spores.body | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.columns` | combat_sheets.spores.columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.count` | combat_sheets.spores.count | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.fps` | combat_sheets.spores.fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.path` | combat_sheets.spores.path | combat/phase_1_spells.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.rows` | combat_sheets.spores.rows | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.combat_sheets.spores.start` | combat_sheets.spores.start | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.frame_count` | frame_count | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.idle_fps` | idle_fps | 8.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.native_cell.phase_1_idle` | native_cell.phase_1_idle | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.native_cell.phase_2_idle` | native_cell.phase_2_idle | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase_1_master` | phase_1_master | masters/phase_1_idle.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase_2_master` | phase_2_master | masters/phase_2_idle.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase_2_preview_center_y` | phase_2_preview_center_y | 0.52 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase_2_preview_visible_width` | phase_2_preview_visible_width | 260.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase_2_revision` | phase_2_revision | 正面正交视角、仅花体无根茎、三层刀刃状花瓣 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.body_canvas` | pixel.body_canvas | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.body_anchor` | pixel.body_anchor | [64,112] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.body_height` | pixel.body_height | 84 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.body_width` | pixel.body_width | 68 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.render_scale` | pixel.render_scale | 1 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.pixels_per_world_unit` | pixel.pixels_per_world_unit | 1 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.flower_canvas` | pixel.flower_canvas | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.flower_anchor` | pixel.flower_anchor | [64,64] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.phase_1_idle.frames` | pixel.animations.phase_1_idle.frames | [0,1,2,3,4,5,6,7] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.phase_1_idle.kind` | pixel.animations.phase_1_idle.kind | body | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.arm_idle.frames` | pixel.animations.arm_idle.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.arm_idle.kind` | pixel.animations.arm_idle.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.slam.frames` | pixel.animations.slam.frames | [0,1,2,3,4,5,6,7,8,9] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.slam.kind` | pixel.animations.slam.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.slam_downstroke.frames` | pixel.animations.slam_downstroke.frames | [0,1,2,3,4,5] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.slam_downstroke.kind` | pixel.animations.slam_downstroke.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spikes.frames` | pixel.animations.spikes.frames | [0,1,2,3,4,5,6,7] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spikes.kind` | pixel.animations.spikes.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.needles.frames` | pixel.animations.needles.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.needles.kind` | pixel.animations.needles.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.gravity.frames` | pixel.animations.gravity.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.gravity.kind` | pixel.animations.gravity.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spores.frames` | pixel.animations.spores.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spores.kind` | pixel.animations.spores.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.repel.frames` | pixel.animations.repel.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.repel.kind` | pixel.animations.repel.kind | arm | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.phase_2_idle.frames` | pixel.animations.phase_2_idle.frames | [0,1,2,3,4,5,6,7] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.phase_2_idle.kind` | pixel.animations.phase_2_idle.kind | flower | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.needle.frames` | pixel.animations.needle.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.needle.kind` | pixel.animations.needle.kind | fx | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spore.frames` | pixel.animations.spore.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spore.kind` | pixel.animations.spore.kind | fx | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spike.frames` | pixel.animations.spike.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.spike.kind` | pixel.animations.spike.kind | fx | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.gravity_ring.frames` | pixel.animations.gravity_ring.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.gravity_ring.kind` | pixel.animations.gravity_ring.kind | fx | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.repel_ring.frames` | pixel.animations.repel_ring.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.repel_ring.kind` | pixel.animations.repel_ring.kind | fx | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.impact.frames` | pixel.animations.impact.frames | [0,1,2,3] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.pixel.animations.impact.kind` | pixel.animations.impact.kind | fx | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.preview_width` | preview_width | 320.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.root` | root | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/ | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.sheet_columns` | sheet_columns | 4.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.sheet_rows` | sheet_rows | 2.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.sheets.phase_1_idle` | sheets.phase_1_idle | pixel_sources/idle_1.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.sheets.phase_2_idle` | sheets.phase_2_idle | pixel_sources/idle_2.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.visible_widths.phase_1_idle` | visible_widths.phase_1_idle | 354.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.visible_widths.phase_2_idle` | visible_widths.phase_2_idle | 356.0 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.root` | unified.root | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/ | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_source` | unified.body_source | sources/body_master.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_source` | unified.arm_source | sources/arm_actions.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.palette` | unified.palette | ["#00000000","#0b0711","#1a1021","#2c1935","#422448","#5a2c65","#74347d","#91429a","#ad59b3","#c97acc","#e3a7e1","#f6dbf1","#3d1d37","#612443","#87385e","#ad4e75","#191b11","#2a2f1b","#424629","#5d6035","#7b7c49","#a2a063","#c6bd84","#e5d4a0","#322921","#554334","#7f6550","#ac8a67","#8a3fd1","#bf6cf0","#edd2ff","#ffffff"] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.player_reference` | unified.player_reference | res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.player_visible_height` | unified.player_visible_height | 42 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_visible_height` | unified.body_visible_height | 84 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_visible_width` | unified.body_visible_width | 68 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_canvas` | unified.body_canvas | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_anchor` | unified.body_anchor | [64,112] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_pulse_deltas` | unified.body_pulse_deltas | [[0,0],[0,0],[1,-1],[1,-1],[0,0],[0,0],[-1,0],[-1,0]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_canvas` | unified.arm_canvas | [352,320] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_anchor` | unified.arm_anchor | [48,288] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_attachment` | unified.arm_attachment | [20,-4] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_source_grid` | unified.arm_source_grid | [4,4] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.idle_lengths` | unified.idle_lengths | [48,49,48,47] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.idle_heights` | unified.idle_heights | [22,23,22,21] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.raise_lengths` | unified.raise_lengths | [26,120,210,238] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.raise_heights` | unified.raise_heights | [22,74,120,160] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.swing_lengths` | unified.swing_lengths | [238,238,238,238,238,238] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.swing_heights` | unified.swing_heights | [146,120,94,64,34,6] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.retract_lengths` | unified.retract_lengths | [180,112,64] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.retract_heights` | unified.retract_heights | [12,18,22] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.cast_pulse_speed` | unified.cast_pulse_speed | 1.4 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.two_arm_casts` | unified.two_arm_casts | [] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.preview_canvas` | unified.preview_canvas | [640,352] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.preview_anchor` | unified.preview_anchor | [320,304] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.fps` | unified.fps | 8 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.flower_size` | unified.flower_size | 84 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.flower_canvas` | unified.flower_canvas | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.flower_anchor` | unified.flower_anchor | [64,64] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_sizes.needle` | unified.effect_sizes.needle | [40,16] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_sizes.spore` | unified.effect_sizes.spore | [20,20] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_sizes.spike` | unified.effect_sizes.spike | [32,40] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_sizes.gravity_ring` | unified.effect_sizes.gravity_ring | [96,12] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_sizes.repel_ring` | unified.effect_sizes.repel_ring | [96,12] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_sizes.impact` | unified.effect_sizes.impact | [236,32] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.swing_sources` | unified.swing_sources | [8,9,10,11,12,13] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_source_row_edges` | unified.arm_source_row_edges | [0,230,539,791,1049] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_source_shared_by_all_states` | unified.body_source_shared_by_all_states | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.body_runtime_reference_root` | unified.body_runtime_reference_root | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/sources/approved_reference/ | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_fit` | unified.arm_fit | isotropic_reach | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_ground_clip_y` | unified.arm_ground_clip_y | 292 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_row_edges` | unified.arm_row_edges | [0,230,539,791,1049] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_source_anchors` | unified.arm_source_anchors | [[77.1,219.36],[453.8,219.4],[827.9,219.2],[1177.8,219.52],[76.2,523.8],[452.0,521.56],[822.4,519.8],[1200.3,517.32],[75.3,769.88],[450.2,771.2],[825.2,773.16],[1196.5,774.84],[77.1,1002.0],[450.2,998.88],[911,983],[1204.0,993.52]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_source` | unified.effect_source | sources/effects.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_columns` | unified.effect_columns | 4 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_rows.needle` | unified.effect_rows.needle | [0,145] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_rows.spore` | unified.effect_rows.spore | [145,315] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_rows.spike` | unified.effect_rows.spike | [315,540] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_rows.gravity_ring` | unified.effect_rows.gravity_ring | [548,631] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_rows.repel_ring` | unified.effect_rows.repel_ring | [631,713] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_rows.impact` | unified.effect_rows.impact | [713,885] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.ring_rendering.mode` | unified.ring_rendering.mode | native_pixel_ribbon | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.ring_rendering.kinds` | unified.ring_rendering.kinds | ["gravity_ring","repel_ring"] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.ring_rendering.pixel_pitch` | unified.ring_rendering.pixel_pitch | 1 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.ring_rendering.repeat_pixels` | unified.ring_rendering.repeat_pixels | 96 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.ring_rendering.strip_height` | unified.ring_rendering.strip_height | 12 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.ring_rendering.shader` | unified.ring_rendering.shader | res://assets/effects/corrumpt/pixel_ring.gdshader | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_frame_boxes.needle` | unified.effect_frame_boxes.needle | [[192,62,336,100],[178,58,320,106],[159,53,306,107],[161,57,312,106]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_frame_boxes.spore` | unified.effect_frame_boxes.spore | [[183,14,318,157],[155,9,296,157],[148,8,281,157],[142,16,271,153]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_frame_boxes.spike` | unified.effect_frame_boxes.spike | [[166,5,326,205],[160,5,320,205],[136,5,296,205],[124,5,284,205]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_frame_boxes.gravity_ring` | unified.effect_frame_boxes.gravity_ring | [[29,2,441,56],[22,0,433,55],[13,0,424,55],[5,1,416,57]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_frame_boxes.repel_ring` | unified.effect_frame_boxes.repel_ring | [[30,1,441,62],[22,1,433,82],[13,3,424,61],[5,2,416,67]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_frame_boxes.impact` | unified.effect_frame_boxes.impact | [[28,50,442,142],[19,0,437,142],[10,20,427,142],[3,52,420,142]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_fit.needle` | unified.effect_fit.needle | uniform | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_fit.spore` | unified.effect_fit.spore | uniform | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_fit.spike` | unified.effect_fit.spike | uniform | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_fit.gravity_ring` | unified.effect_fit.gravity_ring | canvas | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_fit.repel_ring` | unified.effect_fit.repel_ring | canvas | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.effect_fit.impact` | unified.effect_fit.impact | canvas | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_overrides.7.path` | unified.arm_overrides.7.path | sources/raised_arm.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_overrides.7.source_anchor` | unified.arm_overrides.7.source_anchor | [56,1035.5] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.arm_overrides.7.offline_rotation_degrees` | unified.arm_overrides.7.offline_rotation_degrees | -10 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.idle_sources` | unified.idle_sources | [0,0,0,0] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.unified.isolate_arm_component` | unified.isolate_arm_component | true | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.root` | phase2.root | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/ | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.idle_source_root` | phase2.idle_source_root | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/frames/phase_2_idle/ | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.palette_reference` | phase2.palette_reference | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/palette.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.canvas` | phase2.canvas | [128,128] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.anchor` | phase2.anchor | [64,64] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.visible_diameter` | phase2.visible_diameter | 84 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.fps` | phase2.fps | 8 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.render_scale` | phase2.render_scale | 1 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.core_radius` | phase2.core_radius | 6 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.idle_offsets` | phase2.idle_offsets | [[-1,-1],[0,-1],[2,-1],[1,0],[0,1],[1,1],[1,1],[1,1]] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.blade_source` | phase2.blade_source | sources/blade_extend.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.blade_grid` | phase2.blade_grid | [4,2] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.blade_diameters` | phase2.blade_diameters | [84,90,96,102,108,114,118,120] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.spin_angles` | phase2.spin_angles | [0,45,90,135,180,225,270,315] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.spin_fps` | phase2.spin_fps | 32 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.airflow_source` | phase2.airflow_source | sources/airflow.png | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.airflow_size` | phase2.airflow_size | [96,24] | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.airflow_offset` | phase2.airflow_offset | 56 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |
| `art.phase2.airflow_fps` | phase2.airflow_fps | 20 | 美术参数需按像素契约制作、转换与检视，不通过数值文档修改。；只读 |

### 首领分阶段属性

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `phases.0.base_hp` | 腐朽花苞 / base_hp | 600 |  |
| `phases.0.id` | 腐朽花苞 / id | bud |  |
| `phases.0.idle` | 腐朽花苞 / idle | phase_1_idle |  |
| `phases.0.name` | 腐朽花苞 / name | 腐朽花苞 |  |
| `phases.0.poise` | 腐朽花苞 / poise | 300 |  |
| `phases.1.base_hp` | 深渊之花 / base_hp | 1000 |  |
| `phases.1.id` | 深渊之花 / id | bloom |  |
| `phases.1.idle` | 深渊之花 / idle | phase_2_idle |  |
| `phases.1.name` | 深渊之花 / name | 深渊之花 |  |
| `phases.1.poise` | 深渊之花 / poise | 450 |  |

### 一阶段招式与战斗

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `combat.attack_chance` | attack_chance | 0.3333333333333333 |  |
| `combat.body_offset` | body_offset | [0,-40] |  |
| `combat.body_size` | body_size | [56,80] |  |
| `combat.close_range` | close_range | 70 |  |
| `combat.cooldown` | cooldown | 2.0 |  |
| `combat.defeat_fade_seconds` | defeat_fade_seconds | 1.2 |  |
| `combat.direction_variants.slam.left` | direction_variants.slam.left | mirrored_complete_frames |  |
| `combat.direction_variants.slam.right` | direction_variants.slam.right | source_frames |  |
| `combat.direction_variants.spikes.left` | direction_variants.spikes.left | mirrored_complete_frames |  |
| `combat.direction_variants.spikes.right` | direction_variants.spikes.right | source_frames |  |
| `combat.far_weights.needles` | far_weights.needles | 30 |  |
| `combat.far_weights.spores` | far_weights.spores | 30 |  |
| `combat.far_weights.gravity` | far_weights.gravity | 40 |  |
| `combat.flash_seconds` | flash_seconds | 0.12 |  |
| `combat.gravity_followup_weights.slam` | gravity_followup_weights.slam | 1.0 |  |
| `combat.gravity_followup_weights.spikes` | gravity_followup_weights.spikes | 1.0 |  |
| `combat.hurt_shake` | hurt_shake | 2.0 |  |
| `combat.implemented_phase` | implemented_phase | 2 |  |
| `combat.melee_range` | melee_range | 280 |  |
| `combat.moves.gravity.active_seconds` | moves.gravity.active_seconds | 0.45 |  |
| `combat.moves.gravity.damage_multiplier` | moves.gravity.damage_multiplier | 0.0 |  |
| `combat.moves.gravity.pull_seconds` | moves.gravity.pull_seconds | 0.45 |  |
| `combat.moves.gravity.pull_speed` | moves.gravity.pull_speed | 560.0 |  |
| `combat.moves.gravity.recovery_seconds` | moves.gravity.recovery_seconds | 0.15 |  |
| `combat.moves.gravity.ring_extent_ratio` | moves.gravity.ring_extent_ratio | 1.15 |  |
| `combat.moves.gravity.safe_radius` | moves.gravity.safe_radius | 50 |  |
| `combat.moves.gravity.stun_seconds` | moves.gravity.stun_seconds | 0.45 |  |
| `combat.moves.gravity.windup_seconds` | moves.gravity.windup_seconds | 0.35 |  |
| `combat.moves.needles.count` | moves.needles.count | 10.0 |  |
| `combat.moves.needles.damage_multiplier` | moves.needles.damage_multiplier | 0.5 |  |
| `combat.moves.needles.damage_type` | moves.needles.damage_type | physical |  |
| `combat.moves.needles.lifetime` | moves.needles.lifetime | 0.0 |  |
| `combat.moves.needles.radius` | moves.needles.radius | 8 |  |
| `combat.moves.needles.recovery_seconds` | moves.needles.recovery_seconds | 0.55 |  |
| `combat.moves.needles.spawn_height` | moves.needles.spawn_height | 82 |  |
| `combat.moves.needles.spawn_radius` | moves.needles.spawn_radius | 0.0 |  |
| `combat.moves.needles.speed` | moves.needles.speed | 530.0 |  |
| `combat.moves.needles.visual_size` | moves.needles.visual_size | [40,16] |  |
| `combat.moves.needles.windup_seconds` | moves.needles.windup_seconds | 0.5 |  |
| `combat.moves.needles.homing_seconds` | moves.needles.homing_seconds | 0.0 |  |
| `combat.moves.needles.collision_length` | moves.needles.collision_length | 40 |  |
| `combat.moves.needles.sweep_probe_pixels` | moves.needles.sweep_probe_pixels | 0.25 |  |
| `combat.moves.needles.phase2_spawn_height` | moves.needles.phase2_spawn_height | 42 |  |
| `combat.moves.needles.fan_step_degrees` | moves.needles.fan_step_degrees | 15.0 |  |
| `combat.moves.needles.aimed_needle_index` | moves.needles.aimed_needle_index | 5 |  |
| `combat.moves.repel.cooldown` | moves.repel.cooldown | 0 |  |
| `combat.moves.repel.damage_multiplier` | moves.repel.damage_multiplier | 0.0 |  |
| `combat.moves.repel.duration` | moves.repel.duration | 0.35 |  |
| `combat.moves.repel.push_seconds` | moves.repel.push_seconds | 0.35 |  |
| `combat.moves.repel.push_speed` | moves.repel.push_speed | 340.0 |  |
| `combat.moves.repel.radius` | moves.repel.radius | 172.0 |  |
| `combat.moves.repel.stun_seconds` | moves.repel.stun_seconds | 0.25 |  |
| `combat.moves.repel.close_accumulation_seconds` | moves.repel.close_accumulation_seconds | 4.0 |  |
| `combat.moves.repel.outside_range_margin` | moves.repel.outside_range_margin | 48 |  |
| `combat.moves.repel.visual_only` | moves.repel.visual_only | true |  |
| `combat.moves.slam.active_seconds` | moves.slam.active_seconds | 0.18 |  |
| `combat.moves.slam.damage_multiplier` | moves.slam.damage_multiplier | 2.0 |  |
| `combat.moves.slam.damage_type` | moves.slam.damage_type | physical |  |
| `combat.moves.slam.hit_offset` | moves.slam.hit_offset | [146,-16] |  |
| `combat.moves.slam.hit_size` | moves.slam.hit_size | [236,32] |  |
| `combat.moves.slam.hold_frame` | moves.slam.hold_frame | 3.0 |  |
| `combat.moves.slam.hold_seconds` | moves.slam.hold_seconds | 0.2 |  |
| `combat.moves.slam.impact_frame` | moves.slam.impact_frame | 5.0 |  |
| `combat.moves.slam.impact_seconds` | moves.slam.impact_seconds | 0.5 |  |
| `combat.moves.slam.raise_frames` | moves.slam.raise_frames | [0.0,1.0,2.0,3.0] |  |
| `combat.moves.slam.raise_seconds` | moves.slam.raise_seconds | 0.45 |  |
| `combat.moves.slam.reach_body_lengths` | moves.slam.reach_body_lengths | 3.5 |  |
| `combat.moves.slam.recovery_frames` | moves.slam.recovery_frames | [6,7,8,9] |  |
| `combat.moves.slam.recovery_seconds` | moves.slam.recovery_seconds | 0.55 |  |
| `combat.moves.slam.swing_animation` | moves.slam.swing_animation | slam_downstroke |  |
| `combat.moves.slam.swing_frames` | moves.slam.swing_frames | [0.0,1.0,2.0,3.0,4.0,5.0] |  |
| `combat.moves.slam.swing_seconds` | moves.slam.swing_seconds | 0.5 |  |
| `combat.moves.slam.lift_height` | moves.slam.lift_height | 160 |  |
| `combat.moves.slam.contact_damage` | moves.slam.contact_damage | true |  |
| `combat.moves.slam.impact_damage` | moves.slam.impact_damage | false |  |
| `combat.moves.slam.collision_alpha_cutoff` | moves.slam.collision_alpha_cutoff | 0.5 |  |
| `combat.moves.slam.collision_simplify_epsilon` | moves.slam.collision_simplify_epsilon | 1.0 |  |
| `combat.moves.slam.minimum_polygon_area` | moves.slam.minimum_polygon_area | 2.0 |  |
| `combat.moves.spikes.active_seconds` | moves.spikes.active_seconds | 0.4 |  |
| `combat.moves.spikes.bury_seconds` | moves.spikes.bury_seconds | 0.4 |  |
| `combat.moves.spikes.count` | moves.spikes.count | 8 |  |
| `combat.moves.spikes.damage_multiplier` | moves.spikes.damage_multiplier | 2.5 |  |
| `combat.moves.spikes.damage_type` | moves.spikes.damage_type | physical |  |
| `combat.moves.spikes.delay_seconds` | moves.spikes.delay_seconds | 1.5 |  |
| `combat.moves.spikes.first_distance` | moves.spikes.first_distance | 50 |  |
| `combat.moves.spikes.ground_probe_down` | moves.spikes.ground_probe_down | 85.0 |  |
| `combat.moves.spikes.ground_probe_up` | moves.spikes.ground_probe_up | 45.0 |  |
| `combat.moves.spikes.height` | moves.spikes.height | 40 |  |
| `combat.moves.spikes.recovery_seconds` | moves.spikes.recovery_seconds | 0.5 |  |
| `combat.moves.spikes.spacing` | moves.spikes.spacing | 32 |  |
| `combat.moves.spikes.width` | moves.spikes.width | 32 |  |
| `combat.moves.spikes.spawn_interval` | moves.spikes.spawn_interval | 0.2 |  |
| `combat.moves.spores.count` | moves.spores.count | 7 |  |
| `combat.moves.spores.damage_multiplier` | moves.spores.damage_multiplier | 1.0 |  |
| `combat.moves.spores.damage_type` | moves.spores.damage_type | physical |  |
| `combat.moves.spores.lifetime` | moves.spores.lifetime | 8.0 |  |
| `combat.moves.spores.radius` | moves.spores.radius | 9 |  |
| `combat.moves.spores.recovery_seconds` | moves.spores.recovery_seconds | 0.55 |  |
| `combat.moves.spores.spawn_radius` | moves.spores.spawn_radius | 42 |  |
| `combat.moves.spores.speed` | moves.spores.speed | 175.0 |  |
| `combat.moves.spores.visual_size` | moves.spores.visual_size | [20,20] |  |
| `combat.moves.spores.windup_seconds` | moves.spores.windup_seconds | 0.65 |  |
| `combat.moves.spores.passes_walls` | moves.spores.passes_walls | false |  |
| `combat.moves.spores.max_bounces` | moves.spores.max_bounces | 2 |  |
| `combat.moves.spores.terrain_mask` | moves.spores.terrain_mask | 129 |  |
| `combat.moves.spores.collision_epsilon` | moves.spores.collision_epsilon | 0.25 |  |
| `combat.near_weights.needles` | near_weights.needles | 20.0 |  |
| `combat.near_weights.slam` | near_weights.slam | 40.0 |  |
| `combat.near_weights.spikes` | near_weights.spikes | 40.0 |  |
| `combat.paralysis_damage_multiplier` | paralysis_damage_multiplier | 1.3 |  |
| `combat.ready_interval` | ready_interval | 1.0 |  |
| `combat.same_layer_tolerance` | same_layer_tolerance | 45.0 |  |
| `combat.visual_width` | visual_width | 240.0 |  |
| `combat.entry_melee_weights.slam` | entry_melee_weights.slam | 1 |  |
| `combat.entry_melee_weights.spikes` | entry_melee_weights.spikes | 1 |  |

### 二阶段招式与战斗

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `phase2_combat.enabled` | enabled | true |  |
| `phase2_combat.body_radius` | body_radius | 42 |  |
| `phase2_combat.blade_radius` | blade_radius | 60 |  |
| `phase2_combat.boundary_margin` | boundary_margin | 64 |  |
| `phase2_combat.entry_seconds` | entry_seconds | 0.8 |  |
| `phase2_combat.entry_lift` | entry_lift | 150 |  |
| `phase2_combat.skill_interval` | skill_interval | 0.0 |  |
| `phase2_combat.ground_recovery.stagger_seconds` | ground_recovery.stagger_seconds | 4.0 |  |
| `phase2_combat.ground_recovery.poise_damage_multiplier` | ground_recovery.poise_damage_multiplier | 2.0 |  |
| `phase2_combat.ground_recovery.landing_speed` | ground_recovery.landing_speed | 240.0 |  |
| `phase2_combat.ground_recovery.grounded_bottom` | ground_recovery.grounded_bottom | 39.0 |  |
| `phase2_combat.ground_recovery.grounded_frame` | ground_recovery.grounded_frame | 0 |  |
| `phase2_combat.ground_recovery.ground_mask` | ground_recovery.ground_mask | 129 |  |
| `phase2_combat.roam_after_third_wait` | roam_after_third_wait | 4.0 |  |
| `phase2_combat.roam_offset` | roam_offset | [320,-180] |  |
| `phase2_combat.close_distance` | close_distance | 160 |  |
| `phase2_combat.avoid_wall_mask` | avoid_wall_mask | 1 |  |
| `phase2_combat.roam_weights.needles` | roam_weights.needles | 50 |  |
| `phase2_combat.roam_weights.spores` | roam_weights.spores | 50 |  |
| `phase2_combat.close_sequence` | close_sequence | ["blade","impact","impact","impact","blade"] |  |
| `phase2_combat.moves.blade.extend_seconds` | moves.blade.extend_seconds | 0.5 |  |
| `phase2_combat.moves.blade.spin_start_seconds` | moves.blade.spin_start_seconds | 0.25 |  |
| `phase2_combat.moves.blade.initial_offset` | moves.blade.initial_offset | [-200,-160] |  |
| `phase2_combat.moves.blade.approach_speed` | moves.blade.approach_speed | 650 |  |
| `phase2_combat.moves.blade.hover_seconds` | moves.blade.hover_seconds | 1.5 |  |
| `phase2_combat.moves.blade.dash_distance` | moves.blade.dash_distance | 420 |  |
| `phase2_combat.moves.blade.dash_speed` | moves.blade.dash_speed | 900 |  |
| `phase2_combat.moves.blade.cycles_min` | moves.blade.cycles_min | 3 |  |
| `phase2_combat.moves.blade.cycles_max` | moves.blade.cycles_max | 5 |  |
| `phase2_combat.moves.blade.spin_stop_seconds` | moves.blade.spin_stop_seconds | 0.3 |  |
| `phase2_combat.moves.blade.retract_seconds` | moves.blade.retract_seconds | 0.5 |  |
| `phase2_combat.moves.blade.damage_multiplier` | moves.blade.damage_multiplier | 1.5 |  |
| `phase2_combat.moves.blade.damage_type` | moves.blade.damage_type | physical |  |
| `phase2_combat.moves.blade.knockback` | moves.blade.knockback | 700 |  |
| `phase2_combat.moves.blade.knockback_seconds` | moves.blade.knockback_seconds | 0.35 |  |
| `phase2_combat.moves.blade.stun_seconds` | moves.blade.stun_seconds | 0.35 |  |
| `phase2_combat.moves.impact.align_speed` | moves.impact.align_speed | 900 |  |
| `phase2_combat.moves.impact.charge_distance` | moves.impact.charge_distance | 70 |  |
| `phase2_combat.moves.impact.charge_speed` | moves.impact.charge_speed | 340 |  |
| `phase2_combat.moves.impact.hold_seconds` | moves.impact.hold_seconds | 0.2 |  |
| `phase2_combat.moves.impact.dash_distance` | moves.impact.dash_distance | 480 |  |
| `phase2_combat.moves.impact.dash_speed` | moves.impact.dash_speed | 1150 |  |
| `phase2_combat.moves.impact.recover_side_distance` | moves.impact.recover_side_distance | 180 |  |
| `phase2_combat.moves.impact.recover_speed` | moves.impact.recover_speed | 750 |  |
| `phase2_combat.moves.impact.damage_multiplier` | moves.impact.damage_multiplier | 2.0 |  |
| `phase2_combat.moves.impact.damage_type` | moves.impact.damage_type | physical |  |
| `phase2_combat.moves.impact.knockback` | moves.impact.knockback | 700 |  |
| `phase2_combat.moves.impact.knockback_seconds` | moves.impact.knockback_seconds | 0.35 |  |
| `phase2_combat.moves.impact.stun_seconds` | moves.impact.stun_seconds | 0.35 |  |
| `phase2_combat.moves.spores.count` | moves.spores.count | 10 |  |
| `phase2_combat.moves.spores.rounds` | moves.spores.rounds | 3 |  |
| `phase2_combat.moves.spores.round_interval` | moves.spores.round_interval | 2.0 |  |
| `phase2_combat.moves.spores.damage_multiplier` | moves.spores.damage_multiplier | 0.5 |  |
| `phase2_combat.moves.spores.lifetime` | moves.spores.lifetime | 15.0 |  |
| `phase2_combat.moves.spores.terrain_mask` | moves.spores.terrain_mask | 449 |  |
| `phase2_combat.moves.spores.terrain_areas` | moves.spores.terrain_areas | true |  |
| `phase2_combat.moves.needles.rounds` | moves.needles.rounds | 4 |  |
| `phase2_combat.moves.needles.round_interval` | moves.needles.round_interval | 0.7 |  |
| `phase2_combat.moves.needles.damage_multiplier` | moves.needles.damage_multiplier | 0.2 |  |
| `phase2_combat.motion_epsilon` | motion_epsilon | 0.01 |  |
| `phase2_combat.min_roam_height_gap` | min_roam_height_gap | 100 |  |
| `phase2_combat.min_roam_distance` | min_roam_distance | 260 |  |
| `phase2_combat.roam_skill_interval` | roam_skill_interval | 3.0 |  |
| `phase2_combat.roam_speed_multiplier` | roam_speed_multiplier | 1.0 |  |
| `phase2_combat.reposition_speed_multiplier` | reposition_speed_multiplier | 2.0 |  |
| `phase2_combat.close_skill_speed_multiplier` | close_skill_speed_multiplier | 0.75 |  |
| `phase2_combat.player_speed_fallback` | player_speed_fallback | 160 |  |
| `phase2_combat.route_player_radius` | route_player_radius | 16 |  |
| `phase2_combat.route_clearance` | route_clearance | 16 |  |
| `phase2_combat.route_margin` | route_margin | 12 |  |

### 转场与虚空湮灭

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `sequence.root` | root | res://assets/PROCESSED/enemies/BOSS-CLAFFERT/sequence_v001/ |  |
| `sequence.canvas` | canvas | [128,128] |  |
| `sequence.opening_anchor` | opening_anchor | [64,112] |  |
| `sequence.flower_center` | flower_center | [64,64] |  |
| `sequence.letterbox_fraction` | letterbox_fraction | 0.12 |  |
| `sequence.flash_color` | flash_color | #af79ec |  |
| `sequence.transition.opening_seconds` | transition.opening_seconds | 1.8 |  |
| `sequence.transition.rise_seconds` | transition.rise_seconds | 1.2 |  |
| `sequence.transition.rise_distance` | transition.rise_distance | 128.0 |  |
| `sequence.transition.hover_seconds` | transition.hover_seconds | 2.0 |  |
| `sequence.transition.flash_in_seconds` | transition.flash_in_seconds | 0.25 |  |
| `sequence.transition.flash_hold_seconds` | transition.flash_hold_seconds | 0.5 |  |
| `sequence.transition.flash_out_seconds` | transition.flash_out_seconds | 0.65 |  |
| `sequence.defeat.center_seconds` | defeat.center_seconds | 0.6 |  |
| `sequence.defeat.grow_seconds` | defeat.grow_seconds | 5.0 |  |
| `sequence.defeat.radius_multiplier` | defeat.radius_multiplier | 10.0 |  |
| `sequence.defeat.damage_per_frame` | defeat.damage_per_frame | 1 |  |
| `sequence.defeat.shake_amplitude` | defeat.shake_amplitude | 5.0 |  |
| `sequence.defeat.shake_frequency` | defeat.shake_frequency | 33.0 |  |
| `sequence.defeat.gravity_interval` | defeat.gravity_interval | 0.5 |  |
| `sequence.defeat.gravity_seconds` | defeat.gravity_seconds | 0.45 |  |
| `sequence.defeat.pull_speed` | defeat.pull_speed | 80.0 |  |
| `sequence.defeat.pull_seconds` | defeat.pull_seconds | 0.35 |  |
| `sequence.defeat.flash_in_seconds` | defeat.flash_in_seconds | 0.3 |  |
| `sequence.defeat.flash_hold_seconds` | defeat.flash_hold_seconds | 0.6 |  |
| `sequence.defeat.flash_out_seconds` | defeat.flash_out_seconds | 0.8 |  |
| `sequence.wilt_color` | wilt_color | #53443c |  |
| `sequence.void_source_radius` | void_source_radius | 34 |  |

### 选招规则

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `skill_selection.constraints` | constraints | ["player_distance","player_remaining_hp","previous_move","boss_phase"] |  |
| `skill_selection.mode` | mode | random_from_currently_eligible |  |
| `skill_selection.skills` | skills | ["slam","spikes","needles","gravity","spores","repel","blade","impact"] |  |
| `skill_selection.status` | status | two_phases_mode_selection |  |

### 场地

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `arena.background_darkness` | background_darkness | 0.55 |  |
| `arena.boss_position` | boss_position | [840.0,560.0] |  |
| `arena.camera_zoom` | camera_zoom | 0.8 |  |
| `arena.floor_y` | floor_y | 560.0 |  |
| `arena.platforms` | platforms | [[320.0,425.0,200.0],[1040.0,425.0,200.0]] |  |
| `arena.player_position` | player_position | [320.0,530.0] |  |
| `arena.size` | size | [1680.0,640.0] |  |

### 血条

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `health_bar.overhead` | overhead | false |  |
| `health_bar.position_requirement` | position_requirement | 屏幕左上方居中 |  |
| `health_bar.status` | status | implemented |  |
| `health_bar.type` | type | boss |  |

### 界面

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `ui.border` | border | #a18c6b |  |
| `ui.fill` | fill | #793c69 |  |
| `ui.health_height` | health_height | 9.0 |  |
| `ui.name_font_size` | name_font_size | 12.0 |  |
| `ui.position` | position | [220.0,12.0] |  |
| `ui.size` | size | [360.0,40.0] |  |
| `ui.trail` | trail | #b68962 |  |
| `ui.trail_speed` | trail_speed | 0.45 |  |
| `ui.poise.frames` | poise.frames | res://assets/ui/corrumpt_poise_v1/CorrumptPoise_frames.tres |  |
| `ui.poise.break_seconds` | poise.break_seconds | 0.24 |  |
| `ui.poise.recover_seconds` | poise.recover_seconds | 0.24 |  |
| `ui.poise.shake_seconds` | poise.shake_seconds | 0.28 |  |
| `ui.poise.shake_amplitude` | poise.shake_amplitude | 6.0 |  |
| `ui.poise.shake_frequency` | poise.shake_frequency | 28.0 |  |
| `ui.poise.overlay_alpha` | poise.overlay_alpha | 1.0 |  |

### Boss共用规则

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `boss_rules.paralysis.base_seconds` | paralysis.base_seconds | 1.0 | 所有Boss共用。 |
| `boss_rules.paralysis.poise_factor` | paralysis.poise_factor | 0.01 | 所有Boss共用。 |

### 危险红光共用参数

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `danger_warning.frames` | frames | res://assets/effects/danger_warning_v1/DangerWarning_frames.tres | 共用美术预警；时长参与招式总时序，需连同动作检视后修改。；只读 |
| `danger_warning.seconds` | seconds | 0.2 | 共用美术预警；时长参与招式总时序，需连同动作检视后修改。；只读 |
| `danger_warning.offset` | offset | [0,0] | 共用美术预警；时长参与招式总时序，需连同动作检视后修改。；只读 |
| `danger_warning.opacity` | opacity | 0.85 | 共用美术预警；时长参与招式总时序，需连同动作检视后修改。；只读 |
| `danger_warning.scale` | scale | 4.0 | 共用美术预警；时长参与招式总时序，需连同动作检视后修改。；只读 |

### 首领全局参数

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `boss.combat_enabled` | combat_enabled | true |  |
| `boss.defense` | defense | 0.0 |  |
| `boss.base_damage` | base_damage | 10.0 |  |
| `boss.poise` | poise | 300 | poise为兜底；各阶段覆盖值见分阶段表。 |

### 共用削韧受击反馈

| 字段 | 项目 | 设定值 | 说明 |
|---|---|---|---|
| `poise_feedback.seconds` | seconds | 0.12 | 所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。 |
| `poise_feedback.amplitude` | amplitude | 1.6 | 所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。 |
| `poise_feedback.frequency` | frequency | 22 | 所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。 |

### 动作素材与原生规格（只读）

| 动作 | 帧数 | fps | 单轮秒数 | 循环 | 画布 / 锚点 | 来源 |
|---|---:|---:|---:|---|---|---|
| phase_2_idle | 8 | 8.0 | 1.0 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| phase_2_extend | 8 | 16.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| phase_2_retract | 8 | 16.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| phase_2_spin | 8 | 32.0 | 0.25 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| phase_2_spin_start | 4 | 16.0 | 0.25 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| phase_2_spin_stop | 5 | 16.0 | 0.3125 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| airflow | 4 | 20.0 | 0.2 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/phase2_v001/godot/Corrumpt_phase2_frames.tres` |
| opening | 6 | 12.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/sequence_v001/CorrumptSequence_frames.tres` |
| void | 4 | 12.0 | 0.333333 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/sequence_v001/CorrumptSequence_frames.tres` |
| phase_1_idle | 8 | 8.0 | 1.0 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Claffert_idle_frames.tres` |
| phase_2_idle | 8 | 8.0 | 1.0 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Claffert_idle_frames.tres` |
| phase_1_idle | 8 | 8.0 | 1.0 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| arm_idle | 4 | 8.0 | 0.5 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| slam | 10 | 8.0 | 1.25 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| slam_downstroke | 6 | 12.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| spikes | 8 | 8.0 | 1.0 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| needles | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| gravity | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| spores | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| repel | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| phase_2_idle | 8 | 8.0 | 1.0 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| needle | 4 | 8.0 | 0.5 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| spore | 4 | 8.0 | 0.5 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| spike | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| gravity_ring | 4 | 8.0 | 0.5 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| repel_ring | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| impact | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_combat_frames.tres` |
| phase_1_idle | 8 | 8.0 | 1.0 | true | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| arm_idle | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| slam | 10 | 8.0 | 1.25 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| slam_downstroke | 6 | 8.0 | 0.75 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| spikes | 8 | 8.0 | 1.0 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| needles | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| gravity | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| spores | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
| repel | 4 | 8.0 | 0.5 | false | 按首领档案 / 按首领档案 | `assets/PROCESSED/enemies/BOSS-CLAFFERT/v005/godot/Corrumpt_preview_frames.tres` |
