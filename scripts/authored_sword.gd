extends Node3D
# Original Poem weapon fitted to the source rig's palm. Kept separate from the
# licensed mesh so equipment geometry and swept blade sockets stay identical.
var equipped=""
func _init():configure_equipment("sword","iron_sword")

func configure_equipment(kind: String,item: String) -> String:
 if kind!="sword":return "The duelist rig requires a sword"
 var painter=preload("res://scripts/fighters.gd").new()
 item=painter.EquipmentVisuals.resolve(kind,item)
 if equipped==item:return ""
 for child in get_children():remove_child(child);child.free()
 var weapon=painter.EquipmentVisuals.build(painter,self,kind,item)
 weapon.position=Vector3(0,0,-.08);weapon.rotation.y=PI
 var edge=painter.EquipmentVisuals.trail_edge(kind,item)
 for index in range(2):
  var marker=Marker3D.new();marker.name="TrailInner" if index==0 else "TrailTip"
  weapon.add_child(marker);marker.position=edge[index]
 equipped=item
 return ""
