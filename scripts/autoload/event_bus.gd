extends Node
## EventBus —— 全局事件总线（autoload 单例）
## 纯信号集，禁止在这里写任何业务逻辑；跨系统通信用 signal 连接解耦。

# ---- 玩家 ----
signal player_damaged(amount: int)           ## 玩家受到伤害（结算后数值）
signal player_healed(amount: int)            ## 玩家受到治疗
signal player_died                           ## 玩家死亡

# ---- 战斗 ----
signal enemy_died(enemy_id: StringName, pos: Vector2)  ## 敌人死亡（id + 死亡位置）

# ---- 物品 / 经济 ----
signal item_picked(item_id: StringName, count: int)    ## 拾取道具
signal coin_changed(new_value: int)                    ## 奶币数量变化

# ---- 成长 ----
signal exp_gained(amount: int)               ## 获得经验
signal level_up(new_level: int)              ## 升级
signal ability_unlocked(ability_id: StringName)  ## 解锁能力（本期：double_jump）

# ---- 世界 ----
signal chest_opened(chest_id: StringName)    ## 开启宝箱
signal room_entered(room_id: StringName)     ## 进入房间
signal boss_defeated(boss_id: StringName)    ## 击败 BOSS

# ---- 存档 ----
signal save_completed(slot: int)             ## 某槽位存档完成（M2 由 SaveSystem 发出）
