#!/usr/bin/env python3
"""One spec -> three outputs that cannot disagree (they are all made from the same resolved numbers):

  1. preview images   ui/preview/<Name>.png (design size) and <Name>_<size>.png for the four checker sizes (+ .svg)
  2. game UI file     src/client/Ui/<Name>.luau      ModuleScript: Build(playerGui) -> refs (refs[id] for every node)
  3. Studio script    ui/generated/<Name>.studio.luau   run in Studio (Edit) to build the same UI in StarterGui
  + ui/generated/<Name>.manifest.json with the spec hash and a hash of each output, so check.py can catch drift.

Usage: gen.py <path/to/Name.ui.json> [--root PROJECT] [--no-png]
The project root defaults to the folder that contains ui/ (the spec lives in <root>/ui/specs/).
"""

import argparse
import base64
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, r"C:\Users\theha\.agents\skills\roblox-ui\scripts")
import uispec as U  # noqa: E402

BROWSERS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]


def find_browser():
    for b in BROWSERS:
        if Path(b).exists():
            return b
    for name in ("msedge", "chrome", "google-chrome", "chromium"):
        found = shutil.which(name)
        if found:
            return found
    return None


# ---------------------------------------------------------------- preview (SVG -> PNG)
def esc(t):
    return str(t).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def render_svg(spec, W, H, icons, root, label):
    elements, s = U.resolve(spec, W, H)
    ops = U.draw_ops(spec, elements, s, icons, root)
    th = spec["theme"]
    defs, body = [], []
    body.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
    for z in th.get("reserved", []):
        body.append(
            f'<rect x="{z["x"]}" y="{z["y"]}" width="{z["w"]}" height="{z["h"]}" fill="#FF3B3B" fill-opacity="0.12" '
            f'stroke="#FF3B3B" stroke-dasharray="6 4"/>'
            f'<text x="{z["x"] + 8}" y="{z["y"] + 18}" font-family="Segoe UI, Arial" font-size="12" fill="#B00000">{esc(z["name"])} (reserved)</text>'
        )
    for i, op in enumerate(ops):
        if op["op"] == "rrect":
            if op["w"] <= 0 or op["h"] <= 0:
                continue
            fill = op.get("fill")
            if op.get("grad"):
                gid = f"g{i}"
                defs.append(
                    f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{op["grad"][0]}"/>'
                    f'<stop offset="1" stop-color="{op["grad"][1]}"/></linearGradient>'
                )
                fill = f"url(#{gid})"
            body.append(
                f'<rect x="{f(op["x"])}" y="{f(op["y"])}" width="{f(op["w"])}" height="{f(op["h"])}" rx="{f(op["r"])}" '
                f'fill="{fill}" fill-opacity="{op.get("opacity", 1)}"><title>{esc(op["name"])}</title></rect>'
            )
        elif op["op"] == "text":
            left = op["name"] in th.get("leftAlignedText", [])
            text_x = op["x"] if left else op["x"] + op["w"] / 2
            text_anchor = "start" if left else "middle"
            body.append(
                f'<text x="{f(text_x)}" y="{f(op["y"] + op["h"] / 2)}" text-anchor="{text_anchor}" dominant-baseline="central" '
                f'font-family="{esc(op["font"])}" font-weight="900" font-size="{f(op["size"])}" fill="{op["fill"]}" '
                f'stroke="{op["stroke"]}" stroke-width="{f(op["sw"] * 2)}" stroke-linejoin="round" paint-order="stroke">{esc(op["text"])}</text>'
            )
        elif op["op"] == "icon":
            if op["file"]:
                data = base64.b64encode(Path(op["file"]).read_bytes()).decode()
                crop = icons.get(op["icon"], {}).get("rect")
                if crop:
                    cx, cy, cw, ch = crop
                    body.append(f'<svg x="{f(op["x"])}" y="{f(op["y"])}" width="{f(op["w"])}" height="{f(op["h"])}" viewBox="{cx} {cy} {cw} {ch}" overflow="hidden"><defs><clipPath id="crop{i}"><rect x="{cx}" y="{cy}" width="{cw}" height="{ch}"/></clipPath></defs><image href="data:image/png;base64,{data}" width="1448" height="1086" clip-path="url(#crop{i})"/></svg>')
                else:
                    body.append(f'<image href="data:image/png;base64,{data}" x="{f(op["x"])}" y="{f(op["y"])}" width="{f(op["w"])}" height="{f(op["h"])}" preserveAspectRatio="xMidYMid meet"/>')
            else:
                tag = "icon" if op["known"] else "NEEDS ICON"
                body.append(
                    f'<rect x="{f(op["x"])}" y="{f(op["y"])}" width="{f(op["w"])}" height="{f(op["h"])}" rx="6" fill="#FFFFFF" '
                    f'fill-opacity="0.25" stroke="#FFFFFF" stroke-dasharray="4 3"/>'
                    f'<text x="{f(op["x"] + op["w"] / 2)}" y="{f(op["y"] + op["h"] / 2)}" text-anchor="middle" dominant-baseline="central" '
                    f'font-family="Segoe UI, Arial" font-size="{f(max(9, min(14, op["h"] / 5)))}" fill="#FFFFFF">{tag}: {esc(op["icon"])}</text>'
                )
    defs.append('<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9CC8F5"/><stop offset="1" stop-color="#5E8F4E"/></linearGradient>')
    stamp = f'<text x="{W - 8}" y="{H - 8}" text-anchor="end" font-family="Segoe UI, Arial" font-size="11" fill="#000" fill-opacity="0.45">{esc(spec["name"])} {label} {W}x{H} scale {f(s)} spec {U.spec_hash(spec)}</text>'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
        f'<defs>{"".join(defs)}</defs>{"".join(body)}{stamp}</svg>'
    )


def svg_to_png(browser, svg_path, png_path, W, H):
    html = Path(tempfile.gettempdir()) / f"roblox_ui_{png_path.stem}.html"
    html.write_text(
        f'<html><body style="margin:0;overflow:hidden"><img src="{svg_path.resolve().as_uri()}" width="{W}" height="{H}"></body></html>',
        encoding="utf-8",
    )
    cmd = [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
           f"--screenshot={png_path}", f"--window-size={W},{H}", html.resolve().as_uri()]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    return png_path.exists()


# ---------------------------------------------------------------- Luau (game file + Studio script share one body)
def lnum(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if float(v).is_integer():
        return str(int(v))
    return ("%.4f" % v).rstrip("0").rstrip(".")


def lstr(t):
    return '"' + str(t).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def udim2(u):
    return f"UDim2.new({lnum(u[0][0])}, {lnum(u[0][1])}, {lnum(u[1][0])}, {lnum(u[1][1])})"


def color3(hexstr):
    r, g, b = U.hex_rgb(hexstr)
    return f"Color3.fromRGB({r}, {g}, {b})"


def layout_props(node):
    a = node.get("anchor", [0, 0])
    props = [f"AnchorPoint = Vector2.new({lnum(a[0])}, {lnum(a[1])})",
             f"Position = {udim2(node.get('pos', [[0, 0], [0, 0]]))}", f"Size = {udim2(node['size'])}"]
    if node.get("kind", "panel") == "text":
        props.append(f"TextSize = {lnum(node.get('textSize', 24))}")
    if "hidden" in node:
        props.append(f"Visible = {'false' if node.get('hidden') else 'true'}")
    return "{ " + ", ".join(props) + " }"


def build_body(spec, icons):
    """Lines of the Build function body (one tab of indent), creating every instance with design-space numbers.
    Nodes with a `phone` override also get a row in `layouts` so fit() can switch between desktop and phone."""
    th = spec["theme"]
    out = []
    counter = [0]

    def var():
        counter[0] += 1
        return f"v{counter[0]}"

    def common(node):
        a = node.get("anchor", [0, 0])
        return (f'Name = {lstr(node["id"])}, AnchorPoint = Vector2.new({lnum(a[0])}, {lnum(a[1])}), '
                f'Position = {udim2(node.get("pos", [[0, 0], [0, 0]]))}, Size = {udim2(node["size"])}')

    def emit(node, parent, top, phone_node):
        kind = node.get("kind", "panel")
        v = var()
        if kind in U.STACK_KINDS:
            top_c, bottom_c, shadow_c = U.stack_colors(th, U.base_color(th, node))
            face_class = "TextButton" if kind == "button" else "Frame"
            extra = ', Text = "", AutoButtonColor = false' if kind == "button" else ""
            out.append(f'\tlocal {v} = new("Frame", {{ {common(node)}, BackgroundTransparency = 1 }}, {parent})')
            out.append(f'\tlocal {v}s = new("Frame", {{ Name = "Shadow", Position = UDim2.new(0, 0, 0, {lnum(th["shadowOffset"])}), '
                       f'Size = UDim2.fromScale(1, 1), BackgroundColor3 = {color3(shadow_c)}, '
                       f'BackgroundTransparency = {lnum(round(1 - th["shadowAlpha"], 4))}, BorderSizePixel = 0, ZIndex = 1 }}, {v})')
            out.append(f'\tcorner({v}s, {lnum(th["radius"])})')
            out.append(f'\tnew("UIStroke", {{ Thickness = {lnum(th["outline"])}, Color = {color3(shadow_c)}, '
                       f'Transparency = {lnum(round(1 - th["shadowAlpha"], 4))}, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }}, {v}s)')
            out.append(f'\tlocal {v}f = new("{face_class}", {{ Name = "Face", Size = UDim2.fromScale(1, 1), '
                       f'BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2{extra} }}, {v})')
            out.append(f'\tcorner({v}f, {lnum(th["radius"])})')
            out.append(f'\tnew("UIGradient", {{ Rotation = 90, Color = ColorSequence.new({color3(top_c)}, {color3(bottom_c)}) }}, {v}f)')
            out.append(f'\tnew("UIStroke", {{ Thickness = {lnum(th["outline"])}, Color = {color3(th["outlineColor"])}, '
                       f'ApplyStrokeMode = Enum.ApplyStrokeMode.Border }}, {v}f)')
            ins, lh = th["liftInset"], th["liftHeight"]
            out.append(f'\tlocal {v}l = new("Frame", {{ Name = "Lift", Position = UDim2.new(0, {lnum(ins)}, 0, {lnum(ins / 2)}), '
                       f'Size = UDim2.new(1, {lnum(-2 * ins)}, 0, {lnum(lh)}), BackgroundColor3 = Color3.new(1, 1, 1), '
                       f'BackgroundTransparency = {lnum(round(1 - th["liftAlpha"], 4))}, BorderSizePixel = 0 }}, {v}f)')
            out.append(f'\tcorner({v}l, {lnum(min(th["radius"], lh / 2))})')
            out.append(f'\trefs[{lstr(node["id"])}] = {v}f')
            child_parent = f"{v}f"
        elif kind == "text":
            col = node.get("textColor") or th["text"]
            col = th["palette"].get(col, col)
            out.append(f'\tlocal {v} = new("TextLabel", {{ {common(node)}, BackgroundTransparency = 1, Text = {lstr(node["text"])}, '
                       f'TextSize = {lnum(node.get("textSize", 24))}, Font = Enum.Font.{th["font"]}, TextColor3 = {color3(col)}, '
                       f'TextWrapped = false, TextXAlignment = Enum.TextXAlignment.{"Left" if node["id"] in th.get("leftAlignedText", []) else "Center"}, ZIndex = 3 }}, {parent})')
            out.append(f'\tnew("UIStroke", {{ Thickness = {lnum(th["outline"])}, Color = {color3(th["outlineColor"])}, '
                       f'ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }}, {v})')
            out.append(f'\trefs[{lstr(node["id"])}] = {v}')
            child_parent = v
        elif kind == "icon":
            image = icons.get(node["icon"], {}).get("image", "")
            out.append(f'\tlocal {v} = new("ImageLabel", {{ {common(node)}, BackgroundTransparency = 1, Image = {lstr(image)}, '
                       f'ScaleType = Enum.ScaleType.Fit, ZIndex = 3 }}, {parent})')
            entry = icons.get(node["icon"], {})
            crop = entry.get("runtimeRect", entry.get("rect"))
            if crop:
                cx, cy, cw, ch = crop
                out.append(f'\t{v}.ImageRectOffset = Vector2.new({cx}, {cy})')
                out.append(f'\t{v}.ImageRectSize = Vector2.new({cw}, {ch})')
            if not image:
                out.append(f'\t-- NEEDS ICON: "{node["icon"]}" (ask the owner for it, then add it to ui/icons/icons.json)')
            out.append(f'\trefs[{lstr(node["id"])}] = {v}')
            child_parent = v
        elif kind == "divider":
            col = U.base_color(th, node) if node.get("color") else th["outlineColor"]
            out.append(f'\tlocal {v} = new("Frame", {{ {common(node)}, BackgroundColor3 = {color3(col)}, BorderSizePixel = 0 }}, {parent})')
            out.append(f'\trefs[{lstr(node["id"])}] = {v}')
            child_parent = v
        else:  # spacer
            out.append(f'\tlocal {v} = new("Frame", {{ {common(node)}, BackgroundTransparency = 1 }}, {parent})')
            out.append(f'\trefs[{lstr(node["id"])}] = {v}')
            child_parent = v
        if top:
            out.append(f'\ttable.insert(scales, {{ new("UIScale", {{}}, {v}), {lnum(node.get("zoom", 1))}, {lnum(phone_node.get("zoom", 1))} }})')
        if layout_props(node) != layout_props(phone_node):
            out.append(f"\ttable.insert(layouts, {{ {v}, {layout_props(node)}, {layout_props(phone_node)} }})")
        for kid in node.get("children", []):
            emit(kid, child_parent, False, U.effective(kid, True))
        for d, p in zip(U.synth_children(node), U.synth_children(phone_node)):
            emit(d, child_parent, False, p)

    for n in spec["nodes"]:
        emit(n, "gui", True, U.effective(n, True))
    return out


HELPERS = """local function new(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end
"""


def build_function(spec, icons, fname):
    th = spec["theme"]
    ref_h = spec["reference"]["height"]
    lines = [
        f"{fname}(playerGui)",
        "\tlocal refs = {}",
        "\tlocal scales = {} -- { UIScale, desktop zoom, phone zoom }",
        "\tlocal layouts = {} -- { instance, desktop props, phone props }",
        f'\tlocal gui = new("ScreenGui", {{ Name = {lstr(spec["name"])}, ResetOnSpawn = false, IgnoreGuiInset = true, '
        "ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)",
        f'\tgui:SetAttribute("SpecHash", {lstr(U.spec_hash(spec))})',
        "\trefs.Gui = gui",
        *build_body(spec, icons),
        "\tlocal function fit()",
        "\t\tlocal camera = workspace.CurrentCamera",
        "\t\tif not camera then",
        "\t\t\treturn",
        "\t\tend",
        "\t\tlocal height = camera.ViewportSize.Y",
        f"\t\tlocal phone = height <= {lnum(th['phoneMaxHeight'])}",
        f"\t\tlocal k = if phone then math.clamp(height / {lnum(th['phoneReferenceHeight'])}, {lnum(th['phoneMinScale'])}, {lnum(th['phoneMaxScale'])})",
        f"\t\t\telse math.clamp(height / {lnum(ref_h)}, {lnum(th['minScale'])}, {lnum(th['maxScale'])})",
        "\t\tfor _, scale in ipairs(scales) do",
        "\t\t\tscale[1].Scale = k * (if phone then scale[3] else scale[2])",
        "\t\tend",
        "\t\tfor _, row in ipairs(layouts) do",
        "\t\t\tfor key, value in pairs(if phone then row[3] else row[2]) do",
        "\t\t\t\trow[1][key] = value",
        "\t\t\tend",
        "\t\tend",
        "\tend",
        "\tfit()",
        "\tif workspace.CurrentCamera then",
        '\t\tworkspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)',
        "\tend",
        "\treturn refs",
        "end",
    ]
    return "\n".join(lines)



def bind_function(spec, icons):
    # Resolve the same generated hierarchy and responsive rows without allocating instances.
    body = build_function(spec, icons, 'function Ui.Bind')
    preamble = (
        f'\tlocal saved = playerGui:WaitForChild({lstr(spec["name"])})\n'
        f'\tassert(saved:IsA("ScreenGui") and saved:GetAttribute("SpecHash") == {lstr(U.spec_hash(spec))}, "Saved UI is stale; regenerate and bake it in Edit mode")\n'
        '\tlocal function new(className, props, parent)\n'
        '\t\tlocal inst = parent:FindFirstChild(props.Name or className)\n'
        '\t\tassert(inst and inst:IsA(className), "Saved UI is missing " .. (props.Name or className))\n'
        '\t\treturn inst\n'
        '\tend\n'
        '\tlocal function corner(parent, _radius)\n'
        '\t\tassert(parent:FindFirstChildOfClass("UICorner"), "Saved UI corner is missing")\n'
        '\tend\n'
    )
    return body.replace('function Ui.Bind(playerGui)\n', 'function Ui.Bind(playerGui)\n' + preamble, 1)


def game_file(spec, icons, rel_spec):
    h = U.spec_hash(spec)
    return (
        "--!nonstrict\n"
        f"-- GENERATED by roblox-ui from {rel_spec}. DO NOT EDIT: change the spec and run gen.py.\n"
        f"-- spec-hash: {h}\n"
        "-- Build(playerGui) creates the ScreenGui and returns refs: refs[<node id>] for every node (buttons: the Face\n"
        "-- TextButton, connect .Activated to it), refs.Gui for the ScreenGui.\n\n"
        f"{HELPERS}\nlocal Ui = {{}}\n\nUi.SpecHash = {lstr(h)}\n\n"
        f"{build_function(spec, icons, 'function Ui.Build')}\n\n{bind_function(spec, icons)}\n\nreturn Ui\n"
    )


def studio_file(spec, icons, rel_spec):
    h = U.spec_hash(spec)
    return (
        "--!nonstrict\n"
        f"-- GENERATED by roblox-ui from {rel_spec}. DO NOT EDIT. spec-hash: {h}\n"
        "-- Run in Roblox Studio (Edit mode, e.g. through the Studio MCP execute_luau tool) to build this UI in StarterGui\n"
        "-- for review. It is the same build code as the game file, so what you see here is what the game makes.\n\n"
        f"{HELPERS}\n{build_function(spec, icons, 'local function build')}\n\n"
        'local StarterGui = game:GetService("StarterGui")\n'
        f'local old = StarterGui:FindFirstChild({lstr(spec["name"])})\n'
        "if old then\n\told:Destroy()\nend\n"
        "local refs = build(StarterGui)\n"
        "local count = #refs.Gui:GetDescendants()\n"
        f'return "built {spec["name"]} in StarterGui: " .. count .. " instances, spec {h}"\n'
    )


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("spec")
    ap.add_argument("--root")
    ap.add_argument("--no-png", action="store_true")
    a = ap.parse_args()
    spec_path = Path(a.spec).resolve()
    root = Path(a.root).resolve() if a.root else spec_path.parent.parent.parent
    spec = U.load_spec(spec_path)
    errors = U.validate(spec)
    if errors:
        for e in errors:
            print("SPEC ERROR", e)
        print("gen: nothing generated (fix the spec first)")
        return 1
    icons = U.load_icons(root)
    name = spec["name"]
    rel_spec = spec_path.relative_to(root).as_posix() if spec_path.is_relative_to(root) else spec_path.name
    preview_dir = root / "ui" / "preview"
    gen_dir = root / "ui" / "generated"
    game_path = root / "src" / "client" / "Ui" / f"{name}.luau"
    for d in (preview_dir, gen_dir, game_path.parent):
        d.mkdir(parents=True, exist_ok=True)

    files = {}
    game_path.write_text(game_file(spec, icons, rel_spec), encoding="utf-8", newline="\n")
    studio_path = gen_dir / f"{name}.studio.luau"
    studio_path.write_text(studio_file(spec, icons, rel_spec), encoding="utf-8", newline="\n")
    files[game_path.relative_to(root).as_posix()] = U.norm_hash(game_path.read_text(encoding="utf-8"))
    files[studio_path.relative_to(root).as_posix()] = U.norm_hash(studio_path.read_text(encoding="utf-8"))
    print(f"wrote {game_path.relative_to(root).as_posix()}")
    print(f"wrote {studio_path.relative_to(root).as_posix()}")

    browser = None if a.no_png else find_browser()
    sizes = [("design", int(spec["reference"]["width"]), int(spec["reference"]["height"]))] + U.SIZES
    for label, W, H in sizes:
        stem = name if label == "design" else f"{name}_{label}"
        svg_path = preview_dir / f"{stem}.svg"
        svg_path.write_text(render_svg(spec, W, H, icons, root, label), encoding="utf-8")
        files[svg_path.relative_to(root).as_posix()] = hashlib.sha256(svg_path.read_bytes()).hexdigest()[:12]
        if browser:
            png_path = preview_dir / f"{stem}.png"
            if png_path.exists():
                png_path.unlink()
            if svg_to_png(browser, svg_path, png_path, W, H):
                print(f"wrote {png_path.relative_to(root).as_posix()}")
            else:
                print(f"WARNING: could not render {png_path.name} (the .svg preview is still there)")
    if not browser and not a.no_png:
        print("WARNING: no Edge/Chrome found, previews are .svg only")

    missing = U.missing_icons(spec, icons)
    manifest = {"name": name, "spec": rel_spec, "specHash": U.spec_hash(spec), "files": files, "missingIcons": missing}
    (gen_dir / f"{name}.manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    if missing:
        print("NEEDS ICONS (ask the owner): " + ", ".join(missing))
    print(f"gen: done, spec {manifest['specHash']}. Now run check.py.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
