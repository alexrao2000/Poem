extends RefCounted
## The abbey keeps a candle for each name in the company book when it arrives.

const Architecture=preload("res://scripts/architecture.gd")
const Flame=preload("res://scripts/beacon_flame.gd")
const Hearth=preload("res://scripts/hearth_fire.gd")
const MAP_SITE=Vector3(10.40,-.15,-1.44)
const MAP_SCALE=.91
const ARENA_SCALE=1.48
const COLUMNS=5
const STONE=Color("827f71")
const CLOTH=Color("59516a")
const WAX=Color("e0c99b")
static var book: ArrayMesh

static func lamp_count(game) -> int:
 if not game.permadeath or not game.trials.flags.death_legacies:return 0
 var count=0
 for unit in game.roster:
  if unit.get("fallen",false) and int(game.trials.losses.get(unit.id,game.chapter))<game.chapter:count+=1
 return count

static func build(scenery,parent: Node3D,site: Vector3,size: float,count: int):
 if count==0:return
 var vigil=Node3D.new();vigil.name="AbbeyVigil";vigil.position=site;vigil.scale=Vector3.ONE*size
 parent.add_child(vigil)
 scenery.block(vigil,Vector3(0,.11,0),Vector3(1.79,.22,.83),scenery.detail_material(3)).name="VigilPlinth"
 for side in [-1,1]:
  scenery.block(vigil,Vector3(side*.62,.39,0),Vector3(.32,.40,.65),scenery.detail_material(3)).name="VigilPier"
 scenery.block(vigil,Vector3(0,.661,0),Vector3(1.81,.14,.86),STONE).name="VigilShelf"
 var runner=scenery.block(vigil,Vector3(-.405,.74,-.02),Vector3(.66,.025,.69),CLOTH)
 runner.name="VigilRunner";runner.rotation.y=.035
 scenery.block(vigil,Vector3(-.405,.603,.424),Vector3(.66,.26,.020),CLOTH).name="VigilRunnerFall"
 var pages=scenery.mesh(vigil,pages_mesh(),Vector3(-.41,.76,-.02),Vector3.ONE,Architecture.material())
 pages.name="CompanyBook";pages.rotation.y=.035
 var rows=ceili(float(count)/COLUMNS)
 for row in rows:
  var lamps=mini(COLUMNS,count-row*COLUMNS)
  var height=.731+row*.058
  var depth=.19-row*.18
  if row>0:
   scenery.block(vigil,Vector3(.35,(height+.731)*.5,depth),Vector3(.83,height-.731,.173),STONE.darkened(.10)).name="VigilTier"
  for column in lamps:
   var lamp=Node3D.new();lamp.name="Lamp%d"%(row*COLUMNS+column)
   lamp.position=Vector3(.35+(column-(lamps-1)*.5)*.158,height,depth)
   vigil.add_child(lamp)
   scenery.cylinder(lamp,Vector3(0,.015,0),.030,.063,Color("917255"),.056).name="CandleDish"
   var candle_height=.103+((row*3+column*7)%4)*.019
   scenery.cylinder(lamp,Vector3(0,.03+candle_height*.5,0),candle_height,.036,WAX,.030).name="CandleWax"
   scenery.cylinder(lamp,Vector3(0,.034+candle_height,0),.012,.008,Color("42362e")).name="CandleWick"
   var flame=Flame.new();flame.name="Flame";flame.position.y=.039+candle_height
   lamp.add_child(flame);flame.seek_phase(float(row*COLUMNS+column)*1.74)
   var glow=scenery.mesh(flame,Hearth.shape(),Vector3.ZERO,Vector3(.24,.28,.32),Hearth.paint())
   glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func transfer(source: Node3D,destination: Node3D):
 var original=source.get_node_or_null("AbbeyVigil")
 var next=destination.get_node_or_null("AbbeyVigil")
 if original==null or next==null:return
 for lamp in next.get_children():
  var flame=lamp.get_node_or_null("Flame")
  if flame!=null:flame.seek_phase(original.get_node("%s/Flame"%lamp.name).phase)

static func pages_mesh() -> ArrayMesh:
 if book!=null:return book
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 Architecture.quad(tool,[Vector3(-.285,.015,.205),Vector3(.285,.015,.205),
  Vector3(.285,.015,-.205),Vector3(-.285,.015,-.205)],Vector3.UP,Color("694839"))
 for side in [-1,1]:
  var normal=Vector3(-side*.15,1,0).normalized()
  var leaf=Color("d4bc8f").lightened(.055 if side>0 else 0.0)
  Architecture.quad(tool,[page_point(side,.012,.182),page_point(side,.265,.182),
   page_point(side,.265,-.185),page_point(side,.012,-.185)],normal,leaf)
  for line in 6:
   var z=-.113+line*.044
   var finish=.223-((line*7+side+1)%4)*.013
   Architecture.quad(tool,[page_point(side,.053,z,.002),page_point(side,finish,z,.002),
    page_point(side,finish,z-.009,.002),page_point(side,.053,z-.009,.002)],normal,Color("85725c"))
 book=tool.commit()
 return book

static func page_point(side: int,x: float,z: float,lift=0.0) -> Vector3:
 return Vector3(side*x,.025+x*.15+lift,z)
