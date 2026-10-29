extends RefCounted
# Original vector silhouettes share one lookup across combat and equipment UI.
const TEXTURES={
 "sword":preload("res://assets/ui/weapons/sword.svg"),
 "lance":preload("res://assets/ui/weapons/lance.svg"),
 "axe":preload("res://assets/ui/weapons/axe.svg"),
 "bow":preload("res://assets/ui/weapons/bow.svg"),
 "magic":preload("res://assets/ui/weapons/magic.svg"),
 "staff":preload("res://assets/ui/weapons/staff.svg")
}
static func get_icon(kind: String) -> Texture2D:return TEXTURES.get(kind)
