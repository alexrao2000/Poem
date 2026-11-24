extends SceneTree
const Rider=preload("res://scripts/imported_rider.gd")
const Imported=preload("res://scripts/imported_fighter.gd")
const Director=preload("res://scripts/combat_camera.gd")
const Shutdown=preload("helpers/game_shutdown.gd")
const Vertices=preload("helpers/authored_vertices.gd")
# Run this external script against an exported PCK from a different working
# directory, so resource and text checks cannot silently use the source tree.
func _initialize():call_deferred("run")

func skip_packed_opening(app):
 while app.ui.get_node_or_null("CombatPlayback")==null:await process_frame
 await process_frame
 assert(not app.markers.visible and app.unit_nodes.values().all(func(actor):return not actor.tactical_details_visible and not actor.health.visible and not actor.ring.visible),"Packaged opening zoom hides tactical indicators while retaining map sprites")
 app.ui.get_node("CombatPlayback").request_skip()

func run():
 assert(FileAccess.get_file_as_string("res://scripts/browser_journal.js").contains("poemSaveJournal"),"Export includes browser checkpoint recovery")
 var formation_rules=load("res://scripts/rules.gd").new()
 for chapter in [4,8,11]:
  formation_rules.chapter=chapter;formation_rules.trials.flags.hard_campaign=true;formation_rules.start_battle()
  var count=formation_rules.info().enemies.size()
  assert(formation_rules.living("enemy").size()==count+1 and formation_rules.living("enemy")[-1].job=="Warden","Packed late Hard garrisons include their authored field Warden")
  var restored_formation=load("res://scripts/rules.gd").new()
  assert(restored_formation.restore_save(formation_rules.save_data("battle"))=="battle" and restored_formation.living("enemy").size()==count+1)
  formation_rules.trials.flags.hard_campaign=false;formation_rules.start_battle()
  assert(formation_rules.living("enemy").size()==count,"Packed ordinary garrisons retain their original size")
 var encounters=load("res://scripts/debug_encounters.gd")
 var mechanism=load("res://scripts/clockwork_orbit.gd").new();root.add_child(mechanism);mechanism.configure("engine",1.875,1.2);mechanism.set_process(false);await process_frame
 assert(mechanism.find_children("*","MeshInstance3D",true,false).size()==4,"Packed mechanisms retain their four locally batched meshes")
 var initial_ring=mechanism.outer.transform;mechanism._process(.5)
 assert(mechanism.outer.transform!=initial_ring and mechanism.core.scale.x>1,"Packed ring motion and restrained core pulse advance")
 mechanism.hide();var held_clock=mechanism.elapsed;mechanism._process(1);assert(mechanism.elapsed==held_clock)
 mechanism.queue_free();await process_frame
 assert(encounters.SCENES.size()==8)
 for scene in encounters.SCENES:
  var staged_rules=load("res://scripts/rules.gd").new()
  assert(not encounters.start(staged_rules,scene.id,309).is_empty() and staged_rules.valid_save(staged_rules.save_data("battle")),"Packed encounter starters build complete valid playable positions")
 var roster_rules=load("res://scripts/rules.gd").new()
 for chapter in 12:
  assert(not encounters.start_recruit(roster_rules,"lyra","",309,"",chapter).is_empty() and roster_rules.chapter==chapter and roster_rules.valid_save(roster_rules.save_data("battle")),"Packed battlefield choices retain all twelve legal campaign maps")
 for recruit in roster_rules.content.roster:
  for training in [""]+roster_rules.promotion_options(recruit).map(func(path):return path.id):
   assert(not encounters.start_recruit(roster_rules,recruit.id,training,309).is_empty() and roster_rules.valid_save(roster_rules.save_data("battle")),"Packed full-roster encounters retain all 72 base and promoted positions")
 for recruit in roster_rules.content.roster:
  for item in roster_rules.equipment:
   if item.kind!=recruit.weapon:continue
   var setup=encounters.start_recruit(roster_rules,recruit.id,"",309,item.id)
   assert(not setup.is_empty())
   var actor=roster_rules.units.filter(func(u):return u.id==setup.actor)[0];var recipient=roster_rules.units.filter(func(u):return u.id==setup.target)[0]
   assert(actor.item==item.id and roster_rules.distance(actor,recipient)==int(item.max_range) and roster_rules.valid_save(roster_rules.save_data("battle")),"Packed equipment starters retain all catalogued legal item/recruit pairs")
 assert(load("res://scripts/casualty_card.gd").lines.size()==26,"Export includes all recruit casualty dialogue")
 for id in ["maelin","tovin"]:
  var portrait=load("res://assets/portraits/"+id+"-v1.png") as Texture2D
  assert(portrait!=null and maxf(portrait.get_width(),portrait.get_height())==768)
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
 assert(app.preferences.values.character_models=="revised","Packaged fresh profiles start with revised models")
 var fresh_unit=app.game.roster[0].duplicate(true);fresh_unit.team="player"
 var fresh_lyra=app.make_fighter(fresh_unit,Vector3.ZERO)
 assert(fresh_lyra.has_meta("source_model"),"Packaged fresh profiles select the fitted opening model")
 fresh_lyra.free();app.preferences.values.character_models="current"
 assert(app.ui.get_node("TitleBackdrop").ART.get_width()==1536,"Release includes the original dawn title illustration")
 var cutin_host=Control.new();root.add_child(cutin_host);cutin_host.size=Vector2(1440,900)
 var packed_cutin=load("res://scripts/critical_cutin.gd").new()
 packed_cutin.configure(cutin_host,{"name":"Lyra","team":"player"},null,"For everyone behind me!")
 cutin_host.size=Vector2(1024,640);await process_frame
 assert(is_equal_approx(packed_cutin.size.x,cutin_host.size.x) and packed_cutin.get_node("Quote").get_rect().end.x<cutin_host.size.x,"Packed critical accent reflows after the viewport shrinks")
 var packed_phase=load("res://scripts/phase_banner.gd").new();packed_phase.configure(cutin_host,"enemy",7)
 cutin_host.size=Vector2(1280,720);await process_frame
 assert(is_equal_approx(packed_phase.size.x,cutin_host.size.x) and packed_phase.heading.get_rect().end.x<cutin_host.size.x and packed_phase.detail.text=="TURN 07","Packed phase ribbon follows its resized host without changing the announced turn")
 var playback=load("res://scripts/combat_playback.gd").new();playback.configure(cutin_host)
 var clock_before=playback.original_scale;var skip_count=[0];playback.skip_requested.connect(func():skip_count[0]+=1)
 playback.fast_button.button_pressed=true
 assert(Engine.time_scale==clock_before*2 and playback.pointer_fast,"Packed pointer control accelerates the presentation clock")
 playback.request_skip();playback.request_skip();assert(skip_count[0]==1)
 playback.stop();assert(Engine.time_scale==clock_before and playback.fast_button.disabled and playback.skip_button.disabled)
 cutin_host.queue_free();await process_frame
 var packed_story=JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
 var survivor_dialogue=load("res://scripts/story_survivors.gd")
 var survivor_closing=survivor_dialogue.resolve(packed_story.chapters[0].closing,["oren"])
 assert(survivor_closing.any(func(line):return "carry his name" in line.text) and not survivor_closing.any(func(line):return line.speaker=="oren" or "go home now" in line.text),"Packaged story retains its loss-aware aftermath")
 var final_survivor=survivor_dialogue.resolve(packed_story.chapters[11].closing,["rhea","noor","cassian","oren"])
 assert(final_survivor.size()==2 and final_survivor.all(func(line):return line.speaker=="lyra"),"Packaged finale remains coherent after severe attrition")
 var dialogue_art=load("res://scripts/dialogue_backdrop.gd")
 for chapter in range(12):
  for kind in ["opening","closing"]:
   var picture=dialogue_art.texture_for(chapter,kind)
   assert(picture.atlas.get_width()==1536 and picture.region.size.x>=764 and picture.filter_clip,"Release includes all twelve dialogue locations and closing variants")
 for job in app.CLASSES:assert(app.map_catalog.assets.has("unit."+job.to_lower()),"Release initializes every fallback class without relying on assertions")
 assert(app.map_catalog.recruit_errors.is_empty(),"Packaged recruit artwork validates")
 assert(app.map_catalog.enemy_errors.is_empty(),"Packaged enemy artwork validates")
 for recruit in app.game.roster:
  var wounded=recruit.duplicate(true);wounded.team="player";wounded.acted=true;wounded.hp=0;wounded.downed=true;wounded.bleed_turns=1
  var wounded_actor=load("res://scripts/campaign_map_unit.gd").new();app.pieces.add_child(wounded_actor);wounded_actor.configure(app.map_catalog,wounded);wounded_actor._process(.8)
  assert(wounded_actor.player.state=="hurt" and wounded_actor.player.complete and wounded_actor.sprite.modulate.a==1 and wounded_actor.rescue_marker.get_meta("turns")==1,"Packaged downed recruits hold their visible wounded artwork and countdown")
  wounded_actor.face_toward(Vector2i.LEFT,Vector2i.ZERO);assert(wounded_actor.player.state=="hurt" and wounded_actor.player.complete)
  wounded_actor.queue_free();await process_frame
 assert(app.fighters.enemy_looks.size()==8 and app.fighters.face_atlas.resource_path.ends_with("face-features-v2.png"),"Release includes the matching enemy profiles and current painted facial features")
 assert(app.fighters.EquipmentVisuals.profiles.size()==app.game.equipment.size() and app.fighters.EquipmentVisuals.profiles.war_hammer.shape=="hammer","Release includes every equipped item appearance")
 for item in app.game.equipment:
  var item_icon=app.WeaponIcons.get_item_icon(item.id,item.kind)
  assert(item_icon!=null and item_icon.get_size()==Vector2(48,48) and item_icon.resource_path=="res://assets/ui/items/"+item.id+".svg","Packed resource catalog retains every individual inventory icon")
 for tile in [0,2]:
  var terrain=app.scenery.ground_material(tile)
  assert(terrain.get_shader_parameter("wang_enabled")==true and terrain.get_shader_parameter("natural_surface")== (0 if tile==0 else 1),"Packaged combat uses the same varied grass and dirt as the tactical map")
  assert(terrain.get_shader_parameter("wang_texture")==wang,"Packaged standalone terrain binds the complete edge-matched atlas")
 assert(app.interface_audio.streams.size()==3 and app.interface_audio.streams.confirm.get_length()>.14,"Release includes the original interface cues")
 assert(app.travel_audio.streams.size()==6 and app.travel_audio.streams.hoof_wood.get_length()>.14,"Release includes all original terrain foot/hoof contacts")
 for element in ["ember","gale","thunder"]:assert(app.sfx_streams["impact_"+element].get_length()>.37,"Packaged spells include their elemental contact sound")
 for family in ["sword","axe","lance","bow","ember","gale","thunder"]:assert(app.sfx_streams["release_"+family].get_length()>.13,"Packaged combat includes every original weapon/element release cue")
 for job in app.CLASSES:assert(app.map_catalog.assets.has("enemy."+job.to_lower()),"Release includes every dedicated enemy class atlas")
 for chapter in [0,2,3,4,5,6,7,8,9,10,11]:
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle();await process_frame
  var theme={2:"greywood",3:"abbey",5:"glass_harbor",6:"windscar",7:"aqueduct",8:"starfall",10:"crown",11:"sun_engine"}.get(chapter,["standard","road","dawnless"][chapter/4])
  assert(app.score_director.current_id==theme,"Export includes every chapter's assigned score pair")
  assert(app.unit_nodes.size()==app.game.units.size(),"Packaged maps instantiate every living actor")
  for y in range(app.game.board_size().y):
   for x in range(app.game.board_size().x):
    var cell=Vector2i(x,y)
    if app.map_height(cell)==0:continue
    for offset in [Vector3(-.49,0,0),Vector3(0,0,-.49)]:
     assert(app.map_tile_at(app.camera.unproject_position(app.map_position(cell)+offset))==cell,"Packaged pointer picking follows raised bridge and sanctuary edges")
  var commander=app.game.units.filter(func(unit):return unit.get("boss",false))[0]
  assert(app.unit_nodes[commander.id].has_node("CommanderInsignia") and app.portraits.get_unit_portrait(commander).atlas.get_width()==1254,"Release includes commander crowns and their separate portrait atlas")
  for actor in app.unit_nodes.values():assert(actor.sprite.texture!=null and actor.player.asset.clips.has("move"),"Packaged actors have atlas frames and animations")
 app.game.story_seen.append("opening_"+str(app.game.chapter));app.show_camp();await process_frame
 assert(app.ui.find_child("CompanyCards",true,false).get_child_count()==24 and app.ui.has_node("CouncilBackdrop"),"Release includes the complete portrait preparation roster and covered-scene suspension")
 for path in ["res://assets/art/class-sprites.png","res://assets/sprites/company-a.png",
              "res://assets/sprites/company-b.png","res://assets/sprites/company-c.png"]:
  assert(not ResourceLoader.exists(path),"Source-only sprite drafts stay outside the release")
 var history_state=app.game.save_data("camp").duplicate(true);var history_speed=app.preferences.values.text_speed
 app.preferences.values.text_speed=55
 app.show_dialogue([{"speaker":"lyra","text":"Only the revealed prefix belongs in history."},{"speaker":"oren","text":"This future line remains hidden."}],app.show_camp)
 app.dialogue_label.visible_characters=4;app.dialogue_reveal=4.0;app.show_dialogue_history()
 assert(app.dialogue_stage.history.entries==[{"speaker":"Lyra","text":"Only"}],"Packaged conversation history loads its UI and excludes unrevealed text")
 app._process(.5);assert(app.dialogue_reveal==4.0 and app.dialogue_index==0,"Packaged history pauses the real dialogue clock")
 app.dialogue_stage.close_history();app.finish_dialogue();app.preferences.values.text_speed=history_speed
 assert(app.game.save_data("camp")==history_state,"Packaged history returns without changing campaign data or RNG")
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
 app.show_source_model_view("enemy_duelist","tempered_sword",true);await process_frame
 var enemy_study=app.preview_actor;var enemy_identity=enemy_study.model.get_node("Identity")
 assert(app.preview_unit.team=="enemy" and enemy_study.model.get_meta("enemy_appearance")=="Duelist" and enemy_identity.head.get_meta("enemy_headgear")=="Duelist")
 assert(enemy_identity.cloak.cloth.material_override.get_shader_parameter("cape_mark")==app.fighters.IMPERIAL_CAPE,"Packaged enemy study keeps the imperial insignia")
 var enemy_target=app.ui.find_child("StudyTarget",true,false);enemy_target.select(1);enemy_target.item_selected.emit(1);await app.stage.get_node("PreviewActionPlayer").finished
 var enemy_edge=enemy_study.weapon_trail_points();var enemy_point=enemy_study.get_node("StudyContactTarget").global_position
 assert(Geometry3D.get_closest_point_to_segment(enemy_point,enemy_edge[0],enemy_edge[1]).distance_to(enemy_point)<.006)
 app.close_model_view();await process_frame
 var support_curves=JSON.parse_string(FileAccess.get_file_as_string("res://data/authored_fall_fit.json"))
 assert(support_curves.size()==37,"Packaged full-outfit support includes 23 infantry recruits, seven enemy classes and their separately fitted promotions")
 for support_key in ["promotion:dax:stormbreaker","promotion:dax:trailguard","promotion:hale:stormbreaker","recruit:maelin","promotion:maelin:luminary","promotion:maelin:wayfarer"]:
  assert(support_curves.has(support_key))
 for key in ["recruit:tovin","promotion:tovin:sharpshooter","promotion:tovin:pathfinder"]:
  assert(support_curves.has(key))
 var enemy_metadata=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 for job in ["Vanguard","Knight","Corsair","Ranger","Arcanist","Warden","Rider"]:
  var key="enemy_"+job.to_lower();app.show_source_model_view(key,enemy_metadata[key].supported_items[0],true);await process_frame
  var actor=app.preview_actor;var appearance=actor.model.get_node("Identity")
  assert(actor is Imported and app.preview_unit.team=="enemy" and actor.model.get_meta("enemy_appearance")==job)
  assert(appearance.cloak.cloth.material_override.get_shader_parameter("cape_mark")==app.fighters.IMPERIAL_CAPE)
  if job=="Knight":assert(not appearance.head.get_node("PaintedFace").visible and appearance.hair_motion.root==null)
  if job=="Rider":assert(actor is Rider and actor.model.get_node("Mount").enemy_colors)
  else:
   var fall=actor.player.get_animation("Death01");var track=fall.find_track(NodePath("Armature/Skeleton3D:root"),Animation.TYPE_POSITION_3D)
   assert(track>=0 and fall.track_get_key_count(track)==support_curves["enemy:"+job].size(),"Packaged enemy fall uses its private fitted root track")
  await actor.pose("down",.02).finished;assert(appearance.blink.closed)
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
  assert(bow.equipped=="longbow" and bow.arms.model==ranger.model and bow.arms.chain.size()==8 and ["BowIdle","BowDraw","BowRelease","BowRecover","BowFinish"].all(func(clip):return ranger.player.has_animation(clip)),"Packaged Ranger retains both-arm fitting and draw, release, recovery and finishing clips")
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
 for pair in [["knight_female","petra"],["knight_male","oren"],["rider_female","una"],["rider_male","bram"]]:
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
 for pair in [["rider_female","una"],["rider_male","bram"]]:
  app.show_source_model_view(pair[0],"riders_bane",true);await process_frame
  var rider=app.preview_actor;assert(rider is Rider and rider.mount.configured)
  var rig=rider.model.get_node("Rig/Armature/Skeleton3D");var grip=rig.get_node("WeaponHand/Grip")
  assert(grip.arms.chain.size()==14 and rider.player.has_animation("RiderDown") and rider.model.get_node("Identity").armor.anchors.size()==5)
  var point=rider.to_global(Vector3(0,1.1,-2.1));rider.aim_at(point)
  await rider.pose("windup",.02).finished;await rider.pose("strike",.02).finished
  assert(rider.weapon_trail_points()[1].distance_to(point)<.005,"Packaged seated lance reaches an infantry opponent")
  var contacts=[];rider.travel_contact.connect(func(index):contacts.append(index))
  await rider.pose("advance",.02).finished
  for step in range(72):
   rider.position-=rider.global_basis.z*(1.8/72);rider.update_locomotion()
   assert(absf(rider.ground_contact_position().y-rider.global_position.y)<.0001)
  assert(contacts==[0,1],"Packaged horse uses the distance-driven hoof cadence")
  await rider.pose("down",.02).finished
  assert(rider.mount.gait_weight==0 and Vertices.minimum(rider,Vertices.prepare(rider))>rider.global_position.y-.0001)
  assert(rider.socket_position("rein_grip").distance_to(rig.get_node("ReinHand").to_global(grip.rein_pad))<.0001)
  app.close_model_view();await process_frame
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
 app.ui.find_child("DebugEnemyModels",true,false).button_pressed=true
 var packaged_enemy=app.game.roster[0].duplicate(true);packaged_enemy.id="packaged_enemy";packaged_enemy.team="enemy"
 var enemy_model=app.make_fighter(packaged_enemy,Vector3.ZERO);assert(enemy_model is Imported and enemy_model.model.get_meta("enemy_appearance")=="Vanguard")
 enemy_model.queue_free();await process_frame
 app.ui.find_child("DebugEnemyModels",true,false).button_pressed=false
 app.show_debug_report();assert(JSON.parse_string(app.ui.find_child("DebugReport",true,false).text).debug,"Packaged debug reports contain the current experiment record")
 assert(app.ui.find_child("DebugReportPosition",true,false).text.contains("Permadeath ") and app.ui.find_child("DebugReportSummary",true,false).text.contains("Pressure: %d"%app.game.trials.pressure),"Packed reports include the human-readable experiment summary")
 assert(app.game.trials.scenes.size()==12 and app.game.trials.scenes.has("volunteer_maelin") and app.game.trials.scenes.has("volunteer_tovin"),
  "Release includes relief, retreat, volunteer and memorial story scenes")
 assert(app.persist_campaign("battle") and FileAccess.file_exists(app.save_path+".debug"),"Packaged debug actions save separately")
 app.debug_session.end(app.game);app.preferences.values.character_models="revised"
 for id in ["lyra","nell","silas","yuna","tarin","vela","noor","cassian","rhea","ivo","esme","galen","mara","dax","hale","sera","ari","faye","oren","petra","rook","bram","una","elian"]:
  var campaign_recruit=app.game.roster.filter(func(value):return value.id==id)[0].duplicate(true);campaign_recruit.team="player";campaign_recruit.item="iron_sword" if campaign_recruit.weapon=="sword" else "iron_axe" if campaign_recruit.weapon=="axe" else "javelin" if campaign_recruit.weapon=="lance" else "scout_bow" if campaign_recruit.weapon=="bow" else "field_staff" if campaign_recruit.weapon=="staff" else "ember"
  var campaign_model=app.make_fighter(campaign_recruit,Vector3.ZERO)
  assert(not app.debug_session.active and campaign_model is Imported and campaign_model.model.get_meta("character_identity")==id,"Packaged appearance preference works for every revised recruit in the ordinary campaign")
  campaign_model.queue_free();await process_frame
 for key in enemy_metadata:
  var spec=enemy_metadata[key]
  if not spec.has("study_enemy_class"):continue
  var enemy=app.game.roster.filter(func(unit):return unit.id==spec.study_character)[0].duplicate(true);enemy.id="packaged_enemy";enemy.team="enemy";enemy.job=spec.study_enemy_class;enemy.item=spec.supported_items[0]
  var actor=app.make_fighter(enemy,Vector3.ZERO);assert(actor is Imported and actor.model.get_meta("enemy_appearance")==enemy.job,"Packaged ordinary campaign preference selects all eight enemy families")
  actor.queue_free();await process_frame
  enemy.boss=true;actor=app.make_fighter(enemy,Vector3.ZERO);assert(not actor is Imported,"Packaged preference preserves boss appearances")
  actor.queue_free();await process_frame
 for identity in ["nell","silas","lyra","cassian","enemy_Vanguard","enemy_Duelist"]:
  var enemy=identity.begins_with("enemy_")
  var unit=app.game.roster.filter(func(value):return value.id==("lyra" if enemy else identity))[0].duplicate(true)
  unit.item="estoc";unit.team="enemy" if enemy else "player"
  if enemy:unit.id="packaged_estoc";unit.job=identity.trim_prefix("enemy_")
  var actor=app.make_fighter(unit,Vector3.ZERO)
  assert(actor is Imported and actor.contact==null and actor.point_trail_width==.032,"Export selects the fitted estoc on both bodies and enemy sword classes")
  var target=Vector3(0,1.1,-1.4);actor.aim_at(target)
  await actor.pose("windup",.02).finished;await actor.pose("strike",.02).finished
  assert(actor.sockets.trail_tip.global_position.distance_to(target)<.006,"Packaged estoc meets its exact aim target")
  var edge=actor.weapon_trail_points();assert(is_equal_approx(edge[0].distance_to(edge[1]),.032))
  await actor.pose("down",.02).finished;await actor.pose("idle",.18).finished
  var rig=actor.model.get_node("Rig/Armature/Skeleton3D")
  assert(rig.get_bone_pose_position(rig.find_bone("root")).is_equal_approx(Vector3.ZERO),"Packaged standing pose clears fitted fall support")
  actor.queue_free();await process_frame
 app.stage.show() # Geometry sampling skips meshes hidden by the preceding debug report.
 var fitted_promotions={"Vanguard":["standard_bearer","dawnblade"],"Duelist":["sword_dancer","oathkeeper"],"Ranger":["sharpshooter","pathfinder"],"Corsair":["stormbreaker","trailguard"],"Knight":["bastion","sentinel"],"Arcanist":["star_sage","spellwarden"],"Warden":["luminary","wayfarer"],"Rider":["outrider","iron_lancer"]}
 for id in ["lyra","cassian","rhea","nell","silas","yuna","sera","ari","faye","mara","dax","hale","petra","oren","rook","tarin","vela","noor","ivo","esme","galen","una","bram","elian"]:
  var promotion_recruit=app.game.roster.filter(func(value):return value.id==id)[0]
  for promotion in fitted_promotions[promotion_recruit.job]:
   var unit=promotion_recruit.duplicate(true);unit.team="player";unit.promotion=promotion;unit.item="longbow" if unit.weapon=="bow" else "war_hammer" if unit.weapon=="axe" else "javelin" if unit.weapon=="lance" else "thunder" if unit.weapon=="magic" else "beacon_staff" if unit.weapon=="staff" else "estoc"
   var actor=app.make_fighter(unit,Vector3.ZERO)
   assert(actor is Imported and actor.get_meta("promotion_look")==promotion,"Packaged fitted promotions retain their costumes")
   var packed_face=actor.model.get_node("Identity").blink.surface
   assert(packed_face.get_shader_parameter("personal_iris")== (id in ["lyra","tarin","sera","una","vela","silas","elian"]),"Packed revised palettes remain private to explicitly corrected recruits")
   assert(packed_face.get_shader_parameter("warm_iris")== (id in ["sera","vela"]),"Packed Sera and Vela keep the measured brown-source mask private")
   if id in ["lyra","tarin","sera","una","vela","silas","elian"]:assert(packed_face.get_shader_parameter("iris_tint").is_equal_approx(Color(app.fighters.profiles[id].appearance.iris_color)))
   var outfit=actor.model.get_node("Identity").promotion
   assert(actor.poses.critical_hit.to==.1 and actor.poses.hit.to>.3,"All packed promoted fighters retain held critical recoil and unchanged ordinary reactions")
   var look=load("res://scripts/promotion_costume.gd").looks[promotion]
   assert(outfit.panels.size()==((2 if look.has("tabard") else 0)+(4 if look.has("sash") else 0)+(6 if look.has("stole") else 0)))
   for panel in outfit.panels:assert(panel.skin.get_bind_count()==(6 if panel.get_meta("promotion_stole",false) else 5) and panel.material_override.next_pass!=null)
   if unit.weapon in ["sword","axe"]:
    assert(actor.poses.has("victory_flourish"),"Packed sword/axe adapter contributes its private finishing clip")
    var promotion_finish=actor.model.get_node("Rig/Armature/Skeleton3D/"+("AxeFinish" if unit.weapon=="axe" else "SwordFinish"))
    await actor.finish_flourish(.02).finished;assert(promotion_finish.active and is_zero_approx(promotion_finish.lift))
    await actor.pose("victory",.02).finished;assert(not promotion_finish.active)
   if unit.weapon=="bow":
    assert(actor.poses.has("victory_flourish"),"Packed Ranger adapter contributes its private finishing clip")
    var finishing_bow=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow")
    await actor.finish_flourish(.02).finished
    assert(is_zero_approx(finishing_bow.finish) and finishing_bow.projectile_spent and not finishing_bow.get_node("Weapon/NockedArrow").visible)
    await actor.pose("victory",.02).finished;assert(finishing_bow.projectile_spent and not finishing_bow.get_node("Weapon/NockedArrow").visible)
    await actor.pose("idle",.02).finished;assert(not finishing_bow.projectile_spent and finishing_bow.get_node("Weapon/NockedArrow").visible)
   var promotion_spacing=4.0 if unit.weapon=="bow" else actor.approach_spacing(unit.item)
   var target=Vector3(0,1.85,-promotion_spacing);actor.aim_at(target)
   var promotion_gaze_target=Marker3D.new();app.stage.add_child(promotion_gaze_target);promotion_gaze_target.position=Vector3(.5,2.4,-4)
   if unit.weapon in ["staff","lance"]:actor.face_opponent(promotion_gaze_target)
   await actor.pose("windup",.02).finished;await actor.pose("strike",.02).finished
   if unit.weapon=="bow":
    var bow=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow");assert(bow.projectile_spent and not bow.get_node("Weapon/NockedArrow").visible)
    await actor.pose("critical_windup",.02).finished
    var promotion_arrow=bow.get_node("Weapon/NockedArrow")
    assert(bow.critical_prepared and is_equal_approx(bow.draw_length(),.36) and (-promotion_arrow.global_basis.z.normalized()).dot((target-promotion_arrow.global_position).normalized())>.999999)
    await actor.pose("strike",.02).finished;assert(bow.projectile_spent and not promotion_arrow.visible)
    await actor.pose("windup",.02).finished;assert(not bow.critical_prepared and is_equal_approx(bow.draw_length(),.30))
   elif unit.weapon=="staff":
    var promotion_staff=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Staff");assert(promotion_staff.equipped=="beacon_staff")
    await actor.pose("cast_windup",.02).finished;await actor.pose("cast",.02).finished
    assert(actor.socket_position("projectile").distance_to(promotion_staff.get_node("Weapon").to_global(Vector3(0,.78,0)))<.001)
    assert(actor.model.get_node("Identity").gaze.modifier.active,"Packed healing keeps its recipient gaze")
   elif unit.weapon=="magic":
    assert(actor.to_local(actor.socket_position("projectile")).z<-.5,"Promoted caster extends the free casting palm")
    var promotion_folio=actor.model.get_node("Rig/Armature/Skeleton3D/BookHand/Folio")
    assert(promotion_folio.equipped=="thunder")
    var ordinary_palm=actor.socket_position("projectile")
    await actor.pose("critical_windup",.02).finished
    assert(promotion_folio.critical_prepared and actor.socket_position("projectile").y>ordinary_palm.y+.06)
    await actor.pose("strike",.02).finished
    assert(actor.player.assigned_animation=="CriticalSpellRelease" and actor.socket_position("projectile").distance_to(ordinary_palm)<.00001,"Packed critical cast returns to the ordinary launch point")
    await actor.pose("recover",.02).finished;assert(not promotion_folio.critical_prepared)
    assert(actor.poses.has("victory_flourish") and actor.player.get_animation("SpellFinish").length==actor.player.get_animation("Idle").length)
    await actor.finish_flourish(.02).finished
    assert(actor.player.assigned_animation=="SpellFinish" and not promotion_folio.critical_prepared,"Packed promoted Arcanists retain their private free-hand finish")
    await actor.pose("victory",.02).finished
    assert(actor.player.assigned_animation=="Idle" and not promotion_folio.critical_prepared)
   elif unit.weapon in ["sword","lance"]:assert(actor.sockets.trail_tip.global_position.distance_to(target)<.006)
   else:
    var promotion_edge=actor.weapon_trail_points();assert(Geometry3D.get_closest_point_to_segment(target,promotion_edge[0],promotion_edge[1]).distance_to(target)<.006)
   if unit.weapon=="sword":
    await actor.pose("critical_windup",.02).finished;await actor.pose("strike",.02).finished
    assert(actor.player.assigned_animation=="SwordCriticalAttack" and actor.sockets.trail_tip.global_position.distance_to(target)<.006,"Packed critical sword preparation preserves its exact strike target: %s %s %s gap %s"%[unit.id,promotion,actor.player.assigned_animation,actor.sockets.trail_tip.global_position.distance_to(target)])
   if unit.weapon=="axe":
    await actor.pose("critical_windup",.02).finished;await actor.pose("strike",.02).finished
    var critical_axe_edge=actor.weapon_trail_points()
    assert(actor.player.assigned_animation=="AxeCriticalAttack" and Geometry3D.get_closest_point_to_segment(target,critical_axe_edge[0],critical_axe_edge[1]).distance_to(target)<.006,"Packed Corsair critical preparation retains its actual target")
   if unit.weapon=="lance":
    await actor.pose("critical_windup",.02).finished
    assert(actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").critical_prepared)
    await actor.pose("strike",.02).finished
    assert(actor.sockets.trail_tip.global_position.distance_to(target)<.006,"Packed critical lance preparation preserves exact contact")
    await actor.pose("recover",.02).finished
    assert(not actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").critical_prepared)
    if unit.job=="Knight":
     var promotion_shield=actor.model.get_node("Rig/Armature/Skeleton3D/KnightShield/Plate")
     var promotion_rim=promotion_shield.get_node("PromotionShieldRim" if promotion=="bastion" else "ShieldTrim")
     assert(promotion_rim.scale.is_equal_approx(Vector3.ONE*.83))
     assert(promotion_rim.mesh==(load("res://scripts/knight_shield.gd").promotion_trim_mesh() if promotion=="bastion" else load("res://scripts/knight_shield.gd").trim_mesh()))
    actor.aim_at(Vector3(0,1.85,-4))
    await actor.pose("throw_windup",.02).finished;await actor.pose("throw",.02).finished
    assert(not actor.projectile_source().visible,"Packed promoted javelin leaves the fitted hand")
    var ordinary_launch=actor.projectile_source().global_transform
    await actor.pose("critical_throw_windup",.02).finished
    assert(actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").critical_throw_prepared and actor.projectile_source().visible)
    await actor.pose("throw",.02).finished
    assert(not actor.projectile_source().visible and actor.projectile_source().global_transform.is_equal_approx(ordinary_launch),"Packed critical javelin returns to the ordinary release transform")
    assert(actor.model.get_node("Identity").gaze.modifier.active,"Packed critical throwing keeps its opponent gaze")
    assert(actor.poses.has("victory_flourish"))
    await actor.finish_flourish(.02).finished
    var finish_grip=actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip")
    assert(actor.player.assigned_animation=="LanceFinish" and actor.projectile_source().visible and not finish_grip.throwing and is_zero_approx(finish_grip.finish),"Packed promoted knights and riders settle the spear after its recovery")
    await actor.pose("victory",.02).finished
    assert(is_zero_approx(finish_grip.finish) and actor.projectile_source().visible)
    await actor.pose("idle").finished
    assert(not actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").critical_throw_prepared)
   if unit.weapon in ["axe","lance","magic","staff"]:
    var promotion_identity=actor.model.get_node("Identity")
    actor.clear_aim();await actor.pose("down",.02).finished
    promotion_identity.hair_motion.update(0,"down",2)
    var promotion_cache=Vertices.prepare(actor).filter(func(entry):
     var material=entry[0].get_active_material(0)
     return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
    assert(not promotion_cache.is_empty(),"Packed geometry fixture is visible to the CPU sampler")
    var promotion_mapping=actor.poses.down
    for fraction in [0.0,.39,.46,.52,.75,1.0]:
     actor.player.stop();actor.player.play(promotion_mapping.clip,0);actor.player.seek(lerpf(promotion_mapping.from,promotion_mapping.to,fraction),true,true);actor.player.pause();actor.refresh_skeleton()
     assert(Vertices.minimum(actor,promotion_cache)-actor.global_position.y>(-.0001 if actor is Rider else .01),"Packaged promoted bodies and mounted hooves retain their fitted floor support")
    await actor.pose("idle").finished
    var promotion_rig=actor.model.get_node("Rig/Armature/Skeleton3D");assert(promotion_rig.get_bone_pose_position(promotion_rig.find_bone("root")).is_equal_approx(Vector3.ZERO))
   promotion_gaze_target.queue_free();actor.queue_free();await process_frame
 var commander_rules=load("res://scripts/rules.gd").new()
 for chapter in range(12):
  commander_rules.chapter=chapter;commander_rules.start_battle()
  var unit=commander_rules.living("enemy").filter(func(value):return value.get("boss",false))[0]
  var profile=load("res://scripts/commanders.gd").profile(unit);var actor=app.make_fighter(unit,Vector3.ZERO)
  assert(actor is Imported and actor.get_meta("commander")==profile.id,"Release selects all twelve revised commanders")
  assert(actor.poses.critical_hit.to==.1,"All packed commanders retain the revised critical reaction")
  assert(actor.get_meta("costume_colors").cloth==Color(profile.appearance.cloth) and actor.get_meta("costume_colors").cape==Color(profile.appearance.cape))
  if profile.appearance.has("circlet"):
   var color=Color(profile.appearance.circlet)
   assert(actor.model.get_node("Identity").head.find_children("*","MeshInstance3D",true,false).any(func(mesh):return mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color==color),"Packaged commander retains its individual jewel")
  actor.queue_free();await process_frame
 app.debug_session.begin(app.game,"camp",true);app.options_return="camp";app.show_debug_encounters()
 var model_choice_state=app.game.save_data("camp").duplicate(true)
 app.ui.find_child("EncounterModels_current",true,false).pressed.emit()
 assert(app.debug_session.model_choice()=="current" and app.selected_model_builders().is_empty())
 app.ui.find_child("EncounterModels_revised",true,false).pressed.emit()
 assert(app.debug_session.model_choice()=="revised" and app.selected_model_builders().size()==9 and app.game.save_data("camp")==model_choice_state,"Packed encounter model choices affect all nine Debug presentation groups without changing the campaign")
 app.show_debug_tools("camp")
 app.ui.find_child("CommanderStudy",true,false).select(11);app.ui.find_child("ViewCommanderStudy",true,false).pressed.emit();await process_frame
 assert(app.preview_actor is Imported and app.preview_actor.get_meta("commander")=="vael","Packaged debug commander selector opens its own revised identity")
 app.close_model_view();app.show_source_model_view("female","estoc",true);await process_frame
 var export_choice=app.ui.find_child("PreviewAction",true,false);var export_actions=app.stage.get_node("PreviewActionPlayer");var export_keys=[]
 for index in range(export_choice.item_count):export_keys.append(export_choice.get_item_metadata(index))
 assert("critical_strike" in export_keys and "victory_flourish" in export_keys,"Packed studies expose generated special actions")
 export_choice.select(export_keys.find("critical_strike"));export_choice.item_selected.emit(export_choice.selected);await export_actions.finished
 assert(app.preview_actor.pose_name=="strike" and app.preview_actor.player.assigned_animation=="SwordCriticalAttack","Packed critical preview replays the actual preparation and strike")
 app.close_model_view();app.show_source_model_view("ranger_female","longbow",true);await process_frame
 var ranger_choice=app.ui.find_child("PreviewAction",true,false);var ranger_actions=app.stage.get_node("PreviewActionPlayer")
 for index in range(ranger_choice.item_count):
  if ranger_choice.get_item_metadata(index)=="critical_strike":ranger_choice.select(index);break
 assert(ranger_choice.get_item_metadata(ranger_choice.selected)=="critical_strike")
 var ranger_target=app.ui.find_child("StudyTarget",true,false);assert(ranger_target!=null)
 ranger_target.select(2);ranger_target.item_selected.emit(2);await ranger_actions.finished
 var ranger_bow=app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Bow")
 assert(ranger_bow.critical_prepared and ranger_bow.projectile_spent and ranger_bow.arms.has_aim,"Packaged Ranger study preserves critical selection and aims at the mounted target")
 app.close_model_view();app.show_source_model_view("knight_female","javelin",true);await process_frame
 var throw_choice=app.ui.find_child("PreviewAction",true,false);var throw_actions=app.stage.get_node("PreviewActionPlayer")
 for index in range(throw_choice.item_count):
  if throw_choice.get_item_metadata(index)=="critical_throw":throw_choice.select(index);break
 assert(throw_choice.get_item_metadata(throw_choice.selected)=="critical_throw")
 var throw_target=app.ui.find_child("StudyTarget",true,false);throw_target.select(2);throw_target.item_selected.emit(2);await throw_actions.finished
 assert(app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/WeaponHand/Grip").critical_throw_prepared and not app.preview_actor.projectile_source().visible and is_equal_approx(absf(app.preview_actor.get_node("StudyContactTarget").position.z),4.0),"Packaged critical-throw selection retains ranged target and releases the spear")
 assert(app.preview_actor.model.get_node("Identity").gaze.modifier.active,"Packed target selector drives real throwing gaze")
 app.close_model_view();app.show_source_model_view("warden_female","beacon_staff",true);await process_frame
 var healing_choice=app.ui.find_child("PreviewAction",true,false);var healing_actions=app.stage.get_node("PreviewActionPlayer")
 var healing_target=app.ui.find_child("StudyTarget",true,false);assert(healing_target!=null and healing_target.get_item_text(2)=="Target: mounted ally")
 healing_target.select(2);healing_target.item_selected.emit(2);await healing_actions.finished
 assert(healing_choice.get_item_metadata(healing_choice.selected)=="cast" and app.preview_actor.pose_name=="cast" and app.preview_actor.model.get_node("Identity").gaze.modifier.active,"Packed healing target plays the actual cast with recipient attention")
 healing_target.select(0);healing_target.item_selected.emit(0);await healing_actions.finished
 assert(not app.preview_actor.model.get_node("Identity").gaze.modifier.active,"Packed target clearing releases attention")
 app.close_model_view();app.show_source_model_view("caster_female","thunder",true);await process_frame
 var cast_choice=app.ui.find_child("PreviewAction",true,false);var cast_actions=app.stage.get_node("PreviewActionPlayer")
 for index in range(cast_choice.item_count):
  if cast_choice.get_item_metadata(index)=="critical_strike":cast_choice.select(index);break
 assert(cast_choice.get_item_metadata(cast_choice.selected)=="critical_strike")
 cast_choice.item_selected.emit(cast_choice.selected);await cast_actions.finished
 assert(app.preview_actor.player.assigned_animation=="CriticalSpellRelease" and app.preview_actor.model.get_node("Rig/Armature/Skeleton3D/BookHand/Folio").critical_prepared)
 app.close_model_view();app.debug_session.end(app.game)
 app.preferences.values.character_models="revised";app.game.chapter=0;app.game.start_battle();app.make_map();app.show_battle()
 assert(app.debug_vanguard.models.scene_cache.size()>0 and app.debug_knight.models.scene_cache.size()>0 and app.revised_enemies.models.scene_cache.size()>0,"Packaged battle setup retains chapter model sources before combat")
 var stage_a=app.game.living("player")[0];var stage_b=app.game.living("enemy")[0];stage_a.x=8;stage_a.y=4;stage_b.x=9;stage_b.y=4
 app.map_step_feedback(stage_a,app.game.pos(stage_a),Vector2i.RIGHT,1)
 var map_dust=app.pieces.get_children().filter(func(node):return node.get_script()==load("res://scripts/combat_dust.gd"))[0]
 assert(map_dust.scale.is_equal_approx(Vector3.ONE*.55) and map_dust.global_position==app.map_position(app.game.pos(stage_a)) and map_dust.puffs.size()==2,"Packed map contact uses the smaller grounded infantry accent")
 var map_dust_reference=weakref(map_dust);map_dust._process(.31);await process_frame
 assert(map_dust_reference.get_ref()==null,"Packed map contact releases after its fade")
 var entry_nodes=[0];var count_entry=func(_node):entry_nodes[0]+=1
 app.stage.child_entered_tree.connect(count_entry)
 var entry_state=app.game.save_data("battle").duplicate(true);var entry_camera=app.map_navigation.capture_view()
 var zoom_figure=app.unit_nodes[stage_a.id];var initial_sprite_height=zoom_figure.screen_bounds(app.camera).size.y
 var packed_push=app.map_navigation.approach_combat(zoom_figure.position);packed_push.pause()
 var zoom_veil=load("res://scripts/combat_transition.gd").new();zoom_veil.configure(app.ui);var packed_fade=zoom_veil.conceal();packed_fade.pause()
 packed_push.custom_step(.42*.76);packed_fade.custom_step(.42*.76)
 assert(is_equal_approx(zoom_veil.cover_alpha(),.5) and zoom_figure.screen_bounds(app.camera).size.y>=initial_sprite_height*2.5,"Packed map sprites enlarge before the covering veil hides the combat transition")
 var packed_return=app.map_navigation.return_from_combat(app.map_navigation.capture_view(),entry_camera);packed_return.pause();packed_return.custom_step(.251);app.map_navigation.stop();zoom_veil.free()
 assert(app.map_navigation.capture_view()==entry_camera and app.game.save_data("battle")==entry_state)
 skip_packed_opening(app)
 await app.cinematic(stage_a,stage_b,[{"actor":stage_a.id,"target":stage_b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{stage_a.id:20,stage_b.id:20})
 await process_frame;await process_frame;app.stage.child_entered_tree.disconnect(count_entry)
 assert(entry_nodes[0]==0 and app.game.save_data("battle")==entry_state and app.map_navigation.capture_view()==entry_camera,"Packaged opening Skip returns without constructing an arena or changing resolved state")
 assert(app.markers.visible and app.unit_nodes.values().all(func(actor):return actor.tactical_details_visible and actor.health.visible),"Packaged Skip restores tactical details with map control")
 await app.cinematic(stage_a,stage_b,[{"actor":stage_a.id,"target":stage_b.id,"damage":1,"remaining":19,"hit":true,"crit":false}],{stage_a.id:20,stage_b.id:20})
 assert(not app.stage.visible and app.stage.process_mode==Node.PROCESS_MODE_DISABLED,"Packaged combat suspends its hidden arena after returning to the map")
 var hidden_actors=app.stage.get_children().filter(func(node):return node is Imported)
 assert(hidden_actors[0].poses.critical_hit.to==.1 and hidden_actors[0].poses.hit.to>.3,"Packaged revised swords retain distinct held-critical and ordinary reaction intervals")
 assert(hidden_actors.size()==2 and hidden_actors.all(func(actor):return not actor.player.can_process()),"Packaged hidden animations inherit the stage suspension")
 app.show_model_view(stage_a);await app.preview_actor.pose("windup",.02).finished
 assert(app.preview_actor.player.can_process(),"Packaged outfit preview resumes animation after a suspended battle")
 app.close_model_view();app.debug_session.begin(app.game,"battle",true);app.show_debug_encounters()
 var recruit_choice=app.ui.find_child("EncounterRecruit",true,false);assert(recruit_choice.item_count==24)
 for index in recruit_choice.item_count:
  if recruit_choice.get_item_metadata(index)=="galen":recruit_choice.select(index);recruit_choice.item_selected.emit(index);break
 var training_choice=app.ui.find_child("EncounterTraining",true,false);assert(training_choice.item_count==3)
 training_choice.select(2);training_choice.item_selected.emit(2)
 var equipment_choice=app.ui.find_child("EncounterEquipment",true,false)
 for index in equipment_choice.item_count:
  if equipment_choice.get_item_metadata(index)=="beacon_staff":equipment_choice.select(index);equipment_choice.item_selected.emit(index);break
 assert(equipment_choice.icon==app.WeaponIcons.get_item_icon("beacon_staff") and equipment_choice.get_popup().get_item_icon(equipment_choice.selected)==equipment_choice.icon,"Packed equipment picker retains matching selected and popup artwork")
 var battlefield_choice=app.ui.find_child("EncounterBattlefield",true,false)
 assert(battlefield_choice.item_count==13 and battlefield_choice.is_item_disabled(1) and not battlefield_choice.is_item_disabled(10))
 battlefield_choice.select(10);battlefield_choice.item_selected.emit(10)
 app.ui.find_child("StageRecruitEncounter",true,false).pressed.emit();await process_frame;await process_frame
 assert(app.game.chapter==9,"Packed battlefield selection reaches its chosen chapter through the actual setup control")
 assert(app.screen=="battle" and app.selected.id=="galen" and app.selected.promotion=="wayfarer" and app.game.can_heal(app.selected,app.game.at(app.cursor_tile)) and app.selected.item=="beacon_staff" and app.game.distance(app.selected,app.game.at(app.cursor_tile))==2,"Packed custom selector enters an actual promoted ranged healing encounter")
 app.game.death_door=true;app.preferences.values.combat="map";app.preferences.values.auto_end=false
 var packed_patient=app.game.at(app.cursor_tile);packed_patient.hp=0;app.game.DeathDoor.fall(app.game,packed_patient);app.refresh_pieces()
 app.click_tile(app.game.pos(packed_patient));assert(app.busy and packed_patient.hp>0 and packed_patient.acted)
 var saw_revival=false
 while app.busy:
  await process_frame
  var cue=app.ui.get_node_or_null("MapRecoveryCue")
  if cue!=null:saw_revival=true;assert(cue.text.begins_with("Revived · +"))
 assert(saw_revival and not app.game.DeathDoor.downed(packed_patient),"Packed actual ranged healing identifies a successful spent revival")
 app.game.permadeath=true;app.game.trials.flags.death_legacies=true
 for unit in app.game.units:
  if unit.id in ["oren","sera","ivo"]:unit.hp=0
 app.game.commit_casualties();assert(app.game.trials.credits==3)
 app.show_campaign_trials()
 for stock in app.game.trials.LEGACY_STOCK:
  var item=app.game.equipment.filter(func(entry):return entry.id==stock.id)[0]
  var stock_button=app.ui.find_child("LegacyStock_"+stock.id,true,false)
  assert(stock_button.icon==app.WeaponIcons.get_item_icon(stock.id),"Packed legacy stock uses the actual item artwork")
  if int(item.unlock)<=app.game.chapter:
   assert(not app.game.trials.can_buy(app.game,stock.id) and not app.game.trials.buy(app.game,stock.id))
   assert(stock_button.disabled and stock_button.text.begins_with("Available in arsenal · "),"Packed shop does not sell normally unlocked equipment for legacy credits")
  else:assert(app.game.trials.can_buy(app.game,stock.id) and not stock_button.disabled,"Packed late legacy gear remains available before its ordinary unlock")
 assert(app.game.trials.credits==3)
 app.ui.find_child("LegacyStock_vigil_staff",true,false).pressed.emit();await process_frame;await process_frame
 var late_healer=app.game.roster.filter(func(unit):return unit.id=="galen")[0]
 assert(app.game.trials.credits==1 and "vigil_staff" in app.game.trials.purchases and app.game.equip(late_healer,"vigil_staff"),"Packed late stock purchases and equips before its ordinary chapter unlock")
 var late_actor_unit=late_healer.duplicate(true);late_actor_unit.team="player"
 var late_actor=app.make_fighter(late_actor_unit,Vector3.ZERO)
 assert(late_actor is Imported and late_actor.model.get_meta("character_identity")=="galen" and late_actor.find_children("*","Node3D",true,false).any(func(node):return node.get_meta("equipment","")=="vigil_staff"),"Packed revised healer retains the new fitted staff without fallback")
 late_actor.queue_free();await process_frame
 var arsenal_state=app.game.save_data("battle").duplicate(true)
 app.show_equipment(late_healer);await process_frame;await process_frame
 assert(app.ui.find_child("WeaponIcon",true,false).texture==app.WeaponIcons.get_item_icon("vigil_staff"),"Packed arsenal summary uses the equipped legacy staff art")
 var beacon_comparison=app.ui.find_child("EquipmentComparison_beacon_staff",true,false)
 assert(beacon_comparison.text.contains("Healing %d (-6)"%(10+app.game.promotion_bonus(late_healer,"heal"))) and beacon_comparison.text.contains("Speed %d (+3)"%late_healer.speed),"Packed arsenal compares promoted healing and effective speed against the equipped staff")
 assert(app.game.save_data("battle")==arsenal_state,"Inspecting the packaged arsenal keeps the loadout and campaign untouched")
 app.show_debug_experiments();app.ui.find_child("StartExperiment_last_rescue",true,false).pressed.emit();await process_frame;await process_frame
 var rescue_patient=app.game.units.filter(func(unit):return unit.id=="oren")[0]
 var rescue_healer=app.game.units.filter(func(unit):return unit.id=="ivo")[0]
 var rescue_save=load("res://scripts/rules.gd").new()
 assert(app.screen=="battle" and app.game.DeathDoor.downed(rescue_patient) and rescue_patient.bleed_turns==1 and rescue_healer.acted and app.game.permadeath and app.game.action_saves,"Packed last-chance starter preserves its authored countdown and spent healer")
 assert(rescue_save.load_game(app.save_path+".debug")=="battle")
 var rescue_disk=JSON.parse_string(JSON.stringify(rescue_save.save_data("battle")));var rescue_live=JSON.parse_string(JSON.stringify(app.game.save_data("battle")))
 for key in rescue_live:
  if rescue_live[key]!=rescue_disk.get(key):print("RESCUE SAVE DIFF ",key," live=",rescue_live[key]," disk=",rescue_disk.get(key))
 assert(rescue_disk==rescue_live,"Packed rescue starter writes the complete temporary battle")
 app.show_campaign_rules();app.ui.find_child("Permadeath",true,false).button_pressed=true
 var campaign_settings=load("res://scripts/campaign_settings.gd")
 for setting in campaign_settings.SWITCHES:app.ui.find_child(setting.key,true,false).button_pressed=true
 app.ui.find_children("*","Button",true,false).filter(func(button):return button.text=="Begin the chronicle")[0].pressed.emit()
 assert(campaign_settings.snapshot(app.game).values().all(func(value):return value) and app.game.trials.pressure==0 and app.game.trials.credits==0,"Packed campaign creation applies all chosen rules to fresh consequences")
 app.finish_dialogue();app.deploy_company()
 while app.busy:
  var key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true;app._unhandled_input(key);await process_frame
 var creation_save=load("res://scripts/rules.gd").new()
 assert(creation_save.load_game(app.save_path+".debug")=="battle" and campaign_settings.snapshot(creation_save).values().all(func(value):return value),"Packed first-deployment checkpoint keeps every selected campaign rule")
 var fallen_patient=app.game.units.filter(func(unit):return unit.id=="oren")[0];var falling_figure=app.unit_nodes[fallen_patient.id]
 fallen_patient.hp=0;app.game.DeathDoor.fall(app.game,fallen_patient);var wounded_seen=[false];var map_contact_seen=[false]
 var watch_fall=func():
  var contact=app.pieces.get_node_or_null("MapImpact")
  if contact!=null:
   assert(contact.burst!=null and contact.find_children("*","Label3D",true,false).is_empty())
   assert(contact.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.material_override.no_depth_test and mesh.material_override.render_priority==3))
   map_contact_seen[0]=true
  if is_instance_valid(falling_figure) and not falling_figure.is_queued_for_deletion() and falling_figure.hp_ratio==0:
   assert(not falling_figure.departing and falling_figure.visible and falling_figure.downed and falling_figure.rescue_marker.get_meta("turns")==2,"Packed map contact retains the rescuable patient and countdown instead of fading")
   wounded_seen[0]=true
 process_frame.connect(watch_fall)
 await app.map_combat_feedback([{"actor":app.game.living("enemy")[0].id,"target":fallen_patient.id,"hit":true,"crit":false,"damage":1,"remaining":0}])
 process_frame.disconnect(watch_fall);assert(wounded_seen[0] and map_contact_seen[0] and app.pieces.get_node_or_null("MapImpact")==null)
 var map_miss=load("res://scripts/map_projectile.gd").new();app.pieces.add_child(map_miss)
 var map_flight=map_miss.fly(Vector3.ZERO,Vector3(2,0,0),"bow","",{},true)
 assert(is_equal_approx(map_miss.body.scale.x,.55),"Packed map arrows retain the sprite scale")
 for flight_mesh in map_miss.find_children("*","MeshInstance3D",true,false):
  assert(flight_mesh.material_override.no_depth_test and flight_mesh.material_override.render_priority==3,"Packed tactical projectiles follow the map overlay depth")
 var packed_flight_ref=weakref(map_miss)
 map_flight.pause();assert(map_flight.custom_step(.11) and not map_miss.is_queued_for_deletion(),"Packed misses remain in flight before contact")
 map_flight.custom_step(.02)
 assert(map_miss.is_queued_for_deletion(),"Packed missed-shot follow-through fits the pre-contact interval")
 await process_frame
 assert(packed_flight_ref.get_ref()==null,"Packed tactical flight releases after the pre-contact interval")
 var packed_healer=app.game.units.filter(func(unit):return unit.id=="ivo")[0]
 fallen_patient.hp=8;fallen_patient.downed=false;fallen_patient.acted=true
 var packed_recovery_seen=[false,false]
 var watch_recovery=func():
  var light=app.pieces.get_node_or_null("MapHeal")
  var figure=app.unit_nodes[fallen_patient.id]
  if light!=null and not light.has_arrived:
   assert(figure.hp_ratio==0 and app.ui.get_node_or_null("MapRecoveryCue")==null)
   packed_recovery_seen[0]=true
  if app.ui.get_node_or_null("MapRecoveryCue")!=null:
   assert(not figure.downed and figure.rescue_marker==null and is_equal_approx(figure.hp_ratio,8.0/fallen_patient.max_hp))
   packed_recovery_seen[1]=true
 process_frame.connect(watch_recovery)
 await app.map_heal_feedback(packed_healer,fallen_patient,8,true)
 process_frame.disconnect(watch_recovery);await process_frame
 assert(packed_recovery_seen.all(func(seen):return seen) and app.pieces.get_node_or_null("MapHeal")==null,"Packed map revival waits for staff light, clears wounded indicators and releases its effect")
 app.preferences.values.combat="all";app.debug_session.revised_knight=true
 var packed_rise_seen=[false,false];var packed_recovery_state=app.game.save_data("battle").duplicate(true)
 var watch_rise=func():
  if not app.stage.visible:return
  var directors=app.stage.get_children().filter(func(node):return node is Director)
  if directors.is_empty():return
  var recipient_actor=directors[0].subjects[1]
  assert(recipient_actor is Imported and recipient_actor.kind==fallen_patient.weapon)
  if recipient_actor.pose_name=="down":packed_rise_seen[0]=true
  elif recipient_actor.pose_name=="revive":
   var light=app.stage.get_node_or_null("CombatHeal")
   if light!=null:assert(light.has_arrived and light.recipient.get_ref()==recipient_actor);packed_rise_seen[1]=true
 process_frame.connect(watch_rise)
 await app.staff_healing(packed_healer,fallen_patient,8)
 process_frame.disconnect(watch_rise)
 assert(packed_rise_seen.all(func(seen):return seen) and app.game.save_data("battle")==packed_recovery_state,"Packed revised revival begins wounded, rises at staff arrival and preserves resolved campaign state")
 app.show_source_model_view("rider_female","javelin",true);await process_frame;await process_frame
 var revival_choice=app.ui.find_child("PreviewAction",true,false);var revival_index=-1
 for index in revival_choice.item_count:
  if revival_choice.get_item_metadata(index)=="revive":revival_index=index
 assert(revival_index>=0)
 var revival_preview=app.stage.get_node("PreviewActionPlayer");var preview_rise_seen=[false,false]
 var watch_preview_rise=func():
  if app.preview_actor.pose_name=="down" and revival_preview.pending.size()==2:preview_rise_seen[0]=true
  if app.preview_actor.pose_name=="revive":preview_rise_seen[1]=true
 process_frame.connect(watch_preview_rise)
 revival_choice.select(revival_index);revival_choice.item_selected.emit(revival_index);await revival_preview.finished
 process_frame.disconnect(watch_preview_rise)
 assert(preview_rise_seen.all(func(seen):return seen) and app.preview_actor.pose_name=="idle" and app.game.save_data("battle")==packed_recovery_state,"Packed Revival selector replays the wounded hold and rise without changing the campaign")
 app.close_model_view();await process_frame
 await Shutdown.dispose(app);await process_frame
 print("PASS: exported catalog, assigned scores, chapter scenes, sixteen promotion patterns, all forty-eight revised promotion outfits, licenses and credits")
 quit()
