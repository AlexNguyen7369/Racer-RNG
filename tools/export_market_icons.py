"""Export the shared original segment recipes as transparent SVG and PNG sources."""
import re
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'src/shared/MarketArtConfig.luau').read_text()
out = root / 'ui/icons/market'
out.mkdir(parents=True, exist_ok=True)
for name, body in re.findall(r'(\w+)\s*=\s*\{(.*?)\n\t\},', source, re.S):
    svg = ET.Element('svg', xmlns='http://www.w3.org/2000/svg', viewBox='0 0 100 100', width='256', height='256')
    for values in re.findall(r'\{([^{}]+)\}', body):
        cx, cy, w, h, rotation, radius, color = [v.strip() for v in values.split(',')]
        cx, cy, w, h, rotation, radius = map(float, (cx, cy, w, h, rotation, radius))
        ET.SubElement(svg, 'rect', x=str(cx-w/2), y=str(cy-h/2), width=str(w), height=str(h),
                      rx=str(min(w,h)*radius), fill='#'+color.strip('"'), transform=f'rotate({rotation} {cx} {cy})')
    ET.indent(svg)
    target = out / (name+'.svg')
    ET.ElementTree(svg).write(target, encoding='utf-8', xml_declaration=True)
    try:
        import cairosvg
        cairosvg.svg2png(url=str(target), write_to=str(out/(name+'.png')))
    except ImportError:
        pass
    print(name)
