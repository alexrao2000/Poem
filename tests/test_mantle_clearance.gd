extends SceneTree
func _initialize():call_deferred("run")
func run():
 var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json")).vanguard;spec.appearance="Identity"
 var models=load("res://scripts/combat_models.gd").new("");models.catalog={"characters":{"lyra":spec}};var game=load("res://scripts/rules.gd").new();var unit=game.roster[0].duplicate(true);unit.team="player"
 var stage=Node3D.new();root.add_child(stage);var actor=models.build(stage,unit,Vector3.ZERO);await process_frame;actor.set_process(false)
 var mantle=actor.model.get_node("Identity").mantle;var rig=actor.model.get_node("Rig/Armature/Skeleton3D");var body=rig.get_node("Female_Peasant_Body");var arrays=body.mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var triangles=[]
 for mesh in mantle.garment.find_children("*","MeshInstance3D",true,false):
  if mesh.get_active_material(0)!=mantle.surfaces[0]:continue
  var a=mesh.mesh.surface_get_arrays(0);var ix=a[Mesh.ARRAY_INDEX];var v=a[Mesh.ARRAY_VERTEX]
  if ix==null or ix.is_empty():ix=range(v.size())
  for i in range(0,ix.size(),3):
   var tri=[]
   for j in range(3):tri.append(mantle.garment.to_local(mesh.to_global(v[ix[i+j]])))
   triangles.append(tri)
 var count=0;var worst=0.0;var where=[]
 for key in ["idle","advance","windup","strike","recover","hit","evade","down","victory"]:
  for fraction in [0.0,.25,.5,.75,1.0]:
   var mapping=actor.poses[key];actor.player.stop();actor.player.play(mapping.clip,0);actor.player.seek(lerpf(mapping.from,mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
   var binds=[]
   for index in range(body.skin.get_bind_count()):binds.append(rig.get_bone_global_pose(rig.find_bone(body.skin.get_bind_name(index)))*body.skin.get_bind_pose(index))
   var influences=arrays[Mesh.ARRAY_BONES].size()/vertices.size()
   for index in range(vertices.size()):
    var p=Vector3.ZERO
    for j in range(influences):
     var at=index*influences+j;p+=(binds[arrays[Mesh.ARRAY_BONES][at]]*vertices[index])*arrays[Mesh.ARRAY_WEIGHTS][at]
    p=mantle.garment.to_local(rig.to_global(p))
    if absf(p.x)>.23 or p.y<.21 or p.y>.44 or p.z>0:continue
    var nearest=INF
    for tri in triangles:
     var a=Vector2(tri[0].x,tri[0].y);var b=Vector2(tri[1].x,tri[1].y);var c=Vector2(tri[2].x,tri[2].y);var point=Vector2(p.x,p.y)
     var area=(b-a).cross(c-a)
     if absf(area)<.00001:continue
     var w=Vector3((b-point).cross(c-point),(c-point).cross(a-point),(a-point).cross(b-point))/area
     if minf(w.x,minf(w.y,w.z))<-.00001:continue
     nearest=minf(nearest,Vector3(tri[0].z,tri[1].z,tri[2].z).dot(w))
    if is_inf(nearest):continue
    count+=1
    if nearest-p.z>worst:worst=nearest-p.z;where=[key,fraction,str(p),nearest]
 print("Mantle covered torso samples=",count," max penetration=",worst," case=",where)
 assert(count>10000 and worst<.002,"Covered source bodice stays behind the fitted mantle through combat and travel poses")
 print("PASS: ",count," actual skinned torso vertices projected against the fitted mantle across nine source poses; maximum protrusion ",worst," m")
 stage.queue_free();await process_frame;quit()
