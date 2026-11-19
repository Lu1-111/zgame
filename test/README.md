# 测试入口

正式武器攻击演练：双击[launchers/run_weapon_combat.cmd](launchers/run_weapon_combat.cmd)，选择13把现役武器，点击第1/2/3段或连续攻击，可重播、循环和切换朝向；使用正式Player状态机与倍率时序，独立存档目录。集成验证：godot --headless --path . res://test/scenes/weapon_attributes_test.tscn。面板与全套逐段/连段验证：res://test/scenes/weapon_gallery_validation.tscn。

武器独立模型：双击[launchers/run_weapon_appearances.cmd](launchers/run_weapon_appearances.cmd)，选择握点占位/原武器/替换示例，检查普攻、格挡、限定技能和左右镜像。[模型接入说明](../docs/art/武器模组与独立外观.md)。

洞穴敌怪逐帧检视：双击[launchers/run_cave_enemies.cmd](launchers/run_cave_enemies.cmd)，下拉选择七种敌怪、动作和独立效果；Space重播，主角静态母版同屏核对原生体型。此入口不写旅途存档、不使用占位战斗数值。[设计与尺寸表](../docs/art/cave敌怪设计-v001.md)。

cave洞穴素材：双击[launchers/run_cave_materials.cmd](launchers/run_cave_materials.cmd)，F5全景，E开箱，1/2模拟清场/钥匙解锁；详细说明见[洞穴素材包](../docs/art/cave素材包-v001.md)。

森林十图实际试玩：双击[launchers/run_forest_candidates.cmd](launchers/run_forest_candidates.cmd)。支持选图、F7切换二段跳、F8重置、R回检查点；详细说明见[备选地图试玩](../docs/maps/forest_candidates_试玩说明.md)。

- 单元：godot --headless --path . --script res://test/run_tests.gd
- 敌怪档案回填与编号安全：python -m unittest discover -s test/tools -p test_enemy_registry.py -v
- 像素数据门禁：python tools/qa/validate_pixel_packages.py
- 枪械与饰品实战：godot --headless --path . res://test/scenes/rifle_accessories_test.tscn
- 异常与弹幕演示：godot --path . --resolution 640x360 res://test/scenes/enemy_statuses_test.tscn
- 武器逐段与连段：双击 [run_weapon_combat.cmd](launchers/run_weapon_combat.cmd)，或运行 test/scenes/weapon_gallery_validation.tscn 自动检查。
- 森林原生实例：godot --headless --path . --script res://test/integration/test_forest_native_art.gd
- 洞穴敌怪动画：godot --headless --path . --script res://test/integration/test_cave_enemy_art.gd
- 物理：godot --headless --path . --fixed-fps 60 --max-fps 240 --script res://test/integration/test_forest_03.gd
- 演练：双击launchers/run_corrumpt.cmd，或在编辑器运行scenes/arenas下的场景。
- 预览：previews/存放截图和逐帧检查脚本，产物写入work/或docs/previews/。
- scenes/harnesses/为模拟宿主；fixtures/为测试替身；scripts/仅供测试场景。
- scenes/assets/集中原素材包中的角色预览和怪物Showcase；对应脚本在scripts/assets/与integration/assets/，正式SpriteFrames和可复用实体仍保存在素材包内。

请从工程根目录执行Godot命令。beta不包含此目录；正式标题的F2/F3入口仅在debug环境生效。
