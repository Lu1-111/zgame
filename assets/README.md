# 素材索引

本批 5 把新枪沿用武器原生 48×24 画布，16 件饰品使用 32×32 图标。转换源位于 RAW/weapons 和 RAW/accessories，正式资源按 ID 归入 PROCESSED/weapons 和 PROCESSED/accessories。转换记录为 data/art/arsenal_conversion_v001.json。弩箭和状态粒子在 PROCESSED/effects/status_v001，采用原生网格绘制，电磁弹和电弧由运行时用原生像素线绘制。

新武器模型按PROCESSED/weapons/{武器ID}/v001归类，含48×24原生model.png、握点JSON与各动作frames；本批9把新增267张普攻/格挡/限定技能武器层。RAW/weapons/{ID}/v001保存像素画源和完整提示词。ImageMagick点采样记录在data/art/weapon_conversion_v001.json；统一32色、硬alpha、scale=(1,1)，像素包catalog_v001登记逐图契约。ID与物品描述见[武器登记表](../docs/gameplay/武器登记表.md)。

武器独立层位于PROCESSED/weapons/appearances/v001，含去武器身体、握点、掌指前景和原武器/示例武器层；装备以weapon_type选择模组、appearance_id选择模型。[制作与接入说明](../docs/art/武器模组与独立外观.md)。

RAW是原始制作源；PROCESSED是按内容类别、批次ID、版本保存的加工资源，两者均保留尚未实装的角色、技能和怪物。

environments内按backgrounds（背景）、terrain（墙体材质）、tilesets（地形图块）、props（场景装饰）细分，再按camp/forest地图ID或共享版本定位。effects、ui、audio、fonts、characters分别保存特效、界面、音频、字体和运行角色辅助资源；third_party保留第三方来源。

运行时小地图位于ui/map/minimaps。角色原型参考位于RAW/characters/reference。素材设计清单位于docs/art/素材设计清单.md。

cave洞穴素材按environments/{terrain,tilesets,props,backgrounds}/cave/v001归类；含岩壁与边角、晶石光源、石头/矿石/白骨、金属宝箱、石笋和石台。索引data/art/cave_v001.json，使用与预览见[洞穴素材包](../docs/art/cave素材包-v001.md)。高分辨率母版与提示词归档于RAW/environments/cave/v001，运行场景只引用原生像素加工资源。

forest原生重制资源按environments/{terrain,props,backgrounds}/forest/v002归类，覆盖三张正式森林和十张备选，索引data/art/forest_v002.json；旧地图与素材原样备份在根backup/2026-11-17_forest_original。共享旧材质仍被camp引用时保留依赖。[重制记录](../docs/art/forest原生素材重制-v002.md)。

洞穴敌怪保存在PROCESSED/enemies/CAVE-BONE/v001（骨龙三型与箭矢）和CAVE-BEASTS/v001（岩盔兽、蜘蛛、活化晶石、岩穴猎手与三种效果），合计184张原生逐帧；[动作与检视入口](../docs/art/cave敌怪设计-v001.md)。仅完成美术设计，不登记为正式地图战斗敌人，基础数值保持null。

所有新美术遵守AGENTS.md基本原则。data/art/pixel_standards.json与pixel_packages.json登记数值限制，各包pixel_spec登记画布与色板，pixel_contracts记录逐图有效范围和锚点。先真实工具转换，再执行tools/qa/validate_pixel_packages.py；生成图的“像素风格”不能替代转换。

PROCESSED/environments内的地图属于素材批次附带灰盒/制作参考；真正可玩的地图位于scenes/maps，对应配置在data/maps。不要将两者混为一谈。

素材包内用于单独查看角色/怪物的preview与Showcase场景已集中到test/scenes/assets；它们仍引用原批次的正式SpriteFrames和贴图。旧测试日志已归档到work/organization/archived_artifacts，不混入素材或beta。
