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
 for job in app.CLASSES:assert(app.map_catalog.assets.has("unit."+job.to_lower()),"Release initializes every fallback class without relying on assertions")
 assert(app.map_catalog.recruit_errors.is_empty(),"Packaged recruit artwork validates")
 assert(app.map_catalog.enemy_errors.is_empty(),"Packaged enemy artwork validates")
 assert(app.fighters.enemy_looks.size()==8 and app.fighters.face_atlas.resource_path.ends_with("face-features-v2.png"),"Release includes the matching enemy profiles and current painted facial features")
 assert(app.interface_audio.streams.size()==3 and app.interface_audio.streams.confirm.get_length()>.14,"Release includes the original interface cues")
 for job in app.CLASSES:assert(app.map_catalog.assets.has("enemy."+job.to_lower()),"Release includes every dedicated enemy class atlas")
 for chapter in [0,4,8,11]:
  app.game.chapter=chapter;app.game.start_battle();app.make_map();app.show_battle();await process_frame
  assert(app.score_director.current_id==["standard","road","dawnless"][chapter/4],"Export includes every act-specific score pair")
  assert(app.unit_nodes.size()==app.game.units.size(),"Packaged maps instantiate every living actor")
  for actor in app.unit_nodes.values():assert(actor.sprite.texture!=null and actor.player.asset.clips.has("move"),"Packaged actors have atlas frames and animations")
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
  actor.queue_free();await process_frame
 await Shutdown.dispose(app);await process_frame
 print("PASS: exported catalog, all three act scores, chapter scenes, sixteen promotion costumes, licenses and credits")
 quit()
