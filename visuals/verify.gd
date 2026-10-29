## Self-contained smoke test for the exported starter project.

extends SceneTree
func _initialize():call_deferred("run")
func run():
	var preview=load("res://visuals/preview.tscn").instantiate();root.add_child(preview);await process_frame;await process_frame
	assert(preview.catalog.errors.is_empty() and preview.catalog.assets.size()==8)
	for mode in ["2d","3d"]:
		preview.set_mode(mode);await process_frame
		assert(preview.renderer.actors.size()==8)
		for actor in preview.renderer.actors.values():
			actor.player.play("act","east",true);actor.player.skip();assert(actor.player.complete)
		assert(preview.renderer.world_to_cell(preview.renderer.cell_to_world(Vector2i(6,3)))==Vector2i(6,3))
	preview.queue_free();await process_frame
	print("PASS: standalone package imports eight classes and runs both map renderers without campaign dependencies")
	quit()
