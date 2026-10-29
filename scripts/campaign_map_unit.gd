extends "res://visuals/unit_3d.gd"
# Campaign adapter keeps the portable sprite renderer free of campaign rules.
# Facing and animation are presentation state; action resolution stays in Rules.
const TACTICAL_PIXEL_SIZE=1.0/48.0
static var contact_material: StandardMaterial3D
var unit_id=""

func configure(source: RefCounted,unit: Dictionary,facing="south"):
 unit_id=unit.id;team=unit.team;spent=unit.acted
 hp_ratio=clampf(float(unit.hp)/maxf(1,unit.max_hp),0,1)
 var individual="recruit."+unit.id
 setup(source,individual if team=="player" and source.assets.has(individual) else "unit."+unit.job.to_lower())
 sprite.pixel_size=TACTICAL_PIXEL_SIZE;sprite.no_depth_test=true;sprite.render_priority=2
 var shadow=PlaneMesh.new();shadow.size=Vector2(.58,.40);marker.mesh=shadow;marker.material_override=shadow_material()
 marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 player.play("idle",facing);update_frame()

static func shadow_material() -> StandardMaterial3D:
 if contact_material==null:
  var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.35,1])
  gradient.colors=PackedColorArray([Color(0,0,0,.34),Color(0,0,0,.24),Color(0,0,0,0)])
  var texture=GradientTexture2D.new();texture.width=64;texture.height=64;texture.gradient=gradient
  texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
  contact_material=StandardMaterial3D.new();contact_material.albedo_texture=texture
  contact_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  contact_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return contact_material

func refresh_health():
 var image=Image.create(24,4,false,Image.FORMAT_RGBA8)
 image.fill(Color("6fb6d3") if team=="player" else Color("d77870"))
 image.fill_rect(Rect2i(1,1,22,2),Color("172b30"))
 var fill=Color("acd86b") if hp_ratio>.5 else Color("f2c45e") if hp_ratio>.25 else Color("e87c63")
 image.fill_rect(Rect2i(1,1,maxi(0,roundi(22*clampf(hp_ratio,0,1))),2),fill)
 health.texture=ImageTexture.create_from_image(image);health.visible=true

func _process(dt):
 super._process(dt)
 if team=="enemy":sprite.modulate*=Color(1,.72,.68)

func update_frame():
 super.update_frame()
 var density=player.asset.get("source_pixel_scale",0)
 if density>0:sprite.scale=Vector3(density,density,1)
 var frame=player.asset.frames[player.frame_index()]
 sprite.flip_h=player.facing=="west" and player.asset.get("right_facing_frames",[]).any(func(value):return int(value)==player.frame_index())
 sprite.offset=Vector2(frame.pivot_px[0]-frame.rect[2] if sprite.flip_h else -frame.pivot_px[0],frame.pivot_px[1]-frame.rect[3])

func face_step(step: Vector2i):
 player.play("move",Player.facing_for_step(step));update_frame()

func finish_move():
 player.play("idle");update_frame()

func act_toward(point: Vector2i,origin: Vector2i):
 player.play("act",Player.facing_for_step(point-origin),true);update_frame()

func react(hit: bool,remaining: int):
 if hit:player.play("defeated" if remaining<=0 else "hurt","",true)
 update_frame()

func screen_bounds(camera: Camera3D) -> Rect2:
 var foot=global_position+sprite.position
 var projected=camera.unproject_position(foot)
 var density=projected.distance_to(camera.unproject_position(foot+camera.global_transform.basis.x))
 var pixel_scale=Vector2(sprite.scale.x,sprite.scale.y)*sprite.pixel_size*density
 var texture_size=sprite.texture.get_size()
 var corner=Vector2(sprite.offset.x,-texture_size.y-sprite.offset.y)*pixel_scale
 return Rect2(projected+corner,texture_size*pixel_scale)
