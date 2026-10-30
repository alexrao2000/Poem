extends Control
## Scope scene visibility/processing to a painted screen. Departure restores
## the exact previous state, including scenes that were already hidden.
var covered: Array=[]

func configure(host: Control,scene_nodes: Array):
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 host.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for node in scene_nodes:
  if not is_instance_valid(node):continue
  covered.append({"node":weakref(node),"visible":node.visible,"process_mode":node.process_mode})
  node.hide();node.process_mode=Node.PROCESS_MODE_DISABLED
 tree_exiting.connect(restore_scene);resized.connect(queue_redraw)

func restore_scene():
 for entry in covered:
  var node=entry.node.get_ref()
  if is_instance_valid(node):node.visible=entry.visible;node.process_mode=entry.process_mode
 covered.clear()
