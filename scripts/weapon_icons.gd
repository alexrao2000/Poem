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

const ITEM_TEXTURES={
 "iron_sword":preload("res://assets/ui/items/iron_sword.svg"),
 "dueling_sword":preload("res://assets/ui/items/dueling_sword.svg"),
 "tempered_sword":preload("res://assets/ui/items/tempered_sword.svg"),
 "iron_lance":preload("res://assets/ui/items/iron_lance.svg"),
 "light_lance":preload("res://assets/ui/items/light_lance.svg"),
 "pike":preload("res://assets/ui/items/pike.svg"),
 "javelin":preload("res://assets/ui/items/javelin.svg"),
 "iron_axe":preload("res://assets/ui/items/iron_axe.svg"),
 "hatchet":preload("res://assets/ui/items/hatchet.svg"),
 "great_axe":preload("res://assets/ui/items/great_axe.svg"),
 "scout_bow":preload("res://assets/ui/items/scout_bow.svg"),
 "recurve":preload("res://assets/ui/items/recurve.svg"),
 "longbow":preload("res://assets/ui/items/longbow.svg"),
 "ember":preload("res://assets/ui/items/ember.svg"),
 "gale":preload("res://assets/ui/items/gale.svg"),
 "thunder":preload("res://assets/ui/items/thunder.svg"),
 "field_staff":preload("res://assets/ui/items/field_staff.svg"),
 "mend_staff":preload("res://assets/ui/items/mend_staff.svg"),
 "beacon_staff":preload("res://assets/ui/items/beacon_staff.svg"),
 "estoc":preload("res://assets/ui/items/estoc.svg"),
 "riders_bane":preload("res://assets/ui/items/riders_bane.svg"),
 "war_hammer":preload("res://assets/ui/items/war_hammer.svg"),
 "rally_lance":preload("res://assets/ui/items/rally_lance.svg"),
 "vigil_staff":preload("res://assets/ui/items/vigil_staff.svg")
}
static func get_icon(kind: String) -> Texture2D:return TEXTURES.get(kind)
static func get_item_icon(item_id: String,kind: String="") -> Texture2D:return ITEM_TEXTURES.get(item_id,get_icon(kind))
