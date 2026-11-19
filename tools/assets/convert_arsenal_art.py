"""从像素画RAW以ImageMagick Point转换枪械和饰品，保留制作记录。"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from PIL import Image

from convert_weapon_art import PALETTE, ROOT, res, write


MANIFEST = ROOT / "data/art/arsenal_v001.json"
LAYOUT = ROOT / "data/art/arsenal_layout_v001.json"
REPORT = ROOT / "data/art/arsenal_conversion_v001.json"
COLORS = [
    "#573675" if color == "#938063" else "#9c70ca" if color == "#b95219" else color
    for color in PALETTE
]


def convert(binary, sources):
    """按登记画布、有效区域和锚点转换，每张源图只点采样一次。"""
    env = {**os.environ, "MAGICK_THREAD_LIMIT": "1", "MAGICK_OCL_DEVICE": "OFF"}
    version = subprocess.check_output([binary, "-version"], env=env, text=True).splitlines()[0]
    staging = ROOT / "work/arsenal"
    staging.mkdir(parents=True, exist_ok=True)
    palette = Image.new("RGB", (len(COLORS), 1))
    palette.putdata([tuple(bytes.fromhex(color[1:])) for color in COLORS])
    palette_path = staging / "palette.png"
    palette.save(palette_path)
    iron_palette = Image.new("RGB", (7, 1))
    iron_palette.putdata([tuple(bytes.fromhex(color[1:])) for color in COLORS[:7]])
    iron_palette_path = staging / "iron_palette.png"
    iron_palette.save(iron_palette_path)
    layout = json.loads(LAYOUT.read_text(encoding="utf8"))["sprites"]
    entries = []
    records = []
    for item in sources:
        identifier = item["id"]
        spec = layout[identifier]
        rifle = identifier.startswith("rifle_")
        category = "weapons" if rifle else "accessories"
        filename = "model.png" if rifle else "icon.png"
        raw = ROOT / f"assets/RAW/{category}/{identifier}/v001/source.png"
        raw.parent.mkdir(parents=True, exist_ok=True)
        if Path(item["source"]).resolve() != raw.resolve():
            shutil.copy2(item["source"], raw)
        write(raw.with_name("generation.json"), {"tool": "built-in imagegen", "prompt": item["prompt"]})
        source = Image.open(raw).convert("RGBA")
        bbox = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0).getbbox()
        if bbox is None:
            raise ValueError(f"{identifier}: transparent or empty RAW")
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        canvas = spec["canvas"]
        limit = spec["visible_limit"]
        ratio = min(limit[0] / w, limit[1] / h)
        sample = [max(1, round(w * ratio)), max(1, round(h * ratio))]
        offset = [(canvas[0] - sample[0]) // 2, (canvas[1] - sample[1]) // 2]
        output = ROOT / f"assets/PROCESSED/{category}/{identifier}/v001/{filename}"
        output.parent.mkdir(parents=True, exist_ok=True)
        selected_palette = iron_palette_path if spec.get("palette") == "iron" else palette_path
        command = [
            "-limit", "thread", "1", "-size", f"{canvas[0]}x{canvas[1]}", "xc:none",
            "(", str(raw), "-alpha", "on", "-channel", "A", "-threshold", "50%", "+channel",
            "-crop", f"{w}x{h}+{bbox[0]}+{bbox[1]}", "+repage", "-filter", "point", "-sample", f"{sample[0]}x{sample[1]}!",
            "-channel", "A", "-threshold", "50%", "+channel",
            "(", "+clone", "-alpha", "extract", "-write", "mpr:alpha", "+delete", ")",
            "-alpha", "off", "+dither", "-remap", str(selected_palette), "mpr:alpha", "-alpha", "off", "-compose", "CopyAlpha", "-composite",
            ")", "-geometry", f"+{offset[0]}+{offset[1]}", "-compose", "Over", "-composite",
            "-depth", "8", "-strip", "-define", "png:color-type=6", "PNG32:" + str(output),
        ]
        subprocess.run([binary, *command], env=env, check=True)
        entry = {"path": res(output), "native_canvas": canvas, "anchor": spec["anchor"], "runtime_scale": [1, 1]}
        entries.append(entry)
        records.append({
            "id": identifier, "source": res(raw), "source_pixels": list(source.size), "source_crop": list(bbox),
            "sampled_pixels": sample, "offset": offset, "canvas_pixels": canvas, "anchor": spec["anchor"],
            "runtime_scale": [1, 1], "resampling_passes": 1, "sampling": "ImageMagick Point, hard alpha, no dither",
            "palette": spec.get("palette", "shared"),
            "source_sha256": hashlib.sha256(raw.read_bytes()).hexdigest(), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        })
        if rifle:
            write(output.with_name("model.json"), {
                "id": identifier, "name": spec["name"], "weapon_type": "rifle", "texture": res(output),
                "native_canvas": canvas, "grip": spec["anchor"], "source_angle_degrees": 0, "runtime_scale": [1, 1],
            })
    write(REPORT, {"tool": "tools/assets/convert_arsenal_art.py", "tool_version": version, "conversions": records})
    pixel_spec = MANIFEST.with_name("arsenal_pixel_spec_v001.json")
    write(pixel_spec, {
        "palette": COLORS, "max_colors": 32, "conversion_report": res(REPORT),
        "sprite_canvases": {record["id"]: record["canvas_pixels"] for record in records},
    })
    manifest = {"id": "arsenal_v001", "pixel_standard": "res://data/art/pixel_standards.json", "pixel_spec": res(pixel_spec), "assets": entries}
    write(MANIFEST, manifest)
    print(f"ARSENAL POINT: {len(entries)} originals / {version}")


def register_layers():
    """挂接后把同画布逐帧层加入像素门禁清单。"""
    manifest = json.loads(MANIFEST.read_text(encoding="utf8"))
    manifest["assets"] = [entry for entry in manifest["assets"] if "derived_from" not in entry]
    layout = json.loads(LAYOUT.read_text(encoding="utf8"))["sprites"]
    frames = json.loads((ROOT / "assets/PROCESSED/weapons/appearances/v001/manifest.json").read_text(encoding="utf8"))
    for animation in frames["animations"].values():
        for frame in animation["frames"]:
            for identifier in sorted(layout.keys() & frame["skins"].keys()):
                manifest["assets"].append({
                    "path": frame["skins"][identifier]["weapon"], "native_canvas": frame["canvas"],
                    "anchor": [int(v) for v in frame["anchor"]], "runtime_scale": [1, 1], "derived_from": identifier,
                    "sampling": "1:1 nearest rotation from converted model",
                })
    write(MANIFEST, manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--magick", type=Path)
    parser.add_argument("--sources", type=Path)
    parser.add_argument("--register-layers", action="store_true")
    args = parser.parse_args()
    if args.register_layers:
        register_layers()
        return
    if not args.magick:
        parser.error("--magick is required for conversion")
    if args.sources:
        sources = json.loads(args.sources.read_text(encoding="utf8"))
    else:
        stored = json.loads(REPORT.read_text(encoding="utf8"))["conversions"]
        sources = []
        for record in stored:
            path = ROOT / record["source"][6:]
            generation = json.loads(path.with_name("generation.json").read_text(encoding="utf8"))
            sources.append({"id": record["id"], "source": str(path), "prompt": generation["prompt"]})
    convert(str(args.magick.resolve()), sources)


if __name__ == "__main__":
    main()
