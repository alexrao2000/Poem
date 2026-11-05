extends SceneTree
const Imported=preload("res://scripts/imported_fighter.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const Vertices=preload("helpers/authored_vertices.gd")
# Run this external script against an exported PCK from a different working
# directory, so resource and text checks cannot silently use the source tree.
func _initialize():call_deferred("run")

func run():
 assert(FileAccess.get_file_as_string("res://scripts/browser_journal.js").contains("poemSaveJournal"),"Export includes browser checkpoint recovery")
 assert(load("res://scripts/casualty_card.gd").lines.size()==24,"Export includes all recruit casualty dialogue")
 for path in ["res://assets/fonts/OFL.txt","res://assets/audio/VSCO-LICENSE.txt","res://assets/audio/VSCO-CREDITS.txt"]:
  assert(FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).length()>100,"Export includes font and instrument credits/licenses")
 for family in ["base","outfits","animations"]:
  assert(FileAccess.get_file_as_string("res://assets/models/quaternius/licenses/"+family+".txt").contains("CC0 1.0 Universal"),"Release retains the supplied model and animation licenses")
 for gender in ["female","male"]:
  var model=load("res://assets/models/quaternius/duelist_"+gender+".gltf").instantiate()
  assert(model.get_node("AnimationPlayer").has_animation("Sword_Attack"),"Packaged source rigs retain their selected skeletal clips")
  model.free()
 var wang=load("res://assets/art/terrain-wang.png")
 assert(wang is Texture2D and wang.get_size()==Vector2(576,1152) and wang.get_image().has_mipmaps(),"Release includes the padded natural-ground Wang atlas and mipmaps")
 var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/score.json"))
 assert("CC0" in metadata.samples and metadata.frames==1568000,"Export uses the current orchestral arrangement")
 var app=load("res://main.tscn").instantiate();app.settings_path="";app.save_path="/private/tmp/poem-export-test.json";root.add_child(app);await process_frame
 assert(app.ui.get_node("TitleBackdrop").ART.get_width()==1536,"Release includes the original dawn title illustration")
 var dialogue_art=load("res://scripts/dialogue_backdrop.gd")
 for chapter in range(12):
  for kind in ["opening","closing"]:
   var picture=dialogue_art.texture_for(chapter,kind)
   assert(picture.atlas.get_width()==1536 and picture.region.size.x>=764 and picture.filter_clip,"Release includes all twelve dialogue locations and closing variants")
 for job in app.CLASSES:assert(app.map_catalog.assets.has("unit."+job.to_lower()),"Release initializes every fallback class without relying on assertions")
 assert(app.map_catalog.recruit_errors.is_empty(),"Packaged recruit artwork validates")
 assert(app.map_catalog.enemy_errors.is_empty(),"Packaged enemy artwork validates")
 assert(app.fighters.enemy_looks.size()==8 and app.fighters.face_atlas.resource_path.ends_with("face-features-v2.png"),"Release includes the matching enemy profiles and current painted facial features")
 assert(app.fighters.EquipmentVisuals.profiles.size()==22 and app.fighters.EquipmentVisuals.profiles.war_hammer.shape=="hammer","Release includes every equipped item appearance")
 assert(app.interface_audio.streams.size()==3 and app.interface_audio.streams.confirm.get_length()>.14,"Release includes the original interface cues")
 assert(app.travel_audio.streams.size()==6 and app.travel_audio.streams.hoof_wood.get_length()>.14,"Release includes all original terrain foot/hoof contacts")
 for element in ["ember","gale","thunder"]:assert(app.sfx_streams["impact_"+element].get_length()>.37,"Packaged spells include their elemental contact sound")
 for family in ["sword","axe","lance","bow","ember","gale","thunder"]:assert(app.sfx_streams["release_"+family].get_length()>.13,"Packaged combat includes every original weapon/element release cue")
 for job in app.CLASSES:assert(app.map_catalog.assets.has("enemy."+job.to_lower()),"Release includes every dedicated enemy class atlas")
 for chapter in [0,4,8,11]:
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle();await process_frame
  assert(app.score_director.current_id==["standard","road","dawnless"][chapter/4],"Export includes every act-specific score pair")
  assert(app.unit_nodes.size()==app.game.units.size(),"Packaged maps instantiate every living actor")
  var commander=app.game.units.filter(func(unit):return unit.get("boss",false))[0]
  assert(app.unit_nodes[commander.id].has_node("CommanderInsignia") and app.portraits.get_unit_portrait(commander).atlas.get_width()==1254,"Release includes commander crowns and their separate portrait atlas")
  for actor in app.unit_nodes.values():assert(actor.sprite.texture!=null and actor.player.asset.clips.has("move"),"Packaged actors have atlas frames and animations")
 app.game.story_seen.append("opening_"+str(app.game.chapter));app.show_camp();await process_frame
 assert(app.ui.find_child("CompanyCards",true,false).get_child_count()==24 and app.ui.has_node("CouncilBackdrop"),"Release includes the complete portrait preparation roster and covered-scene suspension")
 app.show_credits();await process_frame;assert(app.screen=="credits")
 app.show_campaign_route();await process_frame
 var route=app.ui.find_child("CampaignRoute",true,false)
 assert(route!=null and route.MAP.get_width()==1536 and route.markers.size()==12,"Release includes the illustrated campaign route and all chapter markers")
 for path in app.game.promotions:
  var unit=app.game.roster.filter(func(value):return value.job==path.base)[0].duplicate(true)
  unit.team="player";unit.promotion=path.id
  var actor=app.make_fighter(unit,Vector3(35,0,0))
  assert(actor.get_meta("promotion_look","")==path.id,"Release includes every promotion costume profile and constructor")
  assert(actor.cape_motion.surfaces.size()==2,"Release binds cape fabric and outline motion")
  assert(actor.gaze_motion.neck==actor.bones.Gaze,"Release retains the separate gaze joint")
  if actor.bones.has("HairFall"):assert(actor.hair_motion.root==actor.bones.HairFall,"Release binds loose hair after outfit batching")
  assert(actor.face_blink.surface.get_shader_parameter("closed_face").get_width()==1774,"Release includes the original eyelids on every promoted actor")
  if unit.weapon=="magic":
   assert(actor.bones.Weapon.get_parent()==actor.bones.LeftElbow and actor.bones.Weapon.has_node("Spellbook"),"Packaged caster retains the open folio and free casting hand")
   assert(actor.find_children("*","MeshInstance3D",true,false).any(func(mesh):return mesh.material_override.get_meta("no_character_outline",false) and mesh.material_override.albedo_texture!=null),"Packaged folio generates its original printed pages")
  if path==app.game.promotions[0]:
   assert(ResourceLoader.exists("res://assets/shaders/defeat-mask.gdshaderinc"),"Release includes the dynamically selected defeat shader include")
   var departure=load("res://scripts/combat_defeat.gd").new();app.stage.add_child(departure);departure.begin(actor)
   departure.motion.custom_step(.5)
   assert(not actor.visible and departure.visibility==0,"Packaged material variants complete the defeated actor exit")
   departure.queue_free()
  actor.queue_free();await process_frame
 app.game.new_campaign(true);app.game.story_seen=["opening_0"];app.show_camp();app.show_options("camp")
 app.ui.find_child("DebugMode",true,false).button_pressed=true
 for key in ["action_saves","death_door","section_restarts","reset_pressure","hard_campaign","death_legacies","sacrifice_cost"]:
  app.ui.find_child(key,true,false).button_pressed=true
 app.close_options();app.game.start_battle()
 var patient=app.game.units[1];patient.hp=0;app.game.DeathDoor.fall(app.game,patient)
 app.make_map();app.show_battle()
 assert(app.unit_nodes.has(patient.id) and app.unit_nodes[patient.id].downed and app.unit_nodes[patient.id].rescue_marker.texture.get_width()==64,"Packaged experiment keeps a rescuable downed ally visible")
 var second_patient=app.game.units.filter(func(unit):return unit.team=="player" and unit.id not in [patient.id,app.game.units[0].id])[0]
 var previous=second_patient.duplicate(true);second_patient.hp=0;app.game.DeathDoor.fall(app.game,second_patient);second_patient.x=patient.x;second_patient.y=patient.y
 app.refresh_pieces();app.click_tile(app.game.pos(patient));await process_frame
 assert(app.screen=="tile_units" and app.unit_nodes[patient.id].shared_marker.texture.get_width()==64 and app.ui.find_child("TileUnit_"+second_patient.id,true,false)!=null,"Packaged shared-position badge opens both patient choices")
 second_patient.clear();second_patient.merge(previous,true);app.refresh_pieces();app.show_battle()
 var carrier=app.game.units[0];assert(app.game.DeathDoor.rescue(app.game,carrier,patient));app.refresh_pieces()
 assert(app.unit_nodes[carrier.id].carry_marker.texture.get_width()==64 and not app.unit_nodes.has(patient.id),"The exported package includes the carrier badge and hides its passenger")
 app.show_debug_tools("battle");assert(app.ui.find_child("DebugCasualty",true,false)!=null and app.ui.find_child("DebugSeed",true,false)!=null,"Release contains the debug experiment harness and reproducible seed controls")
 for gender in ["female","male"]:
  app.show_source_model_view(gender,"tempered_sword",true);await process_frame
  assert(app.preview_actor is Imported,"Packaged debug model study uses its authored source wrapper")
  assert(app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").equipped=="tempered_sword","Packaged authored rig uses the selected sword")
  assert(app.preview_actor.weapon_trail_points().size()==2,"Packaged original sword keeps its animated trail sockets")
  var identity=app.preview_actor.model.get_node("Identity")
  assert(identity.outline!=null and identity.outline.pairs.size()>10,"Packaged revised models include their private skinned-normal outlines")
  for entry in identity.outline.pairs:
   assert(entry.material.next_pass==entry.shell and entry.shell.shader.resource_path.ends_with("authored-outline.gdshader"))
  assert(identity.cloak.cloth.mesh!=null and identity.cloak.cloth.material_override.get_shader_parameter("cape_mark")==load("res://assets/art/cape-company.svg"),"Packaged styled study retains its original company cloak")
  assert(identity.identity in ["nell","silas"] and identity.painted_materials.size()>=3,"Packaged study retains original identity and private dyed materials")
  var gaze_target=Marker3D.new();app.stage.add_child(gaze_target);gaze_target.global_position=app.preview_actor.to_global(Vector3(0,2.4,-2))
  app.preview_actor.face_opponent(gaze_target);app.preview_actor.pose("idle",.01);await create_timer(.4).timeout
  var head=identity.gaze.rig.get_node("Face")
  assert(identity.gaze.modifier.active and head.global_basis.z.normalized().dot((identity.gaze.target.global_position-head.global_position).normalized())>.998,"Packaged original head follows a mounted opponent")
  assert(identity.gaze.rig.get_node("PortraitNeck").skin!=null,"Packaged original identity retains the cropped neck skin")
  app.preview_actor.pose("hit",.01);assert(identity.blink.closed and not identity.gaze.modifier.active,"Packaged styled head retains complete facial/neck reactions")
  gaze_target.queue_free()
  var actions=app.stage.get_node("PreviewActionPlayer");actions.play("advance");await create_timer(.08).timeout
  assert(app.preview_actor.stride_phase>0 and not app.preview_actor.player.is_playing(),"Packaged study drives the imported jog explicitly by distance")
  var target_choice=app.ui.find_child("StudyTarget",true,false);target_choice.select(2);target_choice.item_selected.emit(2)
  await app.stage.get_node("PreviewActionPlayer").finished
  var edge=app.preview_actor.weapon_trail_points();var point=app.preview_actor.get_node("StudyContactTarget").global_position
  assert(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)<.006,"Packaged skeletal strike reaches the mounted study target")
  await app.preview_actor.pose("down",.02).finished
  var rig=app.preview_actor.model.get_node("Rig/Armature/Skeleton3D");var held_sword=app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip/Weapon")
  var finger=rig.to_global(rig.get_bone_global_pose(rig.find_bone("middle_04_leaf_r")).origin)
  assert(finger.distance_to(Geometry3D.get_closest_point_to_segment(finger,held_sword.to_global(Vector3(0,0,-.195)),held_sword.to_global(Vector3(0,0,.035))))<.045,"Packaged falling actor retains its equipped grip")
  app.close_model_view();await process_frame
 for pair in [["caster","tarin"],["caster_female","vela"]]:
  app.show_source_model_view(pair[0],"thunder",true);await process_frame
  var caster=app.preview_actor;assert(caster is Imported and caster.model.get_meta("character_identity")==pair[1],"Packaged casting study retains the original identity")
  await caster.pose("windup",.02).finished;await caster.pose("strike",.02).finished
  if pair[1]=="vela":assert(caster.model.get_node("Identity").hair_motion.root!=null,"Packaged female caster retains her dynamic braid")
  var robe=caster.model.get_node("Identity").robe
  assert(robe!=null and robe.pieces.size()==2 and robe.pieces[0].skin.get_bind_count()==5,"Packaged caster retains the fitted original robe and its skin")
  var caster_rig=caster.model.get_node("Rig/Armature/Skeleton3D");var support=caster_rig.get_node("FolioSupport")
  assert(caster_rig.get_node("BookHand").position.distance_to((caster_rig.get_bone_global_pose(support.chest)*support.target).origin)<.0001,"Packaged folio retains its actual skeletal support")
  assert(caster.to_local(caster.socket_position("projectile")).z<-.5 and caster_rig.get_node("BookHand/Folio").equipped=="thunder","Packaged casting hand and selected folio use separate attachments")
  app.close_model_view();await process_frame
 for pair in [["warden","ivo"],["warden_female","esme"]]:
  app.show_source_model_view(pair[0],"beacon_staff",true);await process_frame
  var warden=app.preview_actor;assert(warden is Imported and warden.model.get_meta("character_identity")==pair[1])
  var staff=warden.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Staff")
  assert(staff.equipped=="beacon_staff" and staff.hold.model==warden.model and staff.hold.corners.size()==8,"Packaged staff retains its fitted wrist constraint and prop bounds")
  await warden.pose("cast",.02).finished
  assert(warden.socket_position("projectile").distance_to(staff.get_node("Weapon/Crown").global_position)<.00001,"Packaged healing uses the staff crown socket")
  await warden.pose("down",.02).finished
  for mesh in staff.get_node("Weapon").find_children("*","MeshInstance3D",true,false):
   for surface in range(mesh.mesh.get_surface_count()):
    for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).y>warden.global_position.y+.01,"Packaged falling staff clears the floor")
  app.close_model_view();await process_frame
 for pair in [["corsair_female","mara"],["corsair_male","dax"]]:
  app.show_source_model_view(pair[0],"war_hammer",true);await process_frame
  var corsair=app.preview_actor;assert(corsair is Imported and corsair.model.get_meta("character_identity")==pair[1])
  var grip=corsair.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip")
  assert(grip.equipped=="war_hammer" and grip.floor_fit.model==corsair.model and grip.floor_fit.corners.size()==8,"Packaged axe retains its fitted shaft and floor constraint")
  var target=app.ui.find_child("StudyTarget",true,false);target.select(2);target.item_selected.emit(2);await app.stage.get_node("PreviewActionPlayer").finished
  var edge=corsair.weapon_trail_points();var point=corsair.get_node("StudyContactTarget").global_position
  assert(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1]).distance_to(point)<.01)
  await corsair.pose("down",.02).finished
  for mesh in grip.get_node("Weapon").find_children("*","MeshInstance3D",true,false):
   for surface in range(mesh.mesh.get_surface_count()):
    for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).y>corsair.global_position.y+.01,"Packaged falling hammer clears the floor")
  app.close_model_view();await process_frame
 for pair in [["ranger_female","sera"],["ranger_male","ari"]]:
  app.show_source_model_view(pair[0],"longbow",true);await process_frame
  var ranger=app.preview_actor;assert(ranger is Imported and ranger.model.get_meta("character_identity")==pair[1])
  var rig=ranger.model.get_node("Rig/Armature/Skeleton3D");var bow=rig.get_node("WeaponHand/Bow");var arrow=bow.get_node("Weapon/NockedArrow")
  assert(bow.equipped=="longbow" and bow.arms.model==ranger.model and bow.arms.chain.size()==8 and ranger.player.get_animation_list().size()==15,"Packaged Ranger retains both-arm fitting and four private bow clips")
  var point=ranger.to_global(Vector3(0,1.85,-4));ranger.aim_at(point);await ranger.pose("windup",.02).finished
  assert(rig.get_node("DrawingHand").to_global(bow.finger_pad).distance_to(bow.get_node("Weapon").to_global(Vector3(0,0,.52)))<.0001)
  assert((-arrow.global_basis.z.normalized()).dot((point-arrow.global_position).normalized())>.999999)
  await ranger.pose("strike",.02).finished;assert(not arrow.visible and bow.projectile_spent,"Packaged release hides the nocked arrow")
  await ranger.pose("recover",.02).finished;assert(not arrow.visible)
  await ranger.pose("down",.02).finished
  for mesh in bow.get_node("Weapon").find_children("*","MeshInstance3D",true,false):
   if not mesh.is_visible_in_tree():continue
   for surface in range(mesh.mesh.get_surface_count()):
    for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).y>ranger.global_position.y+.01)
  app.close_model_view();await process_frame
 for pair in [["knight_female","petra"],["knight_male","oren"]]:
  app.show_source_model_view(pair[0],"riders_bane",true);await process_frame
  var knight=app.preview_actor;assert(knight is Imported and knight.model.get_meta("character_identity")==pair[1])
  var armor=knight.model.get_node("Identity").armor;assert(armor!=null and armor.anchors.size()==11 and armor.surfaces[0].get_shader_parameter("paint_average").is_equal_approx(Vector3(.229348,.231699,.239027)))
  var target=app.ui.find_child("StudyTarget",true,false);target.select(2);target.item_selected.emit(2);await app.stage.get_node("PreviewActionPlayer").finished
  assert(knight.weapon_trail_points()[1].distance_to(knight.get_node("StudyContactTarget").global_position)<.005,"Packaged lance constraints reach the mounted target")
  assert(knight.socket_position("guard").is_equal_approx(knight.model.get_node("Rig/Armature/Skeleton3D/KnightShield/Plate/Guard").global_position))
  var cache=Vertices.prepare(knight)
  await knight.pose("down",.02).finished
  assert(Vertices.minimum(knight,cache)>knight.global_position.y+.01,"Packaged root-height fit keeps the complete armored body and shield clear of the floor")
  app.close_model_view();await process_frame
 for pair in [["knight_female","petra"],["knight_male","oren"]]:
  app.show_source_model_view(pair[0],"javelin",true);await process_frame
  var knight=app.preview_actor;var weapon=knight.projectile_source();assert(weapon!=null)
  var point=knight.to_global(Vector3(0,1.85,-4));knight.aim_at(point)
  await knight.pose("throw_windup",.02).finished;await knight.pose("throw",.02).finished;assert(not weapon.visible)
  var flight=load("res://scripts/combat_projectile.gd").new();app.stage.add_child(flight)
  flight.launch(knight.socket_position("projectile"),point,"lance",.23,"",{},true,weapon).pause()
  assert(flight.origin.distance_to(weapon.get_node("TrailTip").global_position)<.00001 and flight.travel_end>1)
  var copy=flight.body.get_node("HeldSpear")
  for mesh in weapon.find_children("*","MeshInstance3D",true,false):
   var copied=copy.get_node(weapon.get_path_to(mesh))
   for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:assert(mesh.to_global(vertex).distance_to(copied.to_global(vertex))<.0001,"Packaged flight retains every fitted spear vertex at release")
  await knight.pose("recover",.02).finished;assert(not weapon.visible and knight.player.assigned_animation=="LanceThrowRecover")
  flight.queue_free();app.close_model_view();await process_frame
 app.show_source_model_view("vanguard","iron_sword",true);await process_frame
 var vanguard=app.preview_actor;assert(vanguard is Imported and vanguard.model.get_meta("character_identity")=="lyra" and vanguard.model.get_node("Identity").mantle!=null,"Packaged Vanguard study retains Lyra’s ivory mantle")
 await vanguard.pose("strike",.02).finished
 assert(vanguard.model.get_node("Identity").mantle.surfaces[0].get_shader_parameter("cloth_floor_enabled"))
 app.close_model_view();await process_frame
 app.show_debug_tools("battle");app.ui.find_child("DebugDuelistModels",true,false).button_pressed=true
 var recruit=app.game.roster.filter(func(unit):return unit.id=="nell")[0].duplicate(true);recruit.team="player"
 var revised=app.make_fighter(recruit,Vector3.ZERO)
 assert(revised is Imported and revised.model.get_meta("character_identity")=="nell","Packaged debug toggle selects the styled recruit through the normal combat builder")
 revised.queue_free();await process_frame
 app.ui.find_child("DebugDuelistModels",true,false).button_pressed=false
 app.ui.find_child("DebugCasterModel",true,false).button_pressed=true
 for id in ["tarin","vela","noor"]:
  var mage=app.game.roster.filter(func(unit):return unit.id==id)[0].duplicate(true);mage.team="player";mage.item="gale"
  var revised_mage=app.make_fighter(mage,Vector3.ZERO)
  assert(revised_mage is Imported and revised_mage.model.get_meta("character_identity")==id and revised_mage.model.get_node("Rig/Armature/Skeleton3D/BookHand/Folio").equipped=="gale","Packaged casting toggle selects the styled mage independently")
  revised_mage.queue_free();await process_frame
 app.ui.find_child("DebugCasterModel",true,false).button_pressed=false
 app.show_debug_report();assert(JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).debug,"Packaged debug reports contain the current experiment record")
 assert(app.game.trials.scenes.size()==10,"Release includes relief, retreat, volunteer and memorial story scenes")
 assert(app.persist_campaign("battle") and FileAccess.file_exists(app.save_path+".debug"),"Packaged debug actions save separately")
 app.debug_session.end(app.game);app.preferences.values.character_models="revised"
 for id in ["lyra","nell","silas","yuna","tarin","vela","noor","cassian","rhea","ivo","esme","galen","mara","dax","hale","sera","ari","faye"]:
  var campaign_recruit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);campaign_recruit.team="player";campaign_recruit.item="iron_sword" if campaign_recruit.weapon=="sword" else "iron_axe" if campaign_recruit.weapon=="axe" else "scout_bow" if campaign_recruit.weapon=="bow" else "field_staff" if campaign_recruit.weapon=="staff" else "ember"
  var campaign_model=app.make_fighter(campaign_recruit,Vector3.ZERO)
  assert(not app.debug_session.active and campaign_model is Imported and campaign_model.model.get_meta("character_identity")==id,"Packaged appearance preference works for every revised recruit in the ordinary campaign")
  campaign_model.queue_free();await process_frame
 await Shutdown.dispose(app);await process_frame
 print("PASS: exported catalog, all three act scores, chapter scenes, sixteen promotion costumes, licenses and credits")
 quit()
