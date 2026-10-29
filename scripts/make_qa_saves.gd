extends SceneTree
# Local QA fixtures only. Not bundled with exported builds.
const Rules=preload("res://scripts/rules.gd")
func write_code(name_value,game,stage):
 var file=FileAccess.open("res://build/qa-saves/"+name_value+".txt",FileAccess.WRITE)
 file.store_string(game.export_code(stage));file.close()
func _initialize():
 DirAccess.make_dir_recursive_absolute("res://build/qa-saves")
 for chapter in range(12):
  var g=Rules.new();g.chapter=chapter;g.story_seen=["opening_"+str(chapter)]
  var available=g.available();available.sort_custom(func(a,b):return a.level>b.level)
  g.deployed=[]
  for unit in available:
   if unit.weapon=="staff":g.deployed.append(unit.id);break
  for unit in available:
   if unit.weapon!="staff" and g.deployed.size()<6:g.deployed.append(unit.id)
  write_code("chapter-%02d-camp"%(chapter+1),g,"camp")
 var g=Rules.new();g.start_battle();g.story_seen=["opening_0"]
 var a=g.units[0];var b=g.living("enemy")[1]
 a.x=6;a.y=3;a.xp=90;b.x=6;b.y=4;b.hp=1
 write_code("level-up",g,"battle")
 for enemy in g.living("enemy"):enemy.hp=0
 write_code("chapter-result",g,"battle")
 print("PASS: 12 preparation codes and 2 progression checkpoints in build/qa-saves")
 quit()
