"""Measure sprite bounds and root pivots without changing generated artwork."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
image=Image.open(ROOT/'assets/art/ground-cover-v1.png').convert('RGBA')
cell=image.width//2
assert image.width==image.height and image.width%2==0
records=[]
for index,kind in enumerate(('grass','fern','reeds','flowers')):
    origin=((index%2)*cell,(index//2)*cell)
    alpha=image.getchannel('A').crop((*origin,origin[0]+cell,origin[1]+cell))
    bounds=alpha.point(lambda value:255 if value>114 else 0).getbbox()
    left,top,right,bottom=bounds
    assert min(left,top,cell-right,cell-bottom)>cell*.1
    # The last six opaque rows converge at the root; keep it on the ground.
    weight=0;moment=0
    for y in range(bottom-6,bottom):
        for x in range(left,right):
            value=alpha.getpixel((x,y))
            if value>114:weight+=value;moment+=x*value
    records.append(dict(kind=kind,cell=index,bounds=list(bounds),
        rect=[origin[0]+left-3,origin[1]+top-3,right-left+6,bottom-top+6],
        root=[round(origin[0]+moment/weight,3),origin[1]+bottom]))
(ROOT/'assets/art/ground-cover.json').write_text(json.dumps(dict(texture='res://assets/art/ground-cover-v1.png',size=list(image.size),plants=records),indent=2)+'\n')
print(records)
