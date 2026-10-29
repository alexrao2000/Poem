extends SceneTree
# Read alpha bounds to generate atlas metadata. Source pixels are never modified.
const ORDER=preload("res://scripts/portraits.gd").ORDER
func _initialize():
 var sheets=[];var result={}
 for letter in ["a","b","c"]:
  var image=Image.load_from_file("res://assets/sprites/company-"+letter+".png")
  assert(image!=null and image.get_width()==1536 and image.get_height()==1024)
  assert(image.get_pixel(0,0).a<.01,"Sprite atlas has actual transparency")
  sheets.append(image)
 for index in range(24):
  var local=index%8
  var area=Rect2i((local%4)*384,(local/4)*512,384,512)
  if index==4:area=Rect2i(0,512,420,512)
  elif index==5:area=Rect2i(420,512,348,512)
  elif index==6:area=Rect2i(768,512,342,512)
  elif index==7:area=Rect2i(1110,512,426,512)
  elif index==22:area=Rect2i(768,512,410,512)
  elif index==23:area=Rect2i(1178,512,358,512)
  var minimum=area.end;var maximum=area.position
  for y in range(area.position.y,area.end.y):
   for x in range(area.position.x,area.end.x):
    if sheets[index/8].get_pixel(x,y).a>=.35:
     minimum.x=mini(minimum.x,x);minimum.y=mini(minimum.y,y)
     maximum.x=maxi(maximum.x,x);maximum.y=maxi(maximum.y,y)
  minimum=(minimum-Vector2i(4,4)).max(area.position)
  maximum=(maximum+Vector2i(5,5)).min(area.end)
  var size=maximum-minimum
  assert(size.x>80 and size.y>150,"Usable full-body sprite region")
  result[ORDER[index]]={"sheet":"company-"+["a","b","c"][index/8],"region":[minimum.x,minimum.y,size.x,size.y]}
  print(ORDER[index],": ",result[ORDER[index]].region)
 var file=FileAccess.open("res://data/sprite_regions.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"\t"));file.close()
 print("PASS: indexed 24 original sprites without modifying raster pixels")
 quit()
