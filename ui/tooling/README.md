# Portable Racer UI generation

`gen_atlas.py` and its local `uispec.py` need Python 3.10+ and the standard library.
There is no external skill import, Windows dependency, or package installation.
The missing external helper/schema was not available in this checkout; the
implemented contract is reconstructed from all seven checked-in specs and their
generated modules. This is not a claim of compatibility with undocumented fields
from the lost external schema.

While the harness is frozen, generate into a temporary root only:

```sh
preview_root=$(mktemp -d)
python3 -B ui/tooling/gen_atlas.py ui/specs/RacerHud.ui.json --root "$preview_root" --no-png
python3 -B ui/tooling/verify.py --lune
```

The first command retains the HUD refresh for review. `verify.py` creates and
cleans its own disposable root, generating all six shipped specs and the concept
draft. It never writes `src/`, `assets/`, specs, or project tests. `--lune` requires
Lune; without it, verification uses only Python. The generated Studio scripts are
artifacts for later review; verification does not execute them in Studio.

Outputs under `--root`:

- `src/client/RollToast/Ui/<Name>.luau`: `Build` and hash-checked `Bind`.
- `ui/generated/<Name>.studio.luau` and `<Name>.manifest.json`.
- Five SVG previews per spec (design, desktop, laptop, tablet, phone). Optional PNG
  rendering uses a locally discovered Chrome/Edge/Chromium and an isolated profile.

Without `--root`, the generator writes into the source project. Icon metadata and
preview art are always read from the source spec's `<project>/ui/icons/`, even when
outputs go elsewhere. Preview `rect` and uploaded `runtimeRect` remain separate;
all seven imported car entries and other icon metadata are consumed unchanged.
The existing atlas renderer retains the 1448x1086 source sheet dimensions.

The contract uses recursive nodes with `id`, `kind`, `size`, optional `pos`,
`anchor`, `children`, `zoom`, `text`, `textSize`, `textColor`, `color`, and `icon`.
Kinds are panel, button, text, icon, divider, spacer. UDim2 values are
`[[xScale, xOffset], [yScale, yOffset]]`. Phone overrides replace complete layout
fields, including a whole UDim2 or anchor, and may change styling/visibility but
not IDs, kinds, content or hierarchy. Explicit children are emitted first; stack
text adds `<id>Label`, filling the face with the node's text size/colour. Duplicate
IDs (including synthetic labels and reserved `Gui`) fail validation before writes.
`action`, `purpose`, `center`, and `allowOverlap` remain annotations; authored
positions and anchors determine geometry. The helper checks structural validity,
not runtime actions, overlap rules, or a Roblox enum catalogue.

`visible` takes precedence over legacy `hidden`. A phone `hidden` override replaces
inherited desktop `visible` unless that override also supplies `visible`. Visibility
is assigned when creating every node and included in responsive rows. Hidden
ancestors suppress all descendant preview operations, while generated descendants
and refs remain available. Top-level UIScale changes size, not position offsets;
child offsets inherit the scale, matching `UiResponsive.ScaledHudRect`.

Defaults reproduce the shipped FredokaOne, gradient, outline, lift, shadow and
responsive scale values. Original shadow shades are retained for the known Racer
colours; new colours use a deterministic outline blend. Hashes are computed locally
from the resolved spec and are deterministic; they may differ from the lost helper.
Refreshing modules therefore requires a matching later bake before hash-checked
`Bind` can use the saved asset.

Verification checks deterministic manifests and hashes, SVG XML, hidden ancestors,
phone visibility overrides, invalid specs, anchor/scale geometry, and icon metadata.
The optional Lune pass executes original and generated `Build` at six viewports
including 500/501px heights, tests viewport callbacks, serializes/deserializes each
generated GUI, and exercises `Bind`. It compares serialized property trees rather
than source formatting. Allowed legacy differences are HUD visibility and the
spec-authored left alignment / Money and Speed crops already repaired by the
controller. Attribute blobs are excluded from cross-version property comparison;
each generated hash is separately enforced by `Bind`. PNG fidelity and live Roblox
layout/click/physics compatibility are not certified by these offline checks.

## Future portable bake: assessment only

No baker or real asset write is included. Coordination notice was sent to the
main agent through the agent bus; any `tools/` baker belongs to that separate work.
Lune 0.10.5 successfully runs these `Build` functions with `luau.load` using
`@lune/roblox` datatypes, serializes binary models, reads them back, and binds them.
Relevant APIs: [Roblox serialization](https://lune-org.github.io/docs/api-reference/roblox/)
and [Luau custom environments](https://lune-org.github.io/docs/api-reference/luau/).

The existing `assets/studio/StarterGui.rbxm` contains one `StarterGui` container with
exactly six ScreenGuis. `default.project.json` maps that asset as StarterGui; retain
the container shape and serialize `{ starterGui }`, not six flattened root GUIs.
The read-only inventory found 150 additional descendants in RacerIndex's Gallery
and 79 in RacerStats' Rows. The other four GUI hierarchies match their module bases.
Replacing the entire asset with plain `Build` output would lose those required
components: `BindIndex` and `BindStats` expect them. Either rebuild them explicitly
through `Components.BakeIndex` / `BakeStats` with the actual catalog/config, or
preserve the named subtrees while auditing their version; never blindly copy stale
geometry, properties, or SpecHash from the old module skeleton. The controller
rebuilds outdated galleries for the now-ten-entry catalog and adds the free-points
HUD badge through `BakeHud`; account for these independently from the original
seven imported icon entries.

Use an explicit environment for `Instance`, `Enum`, `Vector2`, `UDim`, `UDim2`,
`Color3`, and `ColorSequence`. For a design-space bake, `workspace.CurrentCamera=nil`
skips fitting and signals; for responsive verification use a table camera with
ViewportSize and a captured `GetPropertyChangedSignal(...):Connect(...)` callback.
Lune supplies no Studio camera/rendering engine. `Bind` also needs an offline
WaitForChild adapter for already-present fixtures; do not replace Studio semantics
in game sources. Lune's legacy `Font` assignment causes a serialization type error
(EnumItem where FontFace expects Font). The verifier asserts FredokaOne and assigns
its `Font.new("rbxasset://fonts/families/FredokaOne.json")` before serialization;
a baker must handle this explicitly and reject unmapped fonts.

Module `Build` creates only the spec base. Controller state (DisplayOrder, initial
panel visibility, enabled flags) must be deliberately preserved or reapplied.
Keep runtime-only RollToast/showcase animation bodies, Backdrop, AutoButton,
Takeover, blur, connections, player data and progression additions separate; running
the full client initialization offline is not a bake. A future baker should first
emit to an explicit temporary destination, assert six GUI names and new SpecHash
attributes, inspect preserved component subtrees, round-trip serialization, and
verify `Bind` plus component binders before requesting any real asset replacement.
