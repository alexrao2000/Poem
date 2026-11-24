extends SceneTree
## Convert the exported splash directly so the imported pixels stay exact.

func _initialize():
 var paths=OS.get_cmdline_user_args()
 if paths.size()!=2:
  push_error("Expected the exported splash PNG and destination WebP paths")
  quit(1)
  return
 var image=Image.load_from_file(paths[0])
 if image==null or image.is_empty():
  push_error("Unable to read the exported splash PNG")
  quit(1)
  return
 var result=image.save_webp(paths[1],false)
 if result!=OK:push_error("Unable to encode the exported splash: "+error_string(result))
 quit(result)
