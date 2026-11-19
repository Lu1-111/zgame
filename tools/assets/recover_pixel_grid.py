"""整批恢复真实原生像素网格；共用网格/色板，结果只可固定平移补透明画布。

依赖：pip install -r tools/assets/requirements-pixel-recovery.txt
用法：python tools/assets/recover_pixel_grid.py --config params.json
      --output-dir work/recovered frame_00.png frame_01.png

JSON示例：{"pixel_width":5,"upscale_factor":1,"palette_limit":32,
"transparent_background":true,"expected_native_canvas":[49,55],
"target_canvas":[96,96],"output_offset":[23,33]}
target_canvas可省略以保留恢复原生图；补画布必须显式指定output_offset，或
native_anchor与output_anchor两对坐标。禁止按每帧可见包围盒缩放或自动对齐。

调用Proper Pixel Art公开API，未复制其实现。上游MIT许可与来源说明见
tools/assets/licenses/proper-pixel-art-LICENSE.txt及实际输出metadata.json。
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname

# 只限制本进程，且在NumPy/OpenCV首次导入之前设置。
for _variable in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ[_variable] = "1"

UPSTREAM_URL = "https://github.com/KennethJAllen/proper-pixel-art"
UPSTREAM_VERSION = "2.0.0"
UPSTREAM_REFERENCE_COMMIT = "4de0dda5ba066491b5b5fac3500365db4dfd665e"
MAX_SOURCE_PIXELS = 16_000_000
MAX_FRAMES = 128
ALLOWED_FIELDS = {
    "pixel_width", "upscale_factor", "palette_limit", "transparent_background",
    "expected_native_canvas", "target_canvas", "output_offset", "native_anchor",
    "output_anchor", "alpha_threshold", "transparency_majority_fraction",
}


def _integer(value, name, minimum=0, maximum=None):
    if type(value) is not int or value < minimum or (maximum is not None and value > maximum):
        raise ValueError(f"{name} must be an integer in {minimum}..{maximum or 'unbounded'}")
    return value


def _pair(value, name, minimum=0):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f"{name} must be [x, y]")
    return tuple(_integer(v, name, minimum) for v in value)


def _sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _package_provenance():
    distribution = importlib.metadata.distribution("proper-pixel-art")
    if distribution.version != UPSTREAM_VERSION:
        raise ValueError(f"proper-pixel-art=={UPSTREAM_VERSION} required, found {distribution.version}")
    raw_origin = distribution.read_text("direct_url.json")
    origin = json.loads(raw_origin) if raw_origin else {}
    installed_commit = origin.get("vcs_info", {}).get("commit_id")
    parsed = urlparse(origin.get("url", ""))
    if parsed.scheme == "file":
        checkout = Path(url2pathname(unquote(parsed.path)))
        if (checkout / ".git").exists():
            result = subprocess.run(
                ["git", "-C", str(checkout), "rev-parse", "HEAD"],
                capture_output=True, text=True, check=True, timeout=5,
            )
            installed_commit = result.stdout.strip()
    module_hashes = {}
    for name in ("video.py", "image.py", "mesh.py", "colors.py", "config.py"):
        path = Path(distribution.locate_file(f"proper_pixel_art/{name}"))
        module_hashes[name] = _sha256(path)
    return {
        "package": "proper-pixel-art", "version": distribution.version,
        "repository": UPSTREAM_URL, "license": "MIT",
        "upstream_reference_commit": UPSTREAM_REFERENCE_COMMIT,
        "installed_source_commit": installed_commit,
        "installed_origin": origin or {"note": "Package index install; VCS commit not embedded"},
        "installed_module_sha256": module_hashes,
    }


def _load_config(path):
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(config, dict):
        raise ValueError("Config must be a JSON object")
    unknown = set(config) - ALLOWED_FIELDS
    if unknown:
        raise ValueError(f"Unsupported config fields: {sorted(unknown)}; source anchors must be mapped explicitly using the saved mesh")
    _integer(config.get("pixel_width"), "pixel_width", 1)
    if type(config.get("upscale_factor")) is not int or config["upscale_factor"] != 1:
        raise ValueError("upscale_factor must explicitly be 1; output enlargement is forbidden")
    _integer(config.get("palette_limit", 32), "palette_limit", 1, 32)
    if type(config.get("transparent_background", False)) is not bool:
        raise ValueError("transparent_background must be true/false")
    _integer(config.get("alpha_threshold", 128), "alpha_threshold", 1, 255)
    fraction = config.get("transparency_majority_fraction", 0.5)
    if type(fraction) not in (int, float) or not 0 < fraction <= 1:
        raise ValueError("transparency_majority_fraction must be in (0, 1]")
    for field in ("expected_native_canvas", "target_canvas"):
        if field in config:
            _pair(config[field], field, 1)
    for field in ("output_offset", "native_anchor", "output_anchor"):
        if field in config:
            _pair(config[field], field)
    has_offset = "output_offset" in config
    has_anchors = "native_anchor" in config or "output_anchor" in config
    if has_offset and has_anchors:
        raise ValueError("Use output_offset OR native_anchor/output_anchor, never both")
    if has_anchors and not {"native_anchor", "output_anchor"} <= set(config):
        raise ValueError("native_anchor and output_anchor must be supplied together")
    if "target_canvas" in config and not (has_offset or has_anchors):
        raise ValueError("target_canvas requires an explicit common output_offset or anchor pair")
    if "target_canvas" not in config and (has_offset or has_anchors):
        raise ValueError("Placement coordinates require target_canvas")
    return config


def recover_batch(inputs, config, output_dir):
    """同尺寸原始帧一次确定公共网格/色板，严格检查后写出原生PNG和可追溯信息。"""
    import cv2
    import numpy as np
    from PIL import Image
    from proper_pixel_art.config import ColorConfig, PaletteConfig
    from proper_pixel_art.video import FramePipeline, compute_video_mesh

    cv2.setNumThreads(1)
    if not 1 <= len(inputs) <= MAX_FRAMES:
        raise ValueError(f"Require 1..{MAX_FRAMES} frames per shared batch")
    provenance = _package_provenance()
    names = [path.stem + "_native.png" for path in inputs]
    if len(set(name.lower() for name in names)) != len(names):
        raise ValueError("Source file stems must be unique")
    frames, source_records = [], []
    total_pixels = 0
    for path in inputs:
        with Image.open(path) as source:
            total_pixels += source.width * source.height
            if total_pixels > MAX_SOURCE_PIXELS:
                raise ValueError(f"Source batch exceeds {MAX_SOURCE_PIXELS} pixels; split it deliberately")
            if frames and source.size != frames[0].size:
                raise ValueError(f"Frame canvas mismatch: {path}; every RAW cell must have the same size")
            frames.append(source.convert("RGBA"))
        source_records.append({"path": str(path.resolve()), "sha256": _sha256(path), "canvas": list(frames[-1].size)})
    palette_limit = config.get("palette_limit", 32)
    colors = ColorConfig(
        method="palette", palette=PaletteConfig(num_colors=palette_limit),
        alpha_threshold=config.get("alpha_threshold", 128),
        transparency_majority_fraction=config.get("transparency_majority_fraction", 0.5),
    )
    mesh, factor = compute_video_mesh(frames, upscale_factor=1, pixel_width=config["pixel_width"])
    if factor != 1:
        raise ValueError("Upstream changed the native sampling factor")
    pipeline = FramePipeline(
        mesh, factor, frames[0].size, frames, scale_result=None,
        transparent_background=config.get("transparent_background", False), color_config=colors,
    )
    native_frames = [pipeline.process(frame) for frame in frames]
    native_canvas = native_frames[0].size
    if "expected_native_canvas" in config and native_canvas != tuple(config["expected_native_canvas"]):
        raise ValueError(f"Recovered canvas {native_canvas} differs from expected {config['expected_native_canvas']}")
    target_canvas = tuple(config.get("target_canvas", native_canvas))
    if target_canvas[0] * target_canvas[1] * len(inputs) > MAX_SOURCE_PIXELS:
        raise ValueError(f"Output batch exceeds {MAX_SOURCE_PIXELS} pixels")
    offset = tuple(config.get("output_offset", (0, 0)))
    if "native_anchor" in config:
        native_anchor, output_anchor = config["native_anchor"], config["output_anchor"]
        if any(v > limit for v, limit in zip(native_anchor, native_canvas)):
            raise ValueError("native_anchor outside recovered canvas")
        if any(v > limit for v, limit in zip(output_anchor, target_canvas)):
            raise ValueError("output_anchor outside target canvas")
        offset = tuple(out - origin for origin, out in zip(native_anchor, output_anchor))
    if any(origin < 0 or origin + size > limit for origin, size, limit in zip(offset, native_canvas, target_canvas)):
        raise ValueError(f"Recovered canvas {native_canvas} at {offset} exceeds target {target_canvas}; cropping/scaling is forbidden")
    outputs, output_records, union_colors = [], [], set()
    for image in native_frames:
        if image.size != native_canvas:
            raise ValueError("Shared mesh produced inconsistent native canvases")
        rgba = np.asarray(image.convert("RGBA"))
        alpha = sorted(map(int, np.unique(rgba[:, :, 3])))
        if any(value not in (0, 255) for value in alpha):
            raise ValueError("Recovered hard-edge asset contains fractional alpha")
        visible_colors = {tuple(map(int, color)) for color in np.unique(rgba[:, :, :3][rgba[:, :, 3] > 0], axis=0)}
        union_colors.update(visible_colors)
        if len(union_colors) > palette_limit:
            raise ValueError("Batch exceeds its shared palette limit")
        if image.getbbox() is None:
            raise ValueError("Recovered frame has no visible pixels")
        result = image
        if target_canvas != native_canvas or offset != (0, 0):
            result = Image.new("RGBA", target_canvas, (0, 0, 0, 0))
            result.paste(image, offset)  # 无mask复制，RGBA/alpha不重采样、不二次相乘。
        outputs.append(result)
        output_records.append({
            "native_canvas": list(native_canvas), "canvas": list(result.size),
            "native_visible_bbox": list(image.getbbox()), "visible_bbox": list(result.getbbox()),
            "opaque_colors": len(visible_colors), "native_alpha_values": alpha,
            "alpha_values": sorted(map(int, np.unique(np.asarray(result)[:, :, 3]))),
            "native_rgba_sha256": hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest(),
            "rgba_sha256": hashlib.sha256(result.convert("RGBA").tobytes()).hexdigest(),
        })
    palette_rgb = np.asarray(pipeline.palette_img.getpalette(), dtype=np.uint8).reshape(-1, 3)
    metadata = {
        "schema_version": 1, "tool": "tools/assets/recover_pixel_grid.py", "tool_version": "1.0.0",
        "dependency": provenance, "config": config, "sources": source_records,
        "source_canvas": list(frames[0].size), "mesh": {"x": list(map(int, mesh[0])), "y": list(map(int, mesh[1]))},
        "sampling_factor": factor, "output_scale": [1, 1], "post_recovery_resizes": 0,
        "placement": {"common_offset": list(offset), "target_canvas": list(target_canvas), "automatic_alignment": False},
        "palette": {"limit": palette_limit, "batch_opaque_colors": len(union_colors),
                    "shared_rgb": [list(map(int, c)) for c in palette_rgb[:palette_limit]],
                    "opaque_rgb": [list(c) for c in sorted(union_colors)],
                    "background_hex": pipeline.background_hex},
        "cpu_threads": 1, "outputs": output_records,
        "conversions": [{"id": path.stem, "source_pixels": list(frames[0].size),
                         "sampled_pixels": list(native_canvas), "canvas_pixels": list(target_canvas),
                         "resampling_passes": 1, "runtime_scale": [1, 1],
                         "sampling": "proper_pixel_art_shared_mesh_then_fixed_padding",
                         "common_offset": list(offset)} for path in inputs],
        "notice": "Grid recovery is a candidate conversion, not a substitute for native-density and animation review.",
    }
    # 先完成全批次校验，成功才写文件；不允许覆盖已有产物或源图。
    destinations = [output_dir / name for name in names] + [output_dir / "metadata.json"]
    if any(path.exists() for path in destinations):
        raise ValueError("Output already exists; choose a fresh output directory")
    output_dir.mkdir(parents=True, exist_ok=True)
    for image, destination, record in zip(outputs, destinations, output_records):
        image.save(destination)
        record.update(path=str(destination.resolve()), sha256=_sha256(destination))
    (output_dir / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata


def main():
    """读取显式JSON和有序帧列表，失败返回非零并说明拒绝的规格。"""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("frames", nargs="+", type=Path, help="Ordered same-size RAW frame cells")
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        metadata = recover_batch(args.frames, _load_config(args.config), args.output_dir)
    except (ValueError, OSError, ImportError, subprocess.SubprocessError, importlib.metadata.PackageNotFoundError) as error:
        print(f"Pixel grid recovery rejected: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"frames": len(metadata["outputs"]), "native_canvas": metadata["outputs"][0]["native_canvas"],
                      "output_canvas": metadata["outputs"][0]["canvas"], "batch_colors": metadata["palette"]["batch_opaque_colors"],
                      "metadata": str((args.output_dir / "metadata.json").resolve())}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
