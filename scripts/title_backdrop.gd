extends Control
## The original dawn painting fills the title without stretching. A tiny slow
## drift stays within overscan; the covered 3D scene is hidden until departure.
const ART=preload("res://assets/art/title-dawn-v1.png")
var elapsed=0.0
var covered: Array=[]

func configure(host: Control,scene_nodes: Array):
 name="TitleBackdrop";mouse_filter=Control.MOUSE_FILTER_IGNORE
 host.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for node in scene_nodes:
  if not is_instance_valid(node):continue
  covered.append({"node":weakref(node),"visible":node.visible,"process_mode":node.process_mode})
  node.hide();node.process_mode=Node.PROCESS_MODE_DISABLED
 tree_exiting.connect(restore_scene)
 resized.connect(queue_redraw)

static func framing(dimensions: Vector2,time: float) -> Rect2:
 var source=Vector2(ART.get_width(),ART.get_height())
 var scale_value=maxf(dimensions.x/source.x,dimensions.y/source.y)*1.03
 var extent=source*scale_value
 var drift=Vector2(sin(time*.07),cos(time*.05))*dimensions*.004
 return Rect2((dimensions-extent)*.5+drift,extent)

func restore_scene():
 for entry in covered:
  var node=entry.node.get_ref()
  if is_instance_valid(node):node.visible=entry.visible;node.process_mode=entry.process_mode
 covered.clear()

func _process(dt):
 if not is_visible_in_tree():return
 elapsed+=dt;queue_redraw()

func _draw():draw_texture_rect(ART,framing(size,elapsed),false)
