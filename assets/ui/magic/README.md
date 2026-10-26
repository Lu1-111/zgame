# 原创魔幻 UI

代码绘制源：`tools/build_magic_ui_assets.py`，10 张可缩放 SVG。文字和操作按钮由 Godot 实时绘制。

- `hud_frame.svg`：头像圈、三条相连量条及末端宝石。
- `inventory_panel.svg`：行囊 / 仓库 / 天赋古金面板。
- `rest_panel.svg`：灵火菜单与符文圆环。
- `slot.svg`：八角道具 / 技能格。
- `skill_{bubble,shield,heal,slam,starfall}.svg`：五个奶术图标。
- `hit_vignette.svg`：受击红边。

运行时代码：`scripts/ui/game_ui.gd`、`scripts/ui/magic_slot.gd`。数值配置：`data/gameplay_ui.json`。头像与坐姿使用 CHR-01 正式素材，道具图标使用 ITM-B01。
