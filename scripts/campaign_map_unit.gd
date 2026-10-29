extends "res://visuals/unit_3d.gd"
# Campaign adapter keeps the portable sprite renderer free of campaign rules.
# Facing and animation are presentation state; action resolution stays in Rules.
const TACTICAL_PIXEL_SIZE=1.0/48.0
var unit_id=""

func configure(source: RefCounted,unit: Dictionary,facing="south"):
 unit_id=unit.id;team=unit.team;spent=unit.acted
 hp_ratio=clampf(float(unit.hp)/maxf(1,unit.max_hp),0,1)
 var individual="recruit."+unit.id
 setup(source,individual if team=="player" and source.assets.has(individual) else "unit."+unit.job.to_lower())
 sprite.pixel_size=TACTICAL_PIXEL_SIZE;sprite.no_depth_test=true;sprite.render_priority=2
 player.play("idle",facing);update_frame()

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
