extends Node3D
## One flat, unlit corner mesh keeps the keyboard cursor legible on textured
## ground. Its small breathing motion stays within the selected tile.
const Overlay=preload("res://scripts/map_overlay.gd")
var clock=0.0

func build(parent: Node3D,point: Vector3):
 name="MapCursor";parent.add_child(self);position=point
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for sign_x in [-1,1]:
  for sign_y in [-1,1]:
   for stroke in [[Vector2(sign_x*.35,sign_y*.45),Vector2(.12,.03)],[Vector2(sign_x*.45,sign_y*.35),Vector2(.03,.12)]]:
    Overlay.rectangle(surface,stroke[0],stroke[1],.081,Color("243a4b"))
    Overlay.rectangle(surface,stroke[0],stroke[1]-Vector2.ONE*.012,.085,Color("fff6d6"))
 Overlay.finish(self,surface,"CursorBrackets")

func _process(delta):
 if not is_visible_in_tree():return
 clock+=delta
 var breath=1.0+sin(clock*5)*.025
 scale=Vector3(breath,1,breath)
