# ENV-02 RAW 原画记录

本批使用内置 `image_gen`，共3张原始PNG。文件逐字节复制自工具返回的生成目录，未裁切、未缩放、未覆盖；提示词在 `prompts.json`，原始尺寸和SHA-256在 `sources.json`。

- `ENV-02_terrain_source_v001.png`：1254×1254，透明地形源表。
- `ENV-02_scenery_source_v001.png`：1536×1024，透明九模块源表。
- `ENV-02_background_source_v001.png`：1672×941，不透明森林远景原画。

透明请求使用 `transparent_background=true`。工具原图含alpha 0～254/255的轻微边缘值；PROCESSED在保留原画轮廓的基础上统一为alpha 0/255。RAW不是最终16像素游戏图块，不直接接入TileMap。处理结果位于对应 `assets/PROCESSED/environments/ENV-B01/v001/ENV-02/`，地图组合由主代理统一生成。
