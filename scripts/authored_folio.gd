extends Node3D
var equipped=""
var hold: SkeletonModifier3D
var grip_rotations={}
var critical_prepared=false
var preparation_length=0.0
func _init():configure_equipment("magic","ember")
func configure_equipment(kind: String,item: String) -> String:
 if kind!="magic":return "The casting study requires a folio"
 var painter=preload("res://scripts/fighters.gd").new();item=painter.EquipmentVisuals.resolve(kind,item)
 if equipped!=item:
  for child in get_children():remove_child(child);child.free()
  var weapon=painter.EquipmentVisuals.build(painter,self,kind,item)
  # Desired wrist axes: palm faces up, fingers extend toward the opponent.
  # The original folio's printed face (-Z) faces up above the supporting palm.
  weapon.position=Vector3(-.035,.095,0);weapon.basis=Basis(Vector3(0,0,-1),Vector3(0,1,0),Vector3(1,0,0))
  equipped=item
 var anchor=get_parent() as BoneAttachment3D
 if anchor!=null and hold==null:
  var rig=anchor.get_parent() as Skeleton3D
  if rig==null:return "Folio needs its hand skeleton"
  var chest=rig.get_bone_global_rest(rig.find_bone("spine_03"));var shoulder=rig.get_bone_global_rest(rig.find_bone("upperarm_r")).origin
  var goal=Transform3D(Basis(Vector3(0,-1,0),Vector3(0,0,1),Vector3(-1,0,0)),Vector3(shoulder.x-.055,chest.origin.y-.22,.22))
  hold=preload("res://scripts/skeletal_hold.gd").new();hold.name="FolioSupport";rig.add_child(hold);hold.configure(rig,chest.affine_inverse()*goal)
 return ""
func configure_animations(player: AnimationPlayer) -> String:
 var anchor=get_parent() as BoneAttachment3D;var rig=anchor.get_parent() as Skeleton3D if anchor!=null else null
 var result=preload("res://scripts/authored_hand_pose.gd").configure(player,rig,.85,.8,grip_rotations)
 if result.error.is_empty():
  grip_rotations=result.rotations
  result.error=preload("res://scripts/spell_anticipation.gd").configure(player,rig)
  if result.error.is_empty():
   preparation_length=player.get_animation("CriticalSpellEnter").length
   result.error=preload("res://scripts/spell_finish.gd").configure(player,rig)
 return result.error

func additional_poses() -> Dictionary:
 return {"victory_flourish":{"clip":"SpellFinish","from":0.0,"to":.24},"critical_windup":{"clip":"CriticalSpellEnter","from":0.0,"to":preparation_length},"critical_strike":{"clip":"CriticalSpellRelease","from":0.0,"to":.2}}

func combat_pose(key: String):
 if key=="critical_windup":critical_prepared=true
 elif key!="strike":critical_prepared=false

func animation_pose(key: String) -> String:return "critical_strike" if key=="strike" and critical_prepared else key
