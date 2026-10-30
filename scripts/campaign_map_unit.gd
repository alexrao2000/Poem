extends "res://visuals/unit_3d.gd"
# Campaign adapter keeps the portable sprite renderer free of campaign rules.
# Facing, animation and brief reaction offsets are presentation state; action
# resolution stays in Rules. Owned motion always returns to the original tile.

const TACTICAL_PIXEL_SIZE=1.0/48.0
static var contact_material: StandardMaterial3D
static var selected_mesh: ArrayMesh
static var selected_material: StandardMaterial3D
var unit_id=""
var commander_insignia: Sprite3D
var reaction_motion: Tween
var reaction_origin=Vector3.ZERO

func configure(source: RefCounted,unit: Dictionary,facing="south"):
 unit_id=unit.id;team=unit.team;spent=unit.acted
 hp_ratio=clampf(float(unit.hp)/maxf(1,unit.max_hp),0,1)
 var individual="recruit."+unit.id
 var enemy="enemy."+unit.job.to_lower()
 var chosen="unit."+unit.job.to_lower()
 if team=="player" and source.assets.has(individual):chosen=individual
 elif team=="enemy" and source.assets.has(enemy):chosen=enemy
 setup(source,chosen)
 sprite.pixel_size=TACTICAL_PIXEL_SIZE;sprite.no_depth_test=true;sprite.render_priority=2
 var shadow=PlaneMesh.new();shadow.size=Vector2(.58,.40);marker.mesh=shadow;marker.material_override=shadow_material()
 ring.mesh=selection_mesh();ring.material_override=selection_material();ring.position.y=.072
 ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 player.play("idle",facing);update_frame()
 if unit.get("boss",false) and team=="enemy":
  var insignia=Sprite3D.new();insignia.name="CommanderInsignia";insignia.texture=preload("res://assets/ui/commander.svg")
  insignia.billboard=BaseMaterial3D.BILLBOARD_ENABLED;insignia.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
  insignia.pixel_size=1.0/100;insignia.position=Vector3(.30,.93,0);insignia.no_depth_test=true;insignia.render_priority=3
  insignia.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(insignia)
  commander_insignia=insignia

static func selection_mesh() -> ArrayMesh:
 if selected_mesh!=null:return selected_mesh
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var overlay=preload("res://scripts/map_overlay.gd")
 for x in [-1,1]:
  for z in [-1,1]:
   for stroke in [[Vector2(x*.23,z*.33),Vector2(.11,.035)],[Vector2(x*.33,z*.23),Vector2(.035,.11)]]:
    overlay.rectangle(surface,stroke[0],stroke[1],0,Color("254365"))
    overlay.rectangle(surface,stroke[0],stroke[1]-Vector2.ONE*.012,.001,Color("75c4e9"))
 selected_mesh=surface.commit();return selected_mesh

static func selection_material() -> StandardMaterial3D:
 if selected_material!=null:return selected_material
 selected_material=StandardMaterial3D.new();selected_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 selected_material.vertex_color_use_as_albedo=true;selected_material.vertex_color_is_srgb=true
 selected_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 return selected_material

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
 if not is_visible_in_tree():return
 super._process(dt)
 spent_tick.hide()
 if spent:sprite.modulate=Color(.78,.78,.78,sprite.modulate.a)
 var breath=1.0+sin(clock*4)*.045
 ring.scale=Vector3(breath,1,breath)
 if team=="enemy" and not spent and not visual_id.begins_with("enemy."):sprite.modulate*=Color(1,.72,.68)

func update_frame():
 super.update_frame()
 if spent and catalog.has_method("spent_frame_texture"):
  sprite.texture=catalog.spent_frame_texture(visual_id,player.frame_index())
 else:sprite.texture=catalog.frame_texture(visual_id,player.frame_index())
 var density=player.asset.get("source_pixel_scale",0)
 if density>0:sprite.scale=Vector3(density,density,1)
 var frame=player.asset.frames[player.frame_index()]
 sprite.flip_h=player.facing=="west" and player.asset.get("right_facing_frames",[]).any(func(value):return int(value)==player.frame_index())
 sprite.offset=Vector2(frame.pivot_px[0]-frame.rect[2] if sprite.flip_h else -frame.pivot_px[0],frame.pivot_px[1]-frame.rect[3])

func face_step(step: Vector2i):
 player.play("move",Player.facing_for_step(step));update_frame()

func face_toward(point: Vector2i,origin: Vector2i):
 player.play("idle",Player.facing_for_step(point-origin));update_frame()

func settle_reaction():
 if reaction_motion and reaction_motion.is_valid():
  reaction_motion.kill();position=reaction_origin

func reaction_offset(offset: Vector3,outward: float,hold: float,returning: float) -> Tween:
 settle_reaction();reaction_origin=position
 reaction_motion=create_tween()
 reaction_motion.tween_property(self,"position",reaction_origin+offset,outward).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 reaction_motion.tween_interval(hold)
 reaction_motion.tween_property(self,"position",reaction_origin,returning).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 return reaction_motion

func evade_from(point: Vector2i,origin: Vector2i) -> Tween:
 var side=Vector2(origin-point).orthogonal().normalized()
 if side.is_zero_approx():side=Vector2.RIGHT
 return reaction_offset(Vector3(side.x,0,side.y)*.14,.08,.16,.12)

func recoil_from(point: Vector2i,origin: Vector2i,critical=false) -> Tween:
 var away=Vector2(origin-point).normalized()
 if away.is_zero_approx():away=Vector2.DOWN
 return reaction_offset(Vector3(away.x,0,away.y)*(.14 if critical else .08),.045,.055,.14)

func finish_move():
 settle_reaction()
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
 var bounds=Rect2(projected+corner,texture_size*pixel_scale)
 if is_instance_valid(commander_insignia) and commander_insignia.visible:
  bounds=bounds.merge(commander_screen_bounds(camera))
 return bounds

func commander_screen_bounds(camera: Camera3D) -> Rect2:
 if not is_instance_valid(commander_insignia) or not commander_insignia.is_visible_in_tree():return Rect2()
 var center=camera.unproject_position(commander_insignia.global_position)
 var density=center.distance_to(camera.unproject_position(commander_insignia.global_position+camera.global_basis.x))
 var extent=commander_insignia.texture.get_size()*commander_insignia.pixel_size*density
 return Rect2(center-extent*.5,extent)
