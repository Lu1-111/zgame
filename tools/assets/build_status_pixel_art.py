"""手工逐像素绘制异常粒子与弩箭，像素图直接在登记尺寸上绘制。"""

from PIL import Image

from convert_weapon_art import ROOT, res, write


COLORS = {
    "r": "#bd2949", "R": "#fb6273", "g": "#478752", "G": "#96df70",
    "i": "#87c8ec", "I": "#e1f8ff", "b": "#55453c", "s": "#985d35",
    "S": "#d59a57", "F": "#a6adbd", "H": "#eef0f6", "f": "#695b73",
}
ART = {
    "bleeding": (["R.", "rr"], [1, 1]),
    "poison": ([".G.", "Ggg", ".g."], [1, 1]),
    "chill": (["i.I.i", ".III.", "IIIII", ".III.", "i.I.i"], [2, 2]),
    "bolt": ([
        "ff......................",
        "FFF.................HH..",
        ".FSSSSSSSSSSSSSSSSSFHHH.",
        ".fsssssssssssssssssFFHFF",
        ".FbbbbbbbbbbbbbbbbbfFFF.",
        "fff.................ff..",
        "ff......................",
    ], [23, 3]),
}


def main():
    assets = []
    canvas = {}
    for name, (rows, anchor) in ART.items():
        size = [len(rows[0]), len(rows)]
        if any(len(row) != size[0] for row in rows):
            raise ValueError(f"{name}: uneven pixel rows")
        sprite = Image.new("RGBA", tuple(size))
        for y, row in enumerate(rows):
            for x, key in enumerate(row):
                if key != ".":
                    sprite.putpixel((x, y), (*bytes.fromhex(COLORS[key][1:]), 255))
        output = ROOT / f"assets/PROCESSED/effects/status_v001/{name}.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        sprite.save(output)
        assets.append({
            "path": res(output), "native_canvas": size, "runtime_scale": [1, 1],
            "anchor": anchor, "world_size": size, "authored_native": True,
        })
        canvas[name] = size
    spec = ROOT / "data/art/status_pixel_spec_v001.json"
    write(spec, {"palette": list(COLORS.values()), "max_colors": len(COLORS), "sprite_canvases": canvas})
    write(ROOT / "data/art/status_pixel_manifest_v001.json", {
        "id": "status_v001", "pixel_standard": "res://data/art/pixel_standards.json",
        "pixel_spec": res(spec), "assets": assets,
    })
    print(f"STATUS NATIVE PIXELS: {len(assets)} originals")


if __name__ == "__main__":
    main()
