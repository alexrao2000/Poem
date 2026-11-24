extends SceneTree
## Match the stock Web splash by encoding the imported texture losslessly.

func _initialize():
 var paths=OS.get_cmdline_user_args()
 if paths.size()!=2:
  push_error("Expected the imported texture and destination WebP paths")
  quit(1)
  return
 var texture=load(paths[0]) as Texture2D
 var image=texture.get_image() if texture!=null else null
 if image==null or image.is_empty():
  push_error("Unable to read the imported splash texture")
  quit(1)
  return
 if image.is_compressed() and image.decompress()!=OK:
  push_error("Unable to decompress the imported splash texture")
  quit(1)
  return
 image.clear_mipmaps()
 var result=image.save_webp(paths[1],false)
 if result!=OK:push_error("Unable to encode the Web splash: "+error_string(result))
 quit(result)
