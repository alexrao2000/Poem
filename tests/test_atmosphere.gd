extends SceneTree
const CloudSky=preload("res://scripts/cloud_sky.gd")
const Drift=preload("res://scripts/ambient_drift.gd")
const Rules=preload("res://scripts/rules.gd")
const Scenery=preload("res://scripts/scenery.gd")
const ChimneySmoke=preload("res://scripts/chimney_smoke.gd")

func _initialize():call_deferred("run")

func run():
 verify_clouds()
 verify_star_cover()
 var game=Rules.new();var rng=game.rng.state;var saved=game.save_data("camp").duplicate(true)
 var host=Node3D.new();root.add_child(host)
 var source_meshes={};var materials={}
 for theme in Drift.THEMES:
  for arena in [false,true]:
   var a=Drift.new();host.add_child(a);a.configure(theme,Vector3(24,4,18),arena,17);a.set_process(false)
   var b=Drift.new();host.add_child(b);b.configure(theme,Vector3(24,4,18),arena,17);b.set_process(false)
   assert(a.states==b.states,"Chapter atmosphere has a reproducible local seed")
   var mesh=a.cloud.multimesh.mesh;var paint=a.cloud.material_override
   source_meshes[mesh]=true;materials[paint]=true
   assert(mesh==b.cloud.multimesh.mesh and paint==b.cloud.material_override and a.cloud.multimesh!=b.cloud.multimesh,
    "Every repeated atmosphere shares immutable appearance and owns its own instances")
   assert(a.get_child_count()==(2 if theme=="forest" else 1) and a.cloud.multimesh.instance_count<=(84 if theme=="forest" else 32),
    "One batch covers the air, with one more batch for Greywood's ground rings")
   assert(a.cloud.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and a.find_children("*","Light3D",true,false).is_empty(),"Atmosphere adds no lights or shadows")
   assert(a.cloud.material_override.disable_fog,"Fog cannot reveal fully faded particle quads")
   if a.kind!="leaves":assert(a.cloud.material_override.billboard_keep_scale,"Camera-facing particles retain their small instance scales")
   if theme=="forest":
    assert(a.kind=="rain" and a.cloud.multimesh.instance_count==(84 if arena else 36))
    var surface=mesh.surface_get_arrays(0)
    assert(surface[Mesh.ARRAY_VERTEX].size()==6 and mesh==b.cloud.multimesh.mesh,"Greywood shares a lightweight rain streak mesh")
    for state in a.states:
     var earlier=a.particle_position(state,.25)
     var later=a.particle_position(state,.75)
     assert(later.y<earlier.y and later.x>earlier.x and later.z==earlier.z and state.life<1.11,"Rain falls quickly along one wind direction")
   elif theme=="mountain":
    assert(a.kind=="wind" and a.cloud.multimesh.instance_count==(24 if arena else 14))
    assert(a.cloud.material_override.albedo_texture!=null and a.cloud.multimesh.mesh is QuadMesh)
    for state in a.states:
     var earlier=a.particle_position(state,.25);var later=a.particle_position(state,.75)
     assert(is_equal_approx(later.x-earlier.x,a.extent.x*.32))
     assert(absf(later.y-earlier.y)<=.36001 and maxf(later.y,earlier.y)<=1.19)
     assert(state.life>=3.6 and state.life<=5.6)
   elif theme=="road":assert(a.kind=="leaves" and a.cloud.multimesh.mesh is ArrayMesh)
   elif theme in ["furnace","engine"]:assert(a.kind=="embers" and a.cloud.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD)
   for state in a.states:
    for phase in [0.0,.1,.25,.5,.75,.9,1.0]:
     var point=a.particle_position(state,phase)
     assert(a.cloud.multimesh.custom_aabb.has_point(point),"Particle paths remain inside their culling volume throughout a loop")
   var initial=a.cloud.multimesh.buffer;var untouched=b.cloud.multimesh.buffer
   a._process(.6)
   assert(a.cloud.multimesh.buffer!=initial and b.cloud.multimesh.buffer==untouched,"Visible atmosphere updates only its own instance data")
   var buffer=a.cloud.multimesh.buffer
   assert(buffer.size()==a.states.size()*16,"Bulk upload contains every matrix and color")
   for i in range(a.states.size()):
    var offset=i*16
    for channel in [12,13,14]:
     assert(buffer[offset+channel]==initial[offset+channel],"Particle color remains fixed while its opacity changes")
    if a.kind!="leaves":
     for channel in [0,1,2,4,5,6,8,9,10]:
      if a.kind=="wind" and channel==0:continue
      assert(buffer[offset+channel]==initial[offset+channel],"Only tumbling leaves and the width of wind wisps animate their transform bases")
    var basis=Basis(Vector3(buffer[offset],buffer[offset+4],buffer[offset+8]),Vector3(buffer[offset+1],buffer[offset+5],buffer[offset+9]),Vector3(buffer[offset+2],buffer[offset+6],buffer[offset+10]))
    var position=Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
    var transform=Transform3D(basis,position)
    var bounds=transform*a.cloud.multimesh.mesh.get_aabb()
    assert(a.cloud.multimesh.custom_aabb.encloses(bounds),"Actual uploaded instance geometry stays within the culling volume")
    assert(basis.determinant()>0 and basis.orthonormalized().determinant()>.99,"Packed rows retain a valid rotated/scaled basis")
    assert(buffer[offset+15]>=0 and buffer[offset+15]<=.7,"Uploaded opacity remains restrained")
    if a.kind=="wind":
     var reach=basis.x.length()/basis.y.length()
     assert(reach>=7.4 and reach<=10.3,"Wind uses quiet horizontal wisps with a smoothly changing length")
     assert(position.y<1.2 and buffer[offset+15]<=.27001)
   host.hide();var elapsed=a.elapsed;var held=a.cloud.multimesh.buffer;a._process(1)
   assert(a.elapsed==elapsed and a.cloud.multimesh.buffer==held,"Hidden map/arena atmosphere suspends updates")
   host.show();a._process(.1);assert(a.elapsed>elapsed)
   # Every loop starts and ends transparent, rather than popping into view.
   var state=a.states[0]
   for phase in [0.0,.001,.999]:
    a.elapsed=(1-state.phase+phase)*state.life;a.update_particles()
    assert(a.cloud.multimesh.buffer[15]<.01,"Loop boundaries fade before particles recycle")
   if theme=="forest":verify_ripples(a,b)
   a.queue_free();b.queue_free();await process_frame
 assert(source_meshes.size()==3 and materials.size()==4,"Airborne weather shares three meshes and four immutable paints")
 print("PASS: all 24 airborne atmosphere configurations share three meshes and four materials with private instance buffers and stable paint and basis channels")
 assert(game.rng.state==rng and game.save_data("camp")==saved,"Atmosphere never consumes campaign RNG or modifies saves")
 var scenery=Scenery.new()
 for chapter in range(12):
  game.chapter=chapter
  var map=Node3D.new();host.add_child(map);scenery.landscape(map,game)
  var atmosphere=map.get_node("AmbientDrift")
  assert(atmosphere.cloud.multimesh.instance_count>0 and atmosphere.position.y==0,"Every tactical chapter attaches its atmosphere after scenery batching")
  assert(map.has_node("ChimneySmoke")== (chapter==0),"Only Cinderford has active household vents")
  var arena=Node3D.new();host.add_child(arena);scenery.battle_landscape(arena,Vector3(35,0,0),{"environment":game.info().environment,"chapter":chapter})
  var closeup=arena.get_node("AmbientDrift")
  assert(closeup.kind==atmosphere.kind and closeup.position.x==35,"Close-up arena retains the chapter atmosphere around its real stage origin")
  verify_handoff(scenery,map,arena,game.info().environment)
  var reference=weakref(atmosphere);map.queue_free();arena.queue_free();await process_frame
  assert(reference.get_ref()==null,"Leaving a chapter releases its instanced atmosphere")
 await verify_chimneys(scenery,host,game)
 host.queue_free();await process_frame
 print("PASS: all twelve battlefields share seeded particles and exact phases in both directions at three sampled times")
 print("PASS: seamless deterministic cloud panorama, cached cover, horizon/zenith continuity, theme contrast; twelve chapter atmospheres, 24 map/arena configurations, bounded rain streaks, low Windscar crosswind and other instances, deterministic motion, hidden suspension, fade loops and cleanup")
 quit()

func verify_ripples(first,second):
 var mesh=first.ripples.multimesh.mesh
 assert(mesh==second.ripples.multimesh.mesh and first.ripples.material_override==second.ripples.material_override)
 assert(first.ripples.multimesh!=second.ripples.multimesh and first.ripples.multimesh.instance_count==first.states.size())
 assert(first.ripples.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not first.ripples.material_override.no_depth_test)
 var surfaces=mesh.surface_get_arrays(0);var vertices=surfaces[Mesh.ARRAY_VERTEX];var colors=surfaces[Mesh.ARRAY_COLOR]
 assert(vertices.size()==144 and colors.size()==vertices.size())
 for vertex in vertices:assert(is_zero_approx(vertex.y) and vertex.length()>=.779 and vertex.length()<=1.00001)
 assert(Array(colors).any(func(color):return color.a==0) and Array(colors).any(func(color):return color.a==1))
 var state=first.states[0];var end=first.particle_position(state,1)
 var impact=(1-state.phase)*state.life
 var expected=second.ripple_buffer.duplicate()
 var last_radius=0.0
 for age in [0.0,.03,.12,.22]:
  first.seek_elapsed(impact+age)
  var packed=first.ripples.multimesh.buffer
  assert(packed==first.ripple_buffer and second.ripple_buffer==expected)
  assert(is_equal_approx(packed[3],end.x) and is_equal_approx(packed[7],.018) and is_equal_approx(packed[11],end.z))
  assert(packed[0]>last_radius and packed[0]==packed[10] and packed[0]<=.237)
  last_radius=packed[0]
  if age==0.0 or age==.22:assert(packed[15]<.001)
  elif age==.03:assert(absf(packed[15]-.37)<.001)
  else:assert(packed[15]>.01 and packed[15]<.3)
 first.hide();var held=first.ripple_buffer.duplicate();first._process(.6)
 assert(first.ripple_buffer==held)
 first.show()
 print("PASS: Greywood ripples expand at the drop endpoints with soft edges and a shared, private instance clock")

func verify_chimneys(scenery,host,game):
 game.chapter=0
 var field=Node3D.new();host.add_child(field);scenery.batching_enabled=false;scenery.landscape(field,game)
 var field_smoke=field.get_node("ChimneySmoke")
 var vents=game.info().landmarks.filter(func(item):return item.kind=="house")
 var rims=field.find_children("ChimneyRim*","MeshInstance3D",true,false)
 var house_count=vents.size()
 assert(rims.size()==house_count*4 and field_smoke.multimesh.instance_count==house_count*ChimneySmoke.WISPS)
 for i in house_count:
  var site=Vector2(vents[i].position[0],vents[i].position[1])
  var vent=ChimneySmoke.vent(Vector3(site.x,0,site.y),Scenery.HOUSE_SCALE,site)
  assert(field_smoke.vents[i]==vent)
  for rim in rims.slice(i*4,(i+1)*4):
   var box=rim.global_transform*rim.mesh.get_aabb()
   assert(is_equal_approx(box.end.y,vent.origin.y) and not box.has_point(vent.origin-Vector3.UP*.02),"Smoke exits through an open rim at roof height")
 for direction in [-1.0,1.0]:
  var stage=Node3D.new();host.add_child(stage)
  var context=scenery.combat_context(game,{"x":1,"y":2},{"x":2,"y":2},direction)
  scenery.battle_landscape(stage,Vector3(35,0,0),context)
  var close=stage.get_node("ChimneySmoke")
  var moved_site=context.landmarks.filter(func(item):return item.kind=="house")[0].map_site
  var field_index=vents.map(func(item):return Vector2(item.position[0],item.position[1])).find(moved_site)
  var close_vent=close.vents[0]
  assert(field_index>=0 and close_vent.phase==field_smoke.vents[field_index].phase)
  assert(close.material_override==field_smoke.material_override and close.multimesh.mesh==field_smoke.multimesh.mesh)
  assert(close.multimesh!=field_smoke.multimesh and close.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  assert(close.wind.is_equal_approx(ChimneySmoke.WIND*direction))
  for step in 25:
   field_smoke.clock.seek_elapsed(float(step)/24.0*ChimneySmoke.LIFETIME)
   field_smoke.update_from_clock()
   scenery.transfer_environment_motion(field,stage,"village")
   assert(close.clock.elapsed==field_smoke.clock.elapsed)
   var near=field_smoke.instance_data
   var far=close.instance_data
   for i in ChimneySmoke.WISPS:
    var offset=i*16
    assert(far[offset+15]==near[(field_index*ChimneySmoke.WISPS+i)*16+15],"The same chimney keeps the phase and opacity of every wisp")
   for i in close.multimesh.instance_count:
    var offset=i*16
    var position=Vector3(far[offset+3],far[offset+7],far[offset+11])
    var radius=Vector3.ONE*Vector2(far[offset],far[offset+5]).length()*.5
    assert(close.multimesh.custom_aabb.encloses(AABB(position-radius,radius*2)))
  var frozen=field_smoke.instance_data.duplicate()
  field.hide();close.clock.seek_elapsed(close.clock.elapsed+.5);field_smoke._process(.5)
  assert(field_smoke.instance_data==frozen)
  scenery.transfer_environment_motion(stage,field,"village")
  assert(field_smoke.clock.elapsed==close.clock.elapsed and field_smoke.instance_data!=frozen)
  field.show();stage.queue_free();await process_frame
 var paired=Node3D.new();host.add_child(paired)
 var context=scenery.combat_context(game,{"x":8,"y":4},{"x":9,"y":4})
 scenery.battle_landscape(paired,Vector3(35,0,0),context)
 var roofs=paired.find_children("TiledRoof","MeshInstance3D",true,false)
 assert(roofs.size()==2)
 var first=roofs[0].global_transform*roofs[0].mesh.get_aabb()
 var second=roofs[1].global_transform*roofs[1].mesh.get_aabb()
 assert(not first.intersects(second),"Two visible village rooftops have separate eaves")
 paired.queue_free()
 field.queue_free();await process_frame
 print("PASS: seven Cinderford vents, fifty chimney phases through both camera directions, one shared mesh per view, open rims, culling and hidden handoff")


func verify_handoff(scenery,field: Node3D,stage: Node3D,theme: String):
 var map=field.get_node("AmbientDrift")
 var closeup=stage.get_node("AmbientDrift")
 assert(closeup.cloud.multimesh!=map.cloud.multimesh)
 assert(closeup.states.size()>map.states.size() and closeup.states.slice(0,map.states.size())==map.states,"The arena retains the field particles and adds a local layer")
 for elapsed in [1.375,39.5,97.125]:
  map.seek_elapsed(elapsed)
  var start=map.instance_buffer.duplicate()
  scenery.transfer_environment_motion(field,stage,theme)
  assert(closeup.elapsed==elapsed and map.instance_buffer==start)
  compare_drift(map,closeup)
  field.hide();stage.show()
  map._process(.23);closeup._process(.23)
  assert(map.elapsed==elapsed and closeup.elapsed>elapsed)
  var later=closeup.instance_buffer.duplicate()
  scenery.transfer_environment_motion(stage,field,theme)
  assert(map.elapsed==closeup.elapsed and map.instance_buffer!=start and closeup.instance_buffer==later)
  compare_drift(map,closeup)
  field.show()

func compare_drift(map,closeup):
 for index in range(map.states.size()):
  var offset=index*16
  for channel in range(16):
   var near=map.instance_buffer[offset+channel]
   var far=closeup.instance_buffer[offset+channel]
   match channel:
    3:assert(absf(near/map.extent.x-far/closeup.extent.x)<.000001)
    7:
     if map.kind=="wind":assert(near==far)
     else:assert(absf((near-.15)/(map.extent.y-.3)-(far-.15)/(closeup.extent.y-.3))<.000001)
    11:assert(absf(near/map.extent.z-far/closeup.extent.z)<.000001)
    _:assert(near==far,"The same particle keeps its orientation, scale and opacity in both scenes")
  if map.kind=="rain":
   for channel in [0,5,7,10,12,13,14,15]:
    assert(map.ripple_buffer[offset+channel]==closeup.ripple_buffer[offset+channel],"The same ripple keeps its age and surface height through the cut")

func verify_clouds():
 var image=CloudSky.image();var total=0.0;var bright=0;var clear=0
 assert(image.get_size()==Vector2i(1024,512) and image.has_mipmaps(),"Cloud cover has the expected equirectangular dimensions and mipmaps")
 assert(image.get_data()==CloudSky.image().get_data(),"Clouds regenerate deterministically without consuming game RNG")
 assert(CloudSky.texture()==CloudSky.texture(),"Every map/arena shares one cached cloud texture")
 for y in range(image.get_height()):
  assert(absf(image.get_pixel(0,y).a-image.get_pixel(image.get_width()-1,y).a)<=1.0/255,"Cloud panorama closes its longitude seam")
  for x in range(image.get_width()):
   var alpha=image.get_pixel(x,y).a
   if y>=image.get_height()/2:assert(alpha==0,"Cloud cover ends before the ground hemisphere")
   else:
    total+=alpha
    if alpha>.8:bright+=1
    if alpha<.02:clear+=1
   if y==0:assert(image.get_pixel(x,y)==image.get_pixel(0,y),"The zenith has no directional pinching seam")
 assert(total/(1024*256)>.15 and total/(1024*256)<.45 and bright>1000 and clear>10000,"Cloud cover keeps both substantial cloud banks and open sky")
 for x in range(1024):assert(image.get_pixel(x,255).a==0,"Clouds fade out before meeting the distant horizon")
 assert(CloudSky.tint("observatory").a<CloudSky.tint("village").a and CloudSky.tint("engine").a==0 and CloudSky.tint("furnace").a==0,"Night cloud contrast is reduced and enclosed industrial skies stay clear")

func verify_star_cover():
 var night=CloudSky.image(true)
 assert(night.get_size()==CloudSky.SIZE and night.has_mipmaps())
 assert(night.get_data()==CloudSky.image(true).get_data(),"Starfall's cover regenerates byte for byte")
 assert(CloudSky.texture(true)!=CloudSky.texture() and CloudSky.texture(true)==CloudSky.texture(true))
 var quarters=[0,0,0,0]
 for y in night.get_height():
  assert(absf(night.get_pixel(0,y).a-night.get_pixel(night.get_width()-1,y).a)<=1.0/255)
  for x in night.get_width():
   var point=night.get_pixel(x,y)
   if y>=night.get_height()/2:assert(point.a==0)
   if point.a>.4:
    assert(y>=13 and y<night.get_height()/2-14,"Stars stay away from the zenith seam and horizon fade")
    quarters[x/(night.get_width()/4)]+=1
 assert(quarters.all(func(count):return count>22 and count<83),"Bright stars spread quietly around the panorama")
 var chart_pixels={}
 var day=CloudSky.texture().get_image()
 var group=CloudSky.Chart.CONSTELLATIONS[0]
 for index in group:
  var pixel=CloudSky.chart_star_pixel(index)
  assert(not chart_pixels.has(pixel));chart_pixels[pixel]=true
  var star=night.get_pixelv(pixel)
  var pigment=Color("f2e4c6") if index==1 else Color("d5e3f7")
  assert(star.a>=.90 and Color(star,1).is_equal_approx(pigment))
  assert(night.get_pixelv(pixel+Vector2i(0,2)).a>night.get_pixelv(pixel+Vector2i(0,3)).a,
   "Each authored point has a soft edge")
  assert(Color(day.get_pixelv(pixel),1)==Color.WHITE,"The chapter's stars appear only on the night cover")
 assert(chart_pixels.size()==5)
 print("PASS: five chart stars use the engraved pattern, warm and cool cores and quiet outer glow")
 print("PASS: the deterministic Starfall cover scatters dim stars across four sectors and preserves the horizon and longitude seams")
