extends "res://scripts/combat_projectile.gd"
## Tactical flights share the combat geometry at sprite scale. Their overlay
## depth follows map figures, so terrain cannot hide a legal ranged action.
## Miss follow-through fits inside the same pre-contact presentation interval.
const FLIGHT_TIME=.12
const SPRITE_SCALE=.55

func fly(from: Vector3,to: Vector3,weapon: String,spell_id="",appearance={},miss=false) -> Tween:
 var flight=launch(from,to,weapon,FLIGHT_TIME,spell_id,appearance,miss,null,SPRITE_SCALE)
 name="MapProjectile";flight.set_speed_scale(travel_end)
 for mesh in find_children("*","MeshInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var surface=mesh.material_override
  surface.no_depth_test=true;surface.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
  surface.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;surface.render_priority=3
 return flight
