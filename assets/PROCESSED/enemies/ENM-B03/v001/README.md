# ENM-B03 敌人动作与专属特效 v001

新增 5 类敌人，并精修苔甲虫。每种包含 idle、move、telegraph、attack、recover、hurt、death 共 7 组、32 帧；另有每种对应的六帧独立攻击 FX。总计 48 组、228 帧。

## 打开与使用

打开 `preview.html` 查看全部动作、逐帧、镜像、倍率、root、同步 FX 以及“预警 → 攻击 → 收招”。该页面直接读取相邻 PNG，无需联网，分享时保留整个目录。

此包已纳入主游戏资源导入，不再包含嵌套 `project.godot`；从主工程 F2 进入敌人演练场。原独立演示配置备份于 `work/enemy_b04_review/b03-standalone-config/`。可复用节点位于 `godot/EnemyPresentation.tscn`，使用 `select_enemy(gameEnemyId)` 与 `play_action(action, facing_left, rate)`；动作名称可通过 `action_mapping` 映射到现有状态。

将组件用于主工程时保留 godot/、frames/ 与 Catalog.gd 的相对目录关系；包内不放置独立 project.godot，避免主工程跳过资源导入。攻击、伤害、位移和无敌窗口仍由现有状态机决定。

## 类型、画布与锚点

| 素材 | 游戏编号 | 画布 | 锚点 | 主体帧数 |
|---|---|---|---|---|
| ENM-01 苔甲虫精修 | moss_beetle | 64×64 | (32, 56) | 32 |
| ENM-09 矿灯虫 | lamp_bug | 72×72 | (36, 35) | 32 |
| ENM-10 酸液蛞 | acid_slug | 64×64 | (32, 56) | 32 |
| ELT-01 苔甲卫 | moss_guard | 128×144 | (64, 100) | 32 |
| ELT-02 蜂巢守卫 | hive_guard | 120×112 | (66, 56) | 32 |
| ELT-03 酸液母体 | acid_mother | 104×120 | (50, 97) | 32 |

同一敌人的所有动作采用同一目标画布/root。透明画布大小包含武器、翅膀、拖尾和低 alpha 边缘，不代表碰撞体或体型；实际主体按共同游戏像素比例校准。每张源表仅使用一个固定倍率，A/B 表倍率由同一角色的站立高度校准，不按帧缩放。

地面 root 对齐脚底或软体接地点，飞行 root 对齐胸节。镜像围绕 VisualRoot，而非图片中心。死亡八帧按真实塌陷顺序播放；死亡与 FX 末段按生命周期平滑淡出。attack 完成后切换 recover 会继续播放原 FX 尾段。

## 原图与追溯

原稿由内置 image_gen 独立生成，位于 `assets/RAW/enemies/ENM-B03/v001/`；配对特效位于 `assets/RAW/effects/ENM-B03/v001/`。完整提示词、生成路径、入选源表与候选版本均保留。`catalog.json`、`manifests/` 记录实际源图 SHA256、源矩形、语义锚点、倍率、整数位移、FPS 与触发挂点。`processing/overrides.json` 记录统一透明扩边。

## 验证

`qa.json` 为全部帧门禁，`qa/` 保存联系图与组件、HTML 行为及主代理视觉审查。已检查真实透明、非空、源边安全、目标无裁切、预警时长和死亡跨行连续性。引擎与工程测试输出见验证记录。

本批是首版正式表现素材。生成帧仍有少量材质/轮廓变化；左右武器专属重绘、实际战斗挂点和手感联调属于后续接入工作。
