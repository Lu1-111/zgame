# 锻金奇幻 UI 素材

2026-10-27。由内置 imagegen 工具生成并复制到工程，不使用 CLI/API 回退。角色头像继续使用正式角色素材。

- `frames_atlas.png`：1774×887 RGBA，九种面板、按钮、槽位、HUD、提示、量条与装饰材质。
- `icons_atlas.png`：1536×1024 RGBA，25 个武器、主动、被动与装饰图标。
- `cursor_source.png`：透明背景的金属与翡翠光标原图，运行时等比例缩至 32 像素。

切片、布局和渐变在 `data/ui_skin.json`，`scripts/ui/rpg_skin.gd` 提供统一控件样式。框角以九宫格保形，内容区使用细粒皮革底纹，避免放大纹理或非无缝贴图重复造成粗糙接缝。文字由 Godot 控件实时绘制。

## 生成提示词

### 框架材质

```text
Create a PRODUCTION 2D FANTASY RPG UI MATERIAL ATLAS, exquisitely detailed hand-painted heavy dark bronze / aged gold / gunmetal armor, deep midnight teal leather panels, engraved vines and subtle glowing turquoise runes. It will replace crude vector UI in a real game. True transparent background, NO text, NO numbers, NO icons occupying content area, NO screenshot/mockup composition. Strict 3 columns x 3 rows equal cell atlas, each cell conceptual512x256, 1536x768 overall layout, generous transparent margins between disconnected pieces. ROW1 COL1 large wide ornate rectangular panel with substantial hammered bronze/gold frame, faceted corners, soft dark teal leather inset, corners detailed but center plain readable. ROW1 COL2 similar secondary panel with embossed beveled edges, center empty. ROW1 COL3 wide DIALOGUE panel, translucent smoky dark interior and elegant thick metal border, no portrait drawn. ROW2 COL1 exactly SQUARE inventory slot centered in the wide cell, square metal rim, recessed dark empty center, 8% bevelwidth; ROW2 COL2 long rectangular button with ornate raised heavy metal beveled rim, plain dark empty center; ROW2 COL3 compact tooltip/interaction plaque with engraved curled metal corners and plain dark center. ROW3 COL1 WIDE HUD frame: circular empty portrait socket at LEFT, attached to THREE EMPTY HORIZONTAL STATUS BAR CHANNELS to its right, red/amber/violet tiny gems at the tips, no filled bars or character; must be wide low height about3.3:1 ratio. ROW3 COL2 wide thin status bar trough with metallic caps, no fill and NO text; ROW3 COL3 wide ornate thin gold separator crest / underline. Keep each item fully inside its own equal cell; no overlap. Symmetrical scalable borders suitable for 9-slice, no extreme shadows bleeding between cells. Professional thick high-fidelity RPG menu art, worn polished edges, subtle scratches, realistic engraved metal craftsmanship, restrained highlights, dark unobtrusive centers. NO modern flat minimalism, no plastic neon, no bright parchment, no letters whatsoever.
```

### 图标材质

```text
Production fantasy RPG INVENTORY/SKILL ICON ATLAS, strict 5x5 equal square grid, 25 separate icons isolated on true transparent background with generous padding. NO text, NO labels, NO UI borders, NO full character sprites. Exquisitely detailed hand-painted gold/steel weapons, jeweled magic, deep teal highlights matching aged heavy bronze RPG UI. Each icon must read sharply at 32-48px, bold silhouettes, restrained painterly texture, concentrated white/gold highlights, not flat SVG. Row1: steel short sword brass hilt; pale ceramic milk-bottle warhammer with wooden handle; recurved wooden bow and single arrow; turquoise crystal milk mage staff; luminous cyan milk bubble projectile. Row2: gilded blue magic shield; milk shockwave ground impact; glowing healing heart with cream ribbon; falling violet/gold milk stars; crescent steel sword slash. Row3: pointed spear-like sword thrust; two crossed spinning blades; charged amber arrow; white/cyan milk beam; violet lightning; Row4: swirling green wind blades; ruby heart with ivy (vitality passive); glowing milky droplet pearl (mana passive); bronze breastplate (defense passive); ruby fang (life steal passive). Row5: gold sun heart (vital passive); violet spellbook (arcane passive); stack of antique coins; silver feather wings; ornate fantasy mouse cursor pointer with turquoise gem and bronze metal (single diagonally upward arrow, NO crosshair). Keep each icon entirely inside its own cell, no overlap or lettering. Uniform visual scale, high craftsmanship, dark fine outlines only, background stays transparent, bright effect glows subtle and localized.
```

### 独立光标

```text
A single production fantasy RPG mouse cursor asset. ONLY one slim arrow pointer aimed toward upper-left, with the SHARP TIP at the upper-left corner and small thick bronze engraved metal frame around a dark jade inlay, tiny cyan gemstone near base. Refined heavy antique fantasy metal matching a detailed bronze/teal RPG HUD. Clear recognisable mouse arrow silhouette; no crosshair, no hand, no letters, no UI panel, no circle, NO shadows or glow clouds beyond silhouette. Truly transparent pixels EVERYWHERE outside the cursor itself; do NOT paint any colored backdrop, gradient, checkerboard or scenery. Cursor should remain legible when reduced to 32x32 pixels. Enough empty transparent padding to see whole arrow but asset occupies most of canvas. Crisp outlined edge, subtle gold highlights, elegant craftsmanship.
```
