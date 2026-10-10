#!/usr/bin/env python3
"""Verify generation in a disposable root; never overwrite shipped UI/assets.

Optional Lune compares actual constructed/serialized instance properties against
the original modules at six viewport sizes, and exercises Build/Bind round trips.
"""
import argparse
import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import gen_atlas as G
import uispec as U


def canonical_model(xml):
    rows = {}
    def value(el):
        return (el.tag, (el.text or "").strip(), tuple(value(child) for child in el))
    def walk(item, parent):
        props = {el.get("name"): el for el in item.find("Properties")}
        name = props["Name"].text
        path = f"{parent}/{name}"
        assert path not in rows, f"duplicate sibling {path}"
        rows[path] = (item.get("class"), {key: value(el) for key, el in props.items()
                                        if key not in {"AttributesSerialize", "UniqueId", "HistoryId"}})
        # XML records explicitly assigned defaults that old modules may omit.
        properties = rows[path][1]
        for key, default in {"TextXAlignment": ("token", "2", ()),
                             "Visible": ("bool", "true", ())}.items():
            if properties.get(key) == default:
                properties.pop(key)
        for child in item.findall("Item"):
            walk(child, path)
    for item in ET.fromstring(xml).findall("Item"):
        walk(item, "")
    return rows


def helper_checks(spec, icons, project):
    assert not U.validate(spec), U.validate(spec)
    hidden = {"id": "Parent", "kind": "spacer", "size": [[0, 100], [0, 50]],
              "hidden": True, "children": [{"id": "Child", "kind": "text",
              "text": "invisible", "size": [[1, 0], [1, 0]]}]}
    for visibility in ({"hidden": True}, {"visible": False}, {"hidden": False, "visible": False}):
        test = copy.deepcopy(spec)
        test["nodes"] = [{**hidden, **visibility}]
        elements, scale = U.resolve(test, 1280, 720)
        assert not U.draw_ops(test, elements, scale, icons, project)
        assert "Visible = false" in "\n".join(G.build_body(test, icons))
    node = {**hidden, "visible": False, "phone": {"hidden": False}}
    assert U.visible(U.effective(node, True))
    node["phone"] = {"visible": True}
    assert U.visible(U.effective(node, True))
    node["phone"] = {"visible": False, "hidden": False}
    assert not U.visible(U.effective(node, True))
    static = copy.deepcopy(spec)
    static["nodes"] = [{**hidden, "children": []}]
    assert "Visible = false" in "\n".join(G.build_body(static, icons))
    for mutate in (lambda s: s["nodes"][0].update(size=[1, 2]),
                   lambda s: s["nodes"][0].update(visible="false"),
                   lambda s: s["nodes"][0].update(kind="unknown"),
                   lambda s: s["nodes"].append(copy.deepcopy(s["nodes"][0])),
                   lambda s: s.update(name="../escape")):
        bad = copy.deepcopy(spec)
        mutate(bad)
        assert U.validate(bad), "invalid spec accepted"
    sample = {"id": "Button", "kind": "button", "text": "GO", "textSize": 23}
    assert U.synth_children(sample) == [{"id": "ButtonLabel", "kind": "text", "text": "GO",
                                         "pos": [[0, 0], [0, 0]], "size": [[1, 0], [1, 0]], "textSize": 23}]
    assert U.synth_children({**sample, "kind": "text"}) == []
    required = {"rusty_hatchback", "wooden_car", "go_kart", "street_racer", "rocket_car", "hover_car", "void_racer"}
    assert required <= icons.keys()
    for name in required:
        entry = icons[name]
        assert entry["image"] == "rbxassetid://121915283083474"
        assert len(entry["rect"]) == len(entry["runtimeRect"]) == 4
    # Verify known anchor/UIScale geometry independent of renderer.
    geometry = copy.deepcopy(spec)
    geometry["nodes"] = [{"id": "Box", "kind": "spacer", "anchor": [.5, 1],
                          "pos": [[.5, 10], [1, -20]], "size": [[0, 100], [0, 50]], "zoom": 2,
                          "children": [{"id": "Fill", "kind": "divider", "size": [[1, -10], [1, 0]]}]}]
    boxes, scale = U.resolve(geometry, 1280, 720)
    assert scale == 1 and (boxes[0]["x"], boxes[0]["y"], boxes[0]["w"], boxes[0]["h"]) == (550, 600, 200, 100)
    assert boxes[1]["w"] == 180


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lune", action="store_true", help="require Lune and compare serialized instance trees")
    a = ap.parse_args()
    project = Path(__file__).resolve().parents[2]
    tooling = Path(__file__).resolve().parent
    specs = sorted((project / "ui/specs").glob("*.ui.json"))
    specs += [project / "ui/concept-draft/ui/specs/RacerHudConcept.ui.json"]
    icons = U.load_icons(project)
    helper_checks(U.load_spec(specs[0]), icons, project)
    with tempfile.TemporaryDirectory(prefix="racer-ui-verify-") as temp:
        root = Path(temp)
        print(f"Temporary output root: {root}")
        for path in specs:
            result = subprocess.run([sys.executable, "-B", str(tooling / "gen_atlas.py"), str(path),
                                     "--root", str(root), "--no-png"], capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            spec = U.load_spec(path)
            manifest = json.loads((root / f"ui/generated/{spec['name']}.manifest.json").read_text())
            assert not manifest["missingIcons"]
            assert manifest["specHash"] == U.spec_hash(spec)
            for rel, digest in manifest["files"].items():
                output = root / rel
                actual = hashlib.sha256(output.read_bytes()).hexdigest()[:12] if output.suffix == ".svg" else U.norm_hash(output.read_text())
                assert digest == actual, rel
                if output.suffix == ".svg":
                    ET.parse(output)
            assert len(manifest["files"]) == 7
            assert (root / f"src/client/RollToast/Ui/{spec['name']}.luau").exists()
            if spec["name"] == "RacerHud":
                svg = (root / "ui/preview/RacerHud.svg").read_text()
                assert "ROLLS" not in svg and ">AUTO<" not in svg
                assert "TURBO LUCK" in svg and "data:image/png;base64" in svg
            # Repeat generation to catch nondeterministic output/hashes.
            repeat = subprocess.run(result.args, capture_output=True, text=True)
            assert repeat.returncode == 0 and json.loads((root / f"ui/generated/{spec['name']}.manifest.json").read_text()) == manifest
        print("PASS: seven specs, 35 SVGs, manifests, deterministic output, visibility, geometry and icon metadata")
        if a.lune:
            assert shutil.which("lune"), "Lune is required by --lune"
            result = subprocess.run(["lune", "run", str(tooling / "verify_models.luau"), str(root), str(project)], capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            data = json.loads(result.stdout)
            for pair in data["comparisons"]:
                original = canonical_model(pair["original"])
                generated = canonical_model(pair["generated"])
                assert original.keys() == generated.keys(), pair["name"]
                for path, (cls, props) in generated.items():
                    old_cls, old_props = original[path]
                    assert cls == old_cls, path
                    for key in props.keys() | old_props.keys():
                        if props.get(key) == old_props.get(key):
                            continue
                        # These are the only authored differences from legacy output.
                        if key == "Visible" and path == "/RacerHud/RollControls":
                            assert props[key][1] == "false"
                            continue
                        if key == "TextXAlignment" and path.rsplit("/", 1)[-1] in {"MoneyValue", "SpeedValue", "Unbanked"}:
                            continue
                        # Legacy HUD lacked atlas crops; its controller repairs them.
                        if key in {"ImageRectOffset", "ImageRectSize"} and path in {"/RacerHud/Speed/SpeedIcon", "/RacerHud/Money/MoneyIcon"}:
                            icon = icons["speed" if path.endswith("SpeedIcon") else "cash"]
                            rect = icon["runtimeRect"]
                            xy = rect[:2] if key == "ImageRectOffset" else rect[2:]
                            assert props[key][2] == (("X", str(xy[0]), ()), ("Y", str(xy[1]), ()))
                            continue
                        raise AssertionError(f"{pair['name']} {pair['width']}x{pair['height']} {path}.{key}: {old_props.get(key)} != {props.get(key)}")
            print(f"PASS: {len(data['comparisons'])} Lune property comparisons, responsive transitions, binary round trips and Bind")
            print("Read-only saved asset inventory:", data["asset"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
