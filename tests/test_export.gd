extends SceneTree
const Shutdown=preload("helpers/game_shutdown.gd")
# Run this external script against an exported PCK from a different working
# directory, so resource and text checks cannot silently use the source tree.
func _initialize():call_deferred("run")

func run():
 for path in ["res://assets/fonts/OFL.txt","res://assets/audio/VSCO-LICENSE.txt","res://assets/audio/VSCO-CREDITS.txt"]:
  assert(FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).length()>100,"Export includes font and instrument credits/licenses")
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
 await Shutdown.dispose(app);await process_frame
 print("PASS: exported catalog, all three act scores, chapter scenes, sixteen promotion costumes, licenses and credits")
 quit()
