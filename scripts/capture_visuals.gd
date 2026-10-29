## Native renderer capture harness. Explicit frame drawing also works while the window is covered.

extends SceneTree
func _initialize():call_deferred("run")
func run():
	print("Capture: loading workshop")
	var lab=load("res://visual_lab.tscn").instantiate();root.add_child(lab)
	print("Capture: workshop ready")
	await create_timer(.8).timeout
	var mode="3d" if "--visual-3d" in OS.get_cmdline_user_args() else "2d"
	lab.set_mode(mode);lab.performance.hide();await create_timer(.5).timeout
	print("Capture: renderer ready ",mode)
	RenderingServer.force_draw(false)
	var output="res://build/visual-"+mode+("-small" if "--capture-small" in OS.get_cmdline_user_args() else "")+".png"
	root.get_texture().get_image().save_png(output)
	print("PASS: saved native ",mode," capture to ",output)
	quit()
