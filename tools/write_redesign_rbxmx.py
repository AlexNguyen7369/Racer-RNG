"""Write assets/studio/RedesignCarModels/<model>.rbxmx from uploaded meshes (docs/CAR_REDESIGN_SPEC.md).

    python3 tools/write_redesign_rbxmx.py go_kart [more ids...]

Mesh data per car comes from assets/meshes/cars/meshes.json ({id: {part: {MeshId, Size, Pos}}}), dumped from Studio
after InsertService:LoadAsset(ids.json[id]); colours and materials come from drafts/cars/<id>/redesign/parts.json.
Textured special-case rides (CAR_REDESIGN_SPEC section 9) also carry ColorMap / NormalMap per part, written as a
SurfaceAppearance, and parts.json wing_hinge (Blender coords) becomes each wing's PivotOffset (the flap hinge).
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/studio/RedesignCarModels'
MATERIAL = {'SmoothPlastic': 272, 'Neon': 288, 'Metal': 1088, 'Glass': 1568}
BOX_FIDELITY = 1


def write(car_id, meshes):
    report = json.loads((ROOT / 'drafts/cars' / car_id / 'redesign/parts.json').read_text())
    parts = report['materials']
    # Blender (x, y, z) lands in Roblox at (x, z, -y) (export turn + importer axes, tools/build_redesign_cars.py).
    hinges = {name: (h[0], h[2], -h[1]) for name, h in report.get('wing_hinge', {}).items()}
    assert set(parts) == set(meshes), (car_id, sorted(parts), sorted(meshes))
    doc = ET.Element('roblox', version='4')
    model = ET.SubElement(doc, 'Item', {'class': 'Model', 'referent': 'RBXMODEL'})
    props = ET.SubElement(model, 'Properties')
    ET.SubElement(props, 'string', name='Name').text = car_id

    def vec(parent, tag, name, values, axes='XYZ'):
        e = ET.SubElement(parent, tag, name=name)
        for axis, v in zip(axes, values):
            ET.SubElement(e, axis).text = repr(float(v))
        return e

    for i, name in enumerate(sorted(meshes)):
        mesh, look = meshes[name], parts[name]
        item = ET.SubElement(model, 'Item', {'class': 'MeshPart', 'referent': f'RBX{i}'})
        pr = ET.SubElement(item, 'Properties')
        ET.SubElement(pr, 'string', name='Name').text = name
        for prop, value in [('Anchored', True), ('CanCollide', False), ('CanTouch', False), ('CanQuery', False),
                            ('Massless', True), ('CastShadow', True)]:
            ET.SubElement(pr, 'bool', name=prop).text = str(value).lower()
        ET.SubElement(ET.SubElement(pr, 'Content', name='MeshId'), 'url').text = mesh['MeshId']
        vec(pr, 'Vector3', 'InitialSize', mesh['Size'])
        vec(pr, 'Vector3', 'size', mesh['Size'])
        cf = vec(pr, 'CoordinateFrame', 'CFrame', mesh['Pos'])
        for a in range(3):
            for b in range(3):
                ET.SubElement(cf, f'R{a}{b}').text = str(int(a == b))
        vec(pr, 'Color3', 'Color', look['color'], 'RGB')
        ET.SubElement(pr, 'token', name='Material').text = str(MATERIAL[look['material']])
        ET.SubElement(pr, 'token', name='CollisionFidelity').text = str(BOX_FIDELITY)
        if name in hinges:
            pivot = vec(pr, 'CoordinateFrame', 'PivotOffset', [h - p for h, p in zip(hinges[name], mesh['Pos'])])
            for a in range(3):
                for b in range(3):
                    ET.SubElement(pivot, f'R{a}{b}').text = str(int(a == b))
        if mesh.get('ColorMap'):
            sa = ET.SubElement(item, 'Item', {'class': 'SurfaceAppearance', 'referent': f'RBX{i}SA'})
            sp = ET.SubElement(sa, 'Properties')
            ET.SubElement(sp, 'string', name='Name').text = 'SurfaceAppearance'
            for prop in ('ColorMap', 'NormalMap'):
                if mesh.get(prop):
                    ET.SubElement(ET.SubElement(sp, 'Content', name=prop), 'url').text = mesh[prop]
    # Base-centred pivot, forward -Z (same contract as ExpansionCarModels).
    pivot = ET.SubElement(ET.SubElement(props, 'OptionalCoordinateFrame', name='WorldPivotData'), 'CFrame')
    for axis in 'XYZ':
        ET.SubElement(pivot, axis).text = '0'
    for a in range(3):
        for b in range(3):
            ET.SubElement(pivot, f'R{a}{b}').text = str(int(a == b))
    ET.indent(doc)
    OUT.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(doc).write(OUT / (car_id + '.rbxmx'), encoding='utf-8', xml_declaration=True)
    print(car_id, len(meshes), 'parts')


if __name__ == '__main__':
    data = json.loads((ROOT / 'assets/meshes/cars/meshes.json').read_text())
    for car_id in sys.argv[1:]:
        write(car_id, data[car_id])
