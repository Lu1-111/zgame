#!/usr/bin/env python3
"""对 ENV-B01 的交付尺寸、来源、平台和门图作独立核验。"""
import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BATCH = ROOT / "assets/PROCESSED/environments/ENV-B01/v001"
SOURCE = ROOT / "data/world/regions.json"


def reachable(rooms, ability):
    """按照 one_way 落点和能力要求检查拓扑可达集合。"""
    known = {"camp_01"}
    queue = deque(known)
    by_id = {r["id"]: r for r in rooms}
    while queue:
        for door in by_id[queue.popleft()]["doors"]:
            if door["one_way"] or (door["requires"] and not ability):
                continue
            if door["target"] not in known:
                known.add(door["target"])
                queue.append(door["target"])
    return sorted(known)


def main():
    """检查完成后输出机器可读报告。"""
    rooms = json.loads(SOURCE.read_text())["rooms"]
    manifest = json.loads((BATCH / "manifest.json").read_text())
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    checks = []

    def check(label, result):
        checks.append({"check": label, "pass": bool(result)})

    check("15 source rooms / 15 delivered rooms", len(rooms) == len(manifest["rooms"]) == 15)
    check("world source unchanged", source_hash == manifest["source_sha256"])
    source_by_id = {r["id"]: r for r in rooms}
    partials = []
    for kit in manifest["kits"]:
        path = BATCH / kit
        info = json.loads((path / "kit.json").read_text())
        image = Image.open(path / info["terrain"])
        check(kit + " atlas 64x64 RGBA", image.size == (64, 64) and image.mode == "RGBA")
        for prop in info["props"]:
            p = Image.open(path / prop["path"])
            check(kit + "/" + prop["id"] + " integer tile canvas + real alpha", p.width % 16 == p.height % 16 == 0 and p.mode == "RGBA" and p.getchannel("A").getextrema() == (0,255))
        check(kit + " Godot TileSet exists", (BATCH/"godot"/(kit+".tres")).exists())
    for record in manifest["rooms"]:
        rid = record["id"]
        folder = BATCH / "maps" / rid
        layout = json.loads((folder / "layout.json").read_text())
        source = source_by_id[rid]
        check(rid + " exact room definition", layout["source_room"] == source)
        check(rid + " exact collider rectangles", [p["rect"] for p in layout["platforms"]] == source["platforms"])
        size = tuple(layout["size_px"])
        for layer in ["background", "midground", "terrain", "props", "hazards", "guides", "map", "design"]:
            img = Image.open(folder / (layer + ".png"))
            check(rid + "/" + layer + " image size", img.size == size and img.mode == "RGBA")
        check(rid + " exported scene", (folder/(rid+".tscn")).exists())
        check(rid + " Tiled image/object map", (folder/"map.tmj").exists())
        for p in layout["platforms"]:
            if not p["global_grid_aligned"]:
                partials.append({"room": rid, "rect": p["rect"]})
    before, after = reachable(rooms, False), reachable(rooms, True)
    check("before ability: reward room reachable, canopy gated", "cave_07" in before and "forest_06" not in before)
    check("after ability: all 15 rooms reachable", len(after) == 15)
    check("return shortcut authored one-way", any(d["target"] == "camp_01" and not d["one_way"] for d in source_by_id["cave_07"]["doors"]) and any(d["target"] == "cave_07" and d["one_way"] for d in source_by_id["camp_01"]["doors"]))
    report = {"batch":"ENV-B01", "checks":checks,"passed":sum(c["pass"] for c in checks),"total":len(checks),
              "source_sha256":source_hash,"topology_before_ability":before,"topology_after_ability":after,
              "non_global_grid_rectangles":partials,
              "scope":"Artifact validation and logical connectivity. No jump, AI, doors, damage, saves or full-run gameplay verification."}
    (BATCH/"VALIDATION.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(f"ENV-B01 ARTIFACT QA: {report['passed']}/{report['total']} PASS")
    for c in checks:
        if not c["pass"]:
            print("FAIL:", c["check"])
    raise SystemExit(0 if report["passed"] == report["total"] else 1)


if __name__ == "__main__":
    main()
