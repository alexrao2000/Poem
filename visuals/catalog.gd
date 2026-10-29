## Engine adapter for the portable JSON asset contract. No campaign dependency.

extends RefCounted
var assets: Dictionary = {}
var textures: Dictionary = {}
var frame_textures: Dictionary = {}
var errors: Array[String] = []
var base_path = ""

func open(path: String) -> bool:
	assets.clear(); textures.clear(); frame_textures.clear(); errors.clear()
	base_path = path.get_base_dir()
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open visual catalog: " + path); return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		errors.append("Invalid catalog JSON: " + path); return false
	var data: Dictionary = parser.data
	if data.get("schema_version") != 1 or not data.get("assets") is Array:
		errors.append("Unsupported visual catalog schema: " + path); return false
	for item in data.assets:
		if not item is Dictionary:
			errors.append("Visual entry must be an object"); continue
		var id = str(item.get("id", ""))
		if id.is_empty() or assets.has(id):
			errors.append("Empty or duplicate visual ID: " + id); continue
		var previous = errors.size()
		validate_asset(item)
		if errors.size() == previous: assets[id] = item
	for id in assets:
		var fallback = assets[id].get("fallback_visual_id")
		if fallback != null and not assets.has(fallback): errors.append(id + ": unknown fallback " + str(fallback))
	return errors.is_empty() and not assets.is_empty()

func fail(id: String, message: String):
	errors.append(id + ": " + message)

func pair(value, positive = false) -> bool:
	return value is Array and value.size() == 2 and value.all(func(n): return (n is int or n is float) and is_finite(float(n)) and (not positive or n > 0))

func validate_asset(item: Dictionary):
	var id = str(item.id)
	var texture_path = str(item.get("texture", ""))
	if texture_path.is_empty() or texture_path.is_absolute_path() or ".." in texture_path.split("/"):
		fail(id, "texture must be a safe relative path"); return
	var path = base_path.path_join(texture_path)
	if not ResourceLoader.exists(path): fail(id, "missing texture " + path); return
	var texture = load(path) as Texture2D
	if texture == null: fail(id, "cannot load texture"); return
	if not pair(item.get("logical_frame_px"), true): fail(id, "invalid logical frame size"); return
	if not item.get("frames") is Array or item.frames.is_empty(): fail(id, "missing frames"); return
	for frame in item.frames:
		if not frame is Dictionary or not frame.get("rect") is Array or frame.rect.size() != 4 or not pair(frame.get("pivot_px")):
			fail(id, "frame requires rect and pivot_px"); return
		var r = frame.rect
		if not r.all(func(n): return (n is int or n is float) and is_finite(float(n)) and n == int(n)):
			fail(id, "frame rectangle must use integer pixels"); return
		if r[0] < 0 or r[1] < 0 or r[2] <= 0 or r[3] <= 0 or r[0]+r[2] > texture.get_width() or r[1]+r[3] > texture.get_height():
			fail(id, "frame rectangle outside texture"); return
		if frame.pivot_px[0] < 0 or frame.pivot_px[0] > r[2] or frame.pivot_px[1] < 0 or frame.pivot_px[1] > r[3]:
			fail(id, "pivot outside frame"); return
	if not item.get("clips") is Dictionary: fail(id, "missing clips"); return
	for state in ["idle", "move", "act", "hurt", "defeated"]:
		if not item.clips.get(state) is Dictionary: fail(id, "missing clip " + state); continue
		for facing in ["south", "west", "east", "north"]:
			var clip = item.clips[state].get(facing)
			if not clip is Dictionary or not clip.get("frames") is Array or not clip.get("duration_ms") is Array:
				fail(id, "missing " + state + "/" + facing); continue
			if clip.frames.is_empty() or clip.frames.size() != clip.duration_ms.size() or not clip.get("loop") is bool or not clip.get("cues") is Array:
				fail(id, "invalid timing or loop for " + state + "/" + facing); continue
			for index in clip.frames:
				if not (index is int or index is float) or index != int(index) or index < 0 or index >= item.frames.size(): fail(id, "invalid frame index")
			for duration in clip.duration_ms:
				if not (duration is int or duration is float) or not is_finite(float(duration)) or duration <= 0: fail(id, "duration must be positive")
			for cue in clip.cues:
				if not cue is Dictionary or not cue.get("name") is String or not (cue.get("frame_index") is int or cue.get("frame_index") is float):
					fail(id, "invalid visual cue"); continue
				if cue.frame_index != int(cue.frame_index) or cue.frame_index < 0 or cue.frame_index >= clip.frames.size(): fail(id, "cue outside clip")
	textures[id] = texture

func resolve(id: String, fallback = "") -> Dictionary:
	return assets.get(id, assets.get(fallback, {}))

func frame_texture(id: String, index: int) -> AtlasTexture:
	var asset: Dictionary = assets.get(id, {})
	if asset.is_empty() or index < 0 or index >= asset.frames.size(): return null
	var key=id+":"+str(index)
	if frame_textures.has(key):return frame_textures[key]
	var rect = asset.frames[index].rect
	var atlas = AtlasTexture.new()
	atlas.atlas = textures[id]
	atlas.region = Rect2(rect[0], rect[1], rect[2], rect[3])
	atlas.filter_clip = true
	frame_textures[key]=atlas
	return atlas
