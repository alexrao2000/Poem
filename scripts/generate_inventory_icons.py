#!/usr/bin/env python3
"""Generate original per-item SVG inventory icons from equipment look profiles.
SVG output uses only the standard library. --review additionally needs Pillow
and renders a source-art contact sheet, not a game capture.
"""
import argparse
import json
import math
import re
from pathlib import Path

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--project-root',type=Path,default=Path(__file__).resolve().parent.parent)
 parser.add_argument('--output',type=Path,help='Defaults to assets/ui/items under the project root.')
 parser.add_argument('--review',action='store_true',help='Also render PNG previews/contact sheet with Pillow; use a review output folder.')
 args=parser.parse_args()
 ROOT=args.project_root.resolve();OUT=args.output or ROOT/'assets/ui/items';OUT.mkdir(parents=True,exist_ok=True)
 items=json.loads((ROOT/'data/equipment.json').read_text());looks=json.loads((ROOT/'data/equipment_looks.json').read_text())
 assert all(re.fullmatch(r'[a-z0-9_]+',item['id']) and item['id'] in looks for item in items)
 assert all(looks[item['id']]['kind']==item['kind'] and item['kind'] in ['sword','lance','axe','bow','magic','staff'] for item in items)
 if args.review:
  try:
   from PIL import Image,ImageDraw,ImageFont
  except ImportError:parser.error('--review requires Pillow; omit it for dependency-free SVG generation')
 INK='#263744';LIGHT='#f4f1df';S=8
 class Vector:
  def __init__(self,angle=0):
   self.angle=angle*math.pi/180;self.svg=[];self.image=Image.new('RGBA',(48*S,48*S)) if args.review else None;self.draw=ImageDraw.Draw(self.image) if self.image is not None else None
  def point(self,p):
   x,y=p[0]-24,p[1]-24;c,s=math.cos(self.angle),math.sin(self.angle)
   return (24+x*c-y*s,24+x*s+y*c)
  def shape(self,points,fill,stroke=INK,width=1.4,closed=True):
   pts=[self.point(p) for p in points];coords=' '.join(f'{x:.3f},{y:.3f}' for x,y in pts)
   tag='polygon' if closed else 'polyline'
   self.svg.append(f'<{tag} points="{coords}" fill="{fill or "none"}" stroke="{stroke or "none"}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>')
   if self.draw is not None:
    pixel=[(round(x*S),round(y*S)) for x,y in pts]
    if fill:self.draw.polygon(pixel,fill=fill)
    if stroke:
     path=pixel+pixel[:1] if closed else pixel;w=max(1,round(width*S));self.draw.line(path,fill=stroke,width=w,joint='curve')
     for x,y in path:self.draw.ellipse((x-w/2,y-w/2,x+w/2,y+w/2),fill=stroke)
  def circle(self,c,r,fill,stroke=INK,width=1.2):
   x,y=self.point(c);self.svg.append(f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{r}" fill="{fill or "none"}" stroke="{stroke or "none"}" stroke-width="{width}"/>')
   if self.draw is not None:self.draw.ellipse(((x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S),fill=fill,outline=stroke,width=round(width*S))
  def rect(self,x,y,w,h,fill,stroke=INK,width=1.2):self.shape([(x,y),(x+w,y),(x+w,y+h),(x,y+h)],fill,stroke,width)
  def save(self,name):
   svg='<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">'+''.join(self.svg)+'</svg>\n'
   (OUT/(name+'.svg')).write_text(svg)
   if self.image is not None:self.image.resize((192,192),Image.Resampling.LANCZOS).save(OUT/(name+'.png'))
   return self.image
 
 def curve(a,b,c,d,n=28):
  return [tuple((1-t)**3*a[k]+3*(1-t)**2*t*b[k]+3*(1-t)*t*t*c[k]+t**3*d[k] for k in [0,1]) for t in [i/n for i in range(n+1)]]
 def glyph(item):
  p=looks[item['id']];kind=p['kind'];v=Vector(40 if kind in ['sword','lance','axe','staff'] else 0)
  steel='#'+p['steel'];grip='#'+p['grip'];accent='#'+p['accent']
  if kind=='sword':
   half=3.5*p['width'];v.shape([(24,3),(24-half,11),(24-half,29),(24+half,29),(24+half,11)],steel)
   v.shape([(24,5),(24,27)],None,LIGHT,.9,False);v.rect(21.8,30,4.4,11,grip)
   for y in [33,36,39]:v.shape([(22.5,y),(25.5,y)],None,accent,.75,False)
   v.shape([(21,42),(24,45),(27,42),(26,40),(22,40)],accent)
   if p['guard']=='swept':v.shape(curve((17,27),(29,24),(34,31),(25.5,39)),None,accent,2.2,False)
   elif p['guard']=='ring':v.circle((24,30),4.7,None,accent,2);v.shape([(18,28),(30,28)],None,accent,2,False)
   else:v.shape([(17,28),(18,26.5),(30,26.5),(31,29),(25,30),(23,30)],accent)
  elif kind=='lance':
   short=item['id']=='javelin';bottom=40 if short else 45;v.rect(22.8,13,2.4,bottom-13,grip)
   half=p['width']*62;v.shape([(24,2.5),(24-half,11),(23,16),(25,16),(24+half,11)],steel)
   v.shape([(24,4),(24,13)],None,LIGHT,.85,False)
   for y in [15,18,bottom-3]:v.rect(22,y,4,1.8,accent,width=.9)
   if p.get('lugs'):v.shape([(17,15),(18,12),(22,14),(26,14),(30,12),(31,15),(26,17),(22,17)],steel,width=1.1)
  elif kind=='axe':
   v.rect(22.6,9,2.8,34,grip);v.rect(21.5,32,5,8,grip)
   for y in [33,36,39]:v.shape([(22,y),(26,y)],None,accent,.9,False)
   if p['shape']=='hammer':
    v.shape([(12,5),(34,5),(37,8),(37,15),(34,18),(12,18),(10,15),(10,8)],steel)
    v.rect(21,5,6,13,accent);v.shape([(12,7),(19,7),(19,16),(12,16)],None,LIGHT,.8,False)
   else:
    wide=9*p['width'];sides=[1] if p['shape']=='hatchet' else [-1,1]
    for side in sides:
     v.shape([(24,8),(24+side*wide,4),(24+side*(wide+2),7),(24+side*(wide+3),20),(24+side*8,18),(24+side*4,13),(24,14)],steel)
     v.shape([(24+side*(wide+1),8),(24+side*(wide+2),18)],None,LIGHT,1,False)
    v.rect(21.8,8,4.4,8,accent)
   v.rect(22,42,4,2,accent)
  elif kind=='staff':
   v.rect(22.6,17,2.8,27,grip)
   for y in [24,38]:v.rect(21.7,y,4.6,2.4,accent,width=.9)
   v.shape([(19,20),(20,17),(28,17),(29,20),(26,22),(22,22)],steel)
   rings=int(p['rings']);radius=4.4+1.35*rings
   for i in range(rings):v.circle((24,11),radius-i*1.65,None,accent,1.1)
   v.circle((24,11),3.1,'#'+p['core'],INK,.9);v.circle((23,10),.85,LIGHT,None)
  elif kind=='bow':
   long=item['id']=='longbow';top=3 if long else 6;bottom=45 if long else 42
   if item['id']=='recurve':
    outer=curve((18,top),(12,top+5),(35,15),(34,24))+curve((34,24),(35,33),(12,bottom-5),(18,bottom))[1:]
   else:outer=curve((19,top),(38,13),(38,35),(19,bottom))
   v.shape([(19,top),(19,bottom)],None,'#d6d0b9',1.2,False)
   v.shape(outer,None,INK,5.6 if long else 4.6,False);v.shape(outer,None,grip,3.1 if long else 2.3,False)
   v.rect(30.5,20,5.5,8,accent,width=1)
   v.shape([(9,24),(36,24)],None,grip,1.7,False);v.shape([(36,21.7),(41,24),(36,26.3)],steel,width=.8)
   v.shape([(10,21),(14,24),(10,27)],None,accent,1.4,False)
  else:
   v.shape([(10,11),(33,7),(39,35),(16,42),(11,38)],'#e7ddc1')
   v.shape([(12,8),(34,4),(39,34),(16,40)],'#'+p['cover']);v.shape([(12,8),(16,40)],None,accent,2.5,False)
   v.shape([(18,12),(30,10),(34,30),(22,33)],None,accent,.8,True)
   if item['id']=='ember':v.shape([(26,13),(23,21),(26,20),(24,27),(30,25),(30,21)],'#'+p['ribbon'],None)
   elif item['id']=='gale':
    v.shape(curve((22,24),(20,14),(33,13),(31,21)),None,'#'+p['ribbon'],1.8,False);v.shape(curve((24,27),(33,27),(35,22),(28,21)),None,'#'+p['ribbon'],1.5,False)
   else:v.shape([(28,12),(22,23),(27,22),(25,30),(33,18),(28,19)],'#'+p['ribbon'],None)
   v.shape([(27,37),(29,44),(31,41),(34,43),(32,35)],'#'+p['ribbon'],INK,.8)
  return v.save(item['id'])
 images=[glyph(item) for item in items]
 if args.review:
  font=ImageFont.truetype(str(ROOT/'assets/fonts/CormorantGaramond.ttf'),21)
  small=ImageFont.load_default(size=13)
  sheet=Image.new('RGB',(6*230,4*182+74),'#ebe4d4');draw=ImageDraw.Draw(sheet)
  draw.text((22,12),'Poem · individual inventory icons',font=ImageFont.truetype(str(ROOT/'assets/fonts/CormorantGaramond.ttf'),30),fill=INK)
  draw.text((22,48),'Source-art review only. Large glyph plus 28 / 20 px on light and dark UI backgrounds; not an in-game capture.',font=small,fill=INK)
  for n,(item,img) in enumerate(zip(items,images)):
   x=(n%6)*230;y=(n//6)*182+74;draw.rounded_rectangle((x+6,y+4,x+224,y+177),radius=8,fill='#faf6ea')
   sheet.paste(img.resize((98,98),Image.Resampling.LANCZOS),(x+16,y+16),img.resize((98,98),Image.Resampling.LANCZOS))
   for xx,bg in [(x+140,'#f6eedc'),(x+182,'#263744')]:
    draw.rounded_rectangle((xx-5,y+45,xx+33,y+83),radius=4,fill=bg)
    mini=img.resize((28,28),Image.Resampling.LANCZOS);sheet.paste(mini,(xx,y+50),mini)
    draw.rounded_rectangle((xx-5,y+87,xx+33,y+116),radius=4,fill=bg)
    mini=img.resize((20,20),Image.Resampling.LANCZOS);sheet.paste(mini,(xx+4,y+92),mini)
   draw.text((x+13,y+124),item['name'],font=font,fill=INK)
   draw.text((x+13,y+151),item['id'],font=small,fill='#665a48')
  sheet.save(OUT/'contact-sheet.png')
 print(f"Generated {len(items)} original SVG inventory icons in {OUT}")

if __name__=='__main__':main()
