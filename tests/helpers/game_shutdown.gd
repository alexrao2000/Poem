extends RefCounted
## The audio mixer releases playback resources on its own clock. Tests that
## press a button immediately before quitting must drain it before engine exit.
static func dispose(app: Node):
 if not is_instance_valid(app):return
 var tree=app.get_tree()
 app.score_director.stop()
 app.interface_audio.player.volume_db=-80
 for player in app.find_children("*","AudioStreamPlayer",true,false):player.stop()
 var deadline=Time.get_ticks_usec()+200000
 while Time.get_ticks_usec()<deadline:await tree.process_frame
 app.queue_free();await tree.process_frame
