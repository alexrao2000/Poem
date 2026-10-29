extends Node3D
const Player = preload("res://visuals/sprite_player.gd")
var player = Player.new()
var catalog: RefCounted
var visual_id = ""
var team = "player"
var hp_ratio = 1.0
var spent = false
var selected = false
var flying = false
var last_frame = -1
var sprite: Sprite3D
var marker: MeshInstance3D
var ring: MeshInstance3D
var health: Sprite3D
var spent_tick: Node3D
var clock = 0.0

func setup(value: RefCounted, id: String):
	catalog = value; visual_id = id; player.configure(catalog.assets[id])
	sprite = Sprite3D.new();sprite.centered=false;sprite.pixel_size=1.0/32.0
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.4
	sprite.shaded=false;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	marker=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.27;mesh.bottom_radius=.27;mesh.height=.015;mesh.radial_segments=team_sides()
	marker.mesh=mesh;marker.position.y=.03;add_child(marker)
	var material=StandardMaterial3D.new();material.albedo_color=Color("7bbbd0") if team=="player" else Color("e88577");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;marker.material_override=material
	ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.31;torus.outer_radius=.35;ring.mesh=torus;ring.position.y=.04;add_child(ring)
	var gold=StandardMaterial3D.new();gold.albedo_color=Color("f2d889");gold.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=gold
	health=Sprite3D.new();health.billboard=BaseMaterial3D.BILLBOARD_ENABLED;health.pixel_size=1.0/32;health.position.y=.10;health.position.z=.24;health.no_depth_test=true;add_child(health)
	spent_tick=Node3D.new();add_child(spent_tick)
	for entry in [[Vector3(-.055,.055,.025),Vector3(.05,.02,.14),-.7],[Vector3(.045,.055,-.015),Vector3(.05,.02,.24),.7]]:
		var bar=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=entry[1];bar.mesh=shape;bar.position=entry[0];bar.rotation.y=entry[2];bar.material_override=gold;spent_tick.add_child(bar)
	update_frame();refresh_health()

func team_sides() -> int:
	return 4 if team=="player" else 3

func refresh_health():
	var image=Image.create(24,3,false,Image.FORMAT_RGBA8);image.fill(Color("172b30"))
	image.fill_rect(Rect2i(1,1,maxi(0,roundi(22*hp_ratio)),1),Color("7bbbd0") if team=="player" else Color("e88577"))
	health.texture=ImageTexture.create_from_image(image);health.visible=hp_ratio<.999

func update_frame():
	var frame=player.frame_index()
	if frame==last_frame:return
	last_frame=frame;sprite.texture=catalog.frame_texture(visual_id,frame)
	var definition=player.asset.frames[frame]
	var scale_value=Vector2(player.asset.logical_frame_px[0]/float(definition.rect[2]),player.asset.logical_frame_px[1]/float(definition.rect[3]))
	sprite.scale=Vector3(scale_value.x,scale_value.y,1)
	sprite.offset=Vector2(-definition.pivot_px[0],definition.pivot_px[1]-definition.rect[3])

func _process(dt):
	clock+=dt;player.advance(dt);update_frame()
	sprite.modulate=Color(.70,.72,.73) if spent else Color.WHITE
	sprite.modulate.a=.25 if player.state=="defeated" and player.complete else 1.0
	sprite.position.y=.05+(0.3+sin(clock*4)*.06 if flying else 0.0)
	ring.visible=selected
	spent_tick.visible=spent
