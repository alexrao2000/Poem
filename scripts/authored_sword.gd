extends Node3D
# Original Poem weapon fitted to the source rig's palm. Kept separate from the
# licensed mesh so equipment geometry and swept blade sockets stay identical.
func _init():
 var painter=preload("res://scripts/fighters.gd").new()
 var weapon=painter.EquipmentVisuals.build(painter,self,"sword","iron_sword")
 weapon.position=Vector3(0,0,-.08);weapon.rotation.y=PI
 var edge=painter.EquipmentVisuals.trail_edge("sword","iron_sword")
 for index in range(2):
  var marker=Marker3D.new();marker.name="TrailInner" if index==0 else "TrailTip"
  weapon.add_child(marker);marker.position=edge[index]
