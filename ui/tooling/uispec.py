"""Portable spec operations used by gen_atlas.py (standard library only).

Defaults and synthetic children are reconstructed from the checked-in Racer UI.
Layout annotations (action, purpose, center, allowOverlap) remain metadata;
Position/Size/AnchorPoint, not those annotations, determine Roblox geometry.
"""

import copy
import hashlib
import json
import math
import re
from pathlib import Path

STACK_KINDS = {"panel", "button"}
SIZES = [("desktop", 1920, 1080), ("laptop", 1280, 720),
         ("tablet", 1024, 768), ("phone", 844, 390)]
PALETTE = {"primary": "#1ED8FF", "accent": "#FFB02E",
           "success": "#3DDC63", "danger": "#FF4D5E"}
THEME = {"font": "FredokaOne", "text": "#FFFFFF", "outlineColor": "#12162B",
         "outline": 3, "radius": 10, "shadowOffset": 4, "shadowAlpha": .6,
         "liftInset": 4, "liftHeight": 6, "liftAlpha": .3, "gradient": .12,
         "minScale": .6, "maxScale": 1.4, "phoneMaxHeight": 500,
         "phoneReferenceHeight": 390, "phoneMinScale": .85, "phoneMaxScale": 1.15}
# Original shaded colours, retained exactly rather than approximating the art.
SHADOWS = {"#1ED8FF": "#12517B", "#AC63EE": "#3E2C76",
           "#FFB02E": "#584439", "#3DDC63": "#1B524A",
           "#FF4D5E": "#582549", "#202B47": "#121A41",
           "#293753": "#151E45", "#A36C93": "#3B2F59"}


def load_spec(path):
    spec = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(spec, dict):
        raise ValueError("spec must be an object")
    theme = spec.get("theme", {})
    if not isinstance(theme, dict):
        raise ValueError("theme must be an object")
    if not isinstance(theme.get("palette", {}), dict):
        raise ValueError("theme.palette must be an object")
    spec["theme"] = {**THEME, **theme,
                     "palette": {**PALETTE, **theme.get("palette", {})}}
    return spec


def load_icons(root):
    path = Path(root) / "ui/icons/icons.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def norm_hash(text):
    return hashlib.sha256(text.replace("\r\n", "\n").strip().encode()).hexdigest()[:12]


def spec_hash(spec):
    return norm_hash(json.dumps(spec, sort_keys=True, separators=(",", ":"), ensure_ascii=False))


def hex_rgb(value):
    if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise ValueError(f"expected #RRGGBB, got {value!r}")
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def base_color(theme, node):
    color = node.get("color", "primary")
    return theme["palette"].get(color, color)


def stack_colors(theme, color):
    rgb = hex_rgb(color)
    g = theme["gradient"]
    def hex_color(values):
        return "#" + "".join(f"{max(0, min(255, round(v))):02X}" for v in values)
    top = hex_color(c + (255 - c) * g for c in rgb)
    bottom = hex_color(c * (1 - g) for c in rgb)
    shadow = SHADOWS.get(color.upper())
    if shadow is None:
        shadow = hex_color(c * .3 + b * .7 for c, b in zip(rgb, hex_rgb(theme["outlineColor"])))
    return top, bottom, shadow


def visible(node):
    """Explicit visible wins over the legacy hidden alias."""
    return node.get("visible", not node.get("hidden", False))


def effective(node, phone=False):
    result = copy.deepcopy(node)
    override = result.pop("phone", {}) if phone else {}
    result.update(override)
    # A phone hidden override must be able to replace inherited visible.
    if "hidden" in override and "visible" not in override:
        result.pop("visible", None)
    return result


def synth_children(node):
    """Stack text is a full-face label; explicit children precede it."""
    if node.get("kind", "panel") not in STACK_KINDS or "text" not in node:
        return []
    return [{"id": node["id"] + "Label", "kind": "text", "text": node["text"],
             "pos": [[0, 0], [0, 0]], "size": [[1, 0], [1, 0]],
             "textSize": node.get("textSize", 24),
             **({"textColor": node["textColor"]} if "textColor" in node else {})}]


def validate(spec):
    errors, ids = [], set()
    def number(v):
        return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)
    def vector(v, dim):
        return isinstance(v, list) and len(v) == dim and all(number(x) for x in v)
    def udim(v):
        return isinstance(v, list) and len(v) == 2 and all(vector(x, 2) for x in v)
    def nodes(items):
        if not isinstance(items, list):
            errors.append("children/nodes must be an array")
            return
        for n in items:
            if not isinstance(n, dict):
                errors.append("node must be an object")
                continue
            ident = n.get("id")
            if not isinstance(ident, str) or not ident or ident == "Gui" or ident in ids:
                errors.append(f"invalid or duplicate id: {ident!r}")
            else:
                ids.add(ident)
            for phone in (False, True):
                if not isinstance(n.get("phone", {}), dict):
                    errors.append(f"{ident}: phone must be an object")
                    break
                e = effective(n, phone)
                prefix = f"{ident}{' phone' if phone else ''}"
                kind = e.get("kind", "panel")
                if not isinstance(kind, str) or kind not in STACK_KINDS | {"text", "icon", "divider", "spacer"}:
                    errors.append(f"{prefix}: unknown kind {kind}")
                if not udim(e.get("size")) or not udim(e.get("pos", [[0, 0], [0, 0]])):
                    errors.append(f"{prefix}: size/pos must be [[scale, offset], [scale, offset]]")
                if not vector(e.get("anchor", [0, 0]), 2):
                    errors.append(f"{prefix}: invalid anchor")
                for k in ("hidden", "visible"):
                    if k in e and not isinstance(e[k], bool):
                        errors.append(f"{prefix}: {k} must be boolean")
                for k in ("zoom", "textSize"):
                    if k in e and (not number(e[k]) or e[k] <= 0):
                        errors.append(f"{prefix}: {k} must be positive")
                if kind == "text" and not isinstance(e.get("text"), str):
                    errors.append(f"{prefix}: text is required")
                elif "text" in e and not isinstance(e["text"], str):
                    errors.append(f"{prefix}: text must be a string")
                if kind == "icon" and not isinstance(e.get("icon"), str):
                    errors.append(f"{prefix}: icon is required")
                for k in ("color", "textColor"):
                    if k in e:
                        try:
                            hex_rgb(spec["theme"]["palette"].get(e[k], e[k]))
                        except (ValueError, TypeError):
                            errors.append(f"{prefix}: invalid {k}")
                if phone and set(e) & {"id", "kind"} and any(e.get(k) != n.get(k) for k in ("id", "kind", "children", "text", "icon")):
                    errors.append(f"{prefix}: phone may change layout/style/visibility, not hierarchy or content")
            nodes(n.get("children", []))
            if isinstance(ident, str) and isinstance(n.get("kind", "panel"), str):
                nodes(synth_children(n))
    if not isinstance(spec.get("name"), str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", spec.get("name", "")):
        errors.append("name must be a safe identifier")
    ref = spec.get("reference", {})
    if not isinstance(ref, dict) or any(not number(ref.get(k)) or ref[k] <= 0 for k in ("width", "height")):
        errors.append("reference width/height must be positive")
    th = spec.get("theme", {})
    for k in THEME:
        if isinstance(THEME[k], (int, float)) and (not number(th.get(k)) or th[k] < 0):
            errors.append(f"theme.{k} must be nonnegative")
    for k in ("phoneReferenceHeight", "phoneMinScale", "minScale"):
        if th.get(k, 0) == 0:
            errors.append(f"theme.{k} must be positive")
    for k in ("gradient", "shadowAlpha", "liftAlpha"):
        if number(th.get(k)) and not 0 <= th[k] <= 1:
            errors.append(f"theme.{k} must be in [0, 1]")
    for low, high in (("minScale", "maxScale"), ("phoneMinScale", "phoneMaxScale")):
        if number(th.get(low)) and number(th.get(high)) and th[low] > th[high]:
            errors.append(f"theme.{low} must be <= {high}")
    if not isinstance(th.get("font"), str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", th.get("font", "")):
        errors.append("theme.font must be an Enum.Font identifier")
    for color in th.get("palette", {}).values():
        try:
            hex_rgb(color)
        except ValueError:
            errors.append(f"invalid palette colour {color!r}")
    if not isinstance(th.get("leftAlignedText", []), list):
        errors.append("theme.leftAlignedText must be an array")
    reserved = th.get("reserved", [])
    if not isinstance(reserved, list):
        errors.append("theme.reserved must be an array")
    else:
        for zone in reserved:
            if not isinstance(zone, dict) or not isinstance(zone.get("name"), str) or any(not number(zone.get(k)) for k in ("x", "y", "w", "h")):
                errors.append("reserved zones require name and numeric x/y/w/h")
    for k in ("text", "outlineColor"):
        try:
            hex_rgb(th.get(k))
        except ValueError:
            errors.append(f"theme.{k}: invalid colour")
    nodes(spec.get("nodes"))
    return errors


def missing_icons(spec, icons):
    missing = set()
    def walk(node):
        if node.get("kind") == "icon" and not icons.get(node["icon"], {}).get("image"):
            missing.add(node["icon"])
        for child in node.get("children", []) + synth_children(node):
            walk(child)
    for node in spec["nodes"]:
        walk(node)
    return sorted(missing)


def resolve(spec, width, height):
    th = spec["theme"]
    phone = height <= th["phoneMaxHeight"]
    k = max(th["phoneMinScale"] if phone else th["minScale"],
            min(th["phoneMaxScale"] if phone else th["maxScale"],
                height / (th["phoneReferenceHeight"] if phone else spec["reference"]["height"])))
    elements = []
    def walk(raw, parent, scale, top=False, shown=True):
        node = effective(raw, phone)
        position_scale = 1 if top else scale
        if top:
            scale *= node.get("zoom", 1)
        px, py, pw, ph = parent
        size = node["size"]
        w, h = (size[0][0] * pw * (scale if top else 1) + size[0][1] * scale,
                size[1][0] * ph * (scale if top else 1) + size[1][1] * scale)
        pos, anchor = node.get("pos", [[0, 0], [0, 0]]), node.get("anchor", [0, 0])
        x = px + pos[0][0] * pw + pos[0][1] * position_scale - anchor[0] * w
        y = py + pos[1][0] * ph + pos[1][1] * position_scale - anchor[1] * h
        shown = shown and visible(node)
        elements.append({"node": node, "x": x, "y": y, "w": w, "h": h,
                         "scale": scale, "visible": shown})
        for child in node.get("children", []) + synth_children(node):
            walk(child, (x, y, w, h), scale, shown=shown)
    for node in spec["nodes"]:
        walk(node, (0, 0, width, height), k, top=True)
    return elements, k


def draw_ops(spec, elements, scale, icons, root):
    ops, th = [], spec["theme"]
    for e in elements:
        if not e["visible"]:
            continue
        n, s = e["node"], e["scale"]
        box = {k: e[k] for k in ("x", "y", "w", "h")}
        box["name"] = n["id"]
        kind = n.get("kind", "panel")
        if kind in STACK_KINDS:
            top, bottom, shadow = stack_colors(th, base_color(th, n))
            ops.append({**box, "op": "rrect", "y": e["y"] + th["shadowOffset"] * s,
                        "r": th["radius"] * s, "fill": shadow, "opacity": th["shadowAlpha"],
                        "stroke": shadow, "sw": th["outline"] * s})
            ops.append({**box, "op": "rrect", "r": th["radius"] * s,
                        "grad": (top, bottom), "stroke": th["outlineColor"], "sw": th["outline"] * s})
            ins, lh = th["liftInset"] * s, th["liftHeight"] * s
            ops.append({**box, "op": "rrect", "x": e["x"] + ins, "y": e["y"] + ins / 2,
                        "w": e["w"] - 2 * ins, "h": lh, "r": min(th["radius"] * s, lh / 2),
                        "fill": "#FFFFFF", "opacity": th["liftAlpha"]})
        elif kind == "text":
            col = n.get("textColor", th["text"])
            ops.append({**box, "op": "text", "text": n["text"], "size": n.get("textSize", 24) * s,
                        "font": th["font"], "fill": th["palette"].get(col, col),
                        "stroke": th["outlineColor"], "sw": th["outline"] * s})
        elif kind == "icon":
            entry = icons.get(n["icon"], {})
            path = Path(root) / "ui/icons" / entry.get("file", "")
            ops.append({**box, "op": "icon", "icon": n["icon"], "known": bool(entry),
                        "file": str(path) if path.is_file() else None})
        elif kind == "divider":
            ops.append({**box, "op": "rrect", "r": 0,
                        "fill": base_color(th, n) if n.get("color") else th["outlineColor"]})
    return ops
