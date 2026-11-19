# forest_01 精细地形素材

2026-10-25，按制作人“墙体、平台等要用更精细的素材”要求新增。使用内置 `image_gen`（imagegen 技能）生成，原始图片保持完整，已复制入工程；没有调用 API/CLI 生成路径。

| 文件 | 实际尺寸 | 用途 |
|---|---|---|
| `moss_root_cliff_v1.png` | 1254×1254 | 岩层、树根、苔藓墙面，Godot Shader 在世界坐标采样 |
| `platform_sheet_v1.png` | 1254×1254，RGBA | 上方实心苔岩平台、下方细枝平台；通过 AtlasTexture 区域引用 |
| `wall_material.gdshader` | — | 连续墙面贴图，地形物理仍来自原 TileMapLayer |

切片范围、落脚线、厚度映射、端帽宽度、贴图缩放及植物位置全部写在 `data/maps/forest_01_art.json`。美术根须与苔藓是装饰；实心 32px / 单向 4px 碰撞、平台 ID 与类型标记保持不变。素材过滤用线性采样；装饰层 1，角色层 20。

复用的蕨叶、苔石和藤蔓来自工程已有 `assets/PROCESSED/environments/ENV-B01/v001/ENV-02/props/`；捷径栅栏复用已有森林图集的木纹。

## 墙面最终提示词

> Use case: stylized-concept. Asset type: a production diffuse albedo terrain texture for a high quality hand-painted 2D fantasy forest platformer. Generate one square 1024x1024 fully opaque seamless tileable texture, straight-on orthographic cross-section of compact ancient forest cliff earth and weathered grey green rocks intertwined with aged dark brown tree roots, moss in fissures, tiny patches of emerald lichen. Dense detailed irregular mineral strata, thin branching roots gripping stones, small dark recesses with warm bark highlights, natural varied shapes, painterly texture with crisp readable edges. This is a continuous solid wall fill material, flat and uniform illumination across the whole tile, no directional cast shadow, no horizon or standalone objects. It must tile seamlessly on all four sides. Keep overall material dark muted warm grey brown / moss green so it reads as opaque solid terrain in front of a teal forest background, enough detail to be beautiful at 1:1 without noisy high contrast speckling. No scenery, no sky, no leaves hanging in foreground, no grass surface on top, no free standing platform, no borders, no text, no grid, no labels, no symbols, no watermark. Painted natural game art, not a photograph and not low-resolution pixel art. Fill entire image edge to edge with the material.

## 平台最终提示词

> Use case: stylized-concept. Asset type: two isolated terrain sprites on one transparent production game sprite sheet, square 1024x1024. Exactly two assets, straight-on side elevation with no perspective, matching rich hand painted 2D ancient forest fantasy game artwork. TRANSPARENT background, fully separated assets, no backgrounds, no text or labels. Top half asset: a long horizontal solid forest ledge about 900px wide, positioned x=60..964 and y=180..390. Its standing surface is perfectly straight and horizontal, covered by a very thin lush moss carpet, tiny grass tufts along the lip, underneath is a thick solid section of irregular grey-green stones, compact warm brown earth and strong intertwined old woody roots gripping the rocks. Bottom silhouette has irregular tapered root tips and small moss fringe. The ledge must look thick, opaque and load bearing, readable rock layers, beautiful detailed roots, subtle rim light, dark shaded underside. Every point of the flat main standing surface has the same height. No big plants on top and no mushrooms. Bottom half asset: a separate very long EXTREMELY THIN nearly straight horizontal woody branch or vine walkway about 900px wide at x=60..964 and y=680..740, flat narrow top with a cool pale green moss rim and warm weathered bark grain below, tiny hanging moss fibers underneath, slim tapered ends. It must clearly look much thinner than the upper rock ledge. No supports, no posts, no chains. Between both assets leave at least 200px transparent separation. Leave ample transparent margin all around. Detail scale should be cohesive with painted forest backgrounds. No other objects, no backdrop, no frame, no letters, no diagrams, no checkerboard painted into image, no watermarks. This will be used as separate atlas regions in Godot, so preserve true alpha transparency.
