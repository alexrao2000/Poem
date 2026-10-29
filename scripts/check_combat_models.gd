extends SceneTree
const Models=preload("res://scripts/combat_models.gd")
func _initialize():call_deferred("run")
func run():
 var models=Models.new();var stage=Node3D.new();root.add_child(stage)
 var count=0
 for category in ["characters","promotions","classes","enemy_classes"]:
  var entries=models.catalog.get(category,{})
  if not entries is Dictionary:models.report(category+" must be an object");continue
  for key in entries:
   var one=Models.new("");one.catalog={"characters":{"check":entries[key]}}
   var actor=one.build(stage,{"id":"check","job":"Vanguard","weapon":"sword","team":"player"},Vector3.ZERO)
   if actor==null:
    for issue in one.issues:models.report(category+"/"+str(key)+": "+issue)
   else:count+=1;actor.queue_free()
 await process_frame;stage.queue_free();await process_frame
 if not models.issues.is_empty():
  for issue in models.issues:printerr(issue)
  quit(1);return
 print("PASS: %d authored model entries validated (%s)"%[count,"procedural fallback only" if count==0 else "visual review still required"])
 quit()
