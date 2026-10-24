# ENM-B04：旧敌重制与游戏接入

重制旧库剩余 7 类：奶罐哥布林、奶滴史莱姆、苔原奶狐、霜晶冰灵、暗影奶灵、藤鞭花、蜜蜡蜂；补齐游戏表中的飞奶蛾、蜂蜜女王。

本批完成 9 类 × 7 动作 = 63 组、288 帧主体；另有奶沫、暗影、藤刺三组六帧飞行弹体。最终状态为 ready，完整验收见 qa.json（413/413 单测、12类严格运行检查通过）。

## 游戏入口

从项目根运行 `./run_game.sh`，或用 Godot 4.7.2 打开根目录 project.godot。
- F2：战斗演练，包含 data/enemies.json 的全部 12 类敌人，可选择敌人、重置战斗。
- F3：原演练入口，保留并行场景工作。
- 战斗演练：A/D 移动、空格跳、左键攻击、右键防御、Q 技能、R 重置、Esc 返回。

CombatEnemy/CombatEnemyVisual/CombatEnemyProjectile 与原 GameEnemy 分离，运行资源及数值配置使用 data/enemy_combat_b04.json。
哥布林、奶狐、冰灵没有原游戏数值定义，保留为素材，不擅自编造平衡表或刷怪点。

## 文件

- preview.html：全部主体七动作的离线逐帧/连播、镜像、锚点检查；分享时保留整目录。
- frames/、sheets/、atlas/、manifests/：PNG 单帧、横条、图集及精确来源元数据。
- godot/<enemyId>.tres：每种敌人七动作 SpriteFrames；EnemyPresentation.tscn 提供可复用视觉组件。
- projectiles.json、projectile_frames/、projectile_sheets/：三种六帧循环弹体，碰撞根位于前端能量核心。
- contact_sheet.png：主体外观总览。
- qa/：校验、原始来源/逐帧哈希及游戏运行证据。

## 连续性与锚点

idle/move/telegraph/attack/recover/hurt 各 4 个独立原画帧，death 为 8 帧。预警与攻击按战斗窗口等比播放，视觉不直接决定伤害；死亡停止判定、奖励只结算一次，演出完成才移除。
每敌使用同一缩放、画布、语义根；地面以脚底/植物根、飞行以胸节或主体中心为根，镜像绕语义根。透明扩边仅为完整保留粒子及尾翼，不代表碰撞体变大。

## 原稿与生成

全部美术使用内置 image_gen 生成，无外部 API 或程序代画。
主体 RAW：assets/RAW/enemies/ENM-B04/v001/；弹体 RAW：assets/RAW/effects/ENM-B04/v001/。
原图、完整提示词、来源、入选与退稿、源裁切矩形、语义锚点、倍率、整数偏移保留在 RAW 与 manifest。
处理仅做裁切、固定最近邻缩放和透明画布平移；没有逐帧 bbox 归一缩放或删除原 alpha。

## 范围

实现基础巡逻追击、地面/飞行/悬浮/炮台、近战/远程、预警后方向锁定冲撞与死亡循环。
本次不等于全部专属 AI 设计完成：召唤、分裂、破盾、酸地与女王完整两阶段机制仍待后续实现。
