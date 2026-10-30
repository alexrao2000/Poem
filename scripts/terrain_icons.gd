extends RefCounted
# Small original terrain emblems share the tactical map's symbols. The caller
# keeps movement, cover and healing text authoritative beside each illustration.

const ICONS={
 ".":preload("res://assets/ui/terrain/plain.svg"),
 "p":preload("res://assets/ui/terrain/path.svg"),
 "=":preload("res://assets/ui/terrain/bridge.svg"),
 "f":preload("res://assets/ui/terrain/forest.svg"),
 "h":preload("res://assets/ui/terrain/hill.svg"),
 "o":preload("res://assets/ui/terrain/stronghold.svg"),
 "+":preload("res://assets/ui/terrain/sanctuary.svg"),
 "#":preload("res://assets/ui/terrain/blocked.svg"),
 "~":preload("res://assets/ui/terrain/water.svg")
}
static func get_icon(symbol: String) -> Texture2D:
 return ICONS.get(symbol,ICONS["."])
