extends "res://scripts/calibrate_authored_falls.gd"
# Offline only: --script scripts/calibrate_promotion_falls.gd -- OUTPUT.json CLASS
# Fit each supported promotion against complete rigid/body geometry. Merge the
# resulting keys into authored_fall_fit.json only after dense pose validation.
func run():
 var arguments=OS.get_cmdline_user_args()
 if arguments.size()!=2:push_error("Pass an output JSON path and base class after --");quit(1);return
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var output={}
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 for study in studies.values():
  if study.has("study_enemy_class") or study.has("mount"):continue
  var exemplar=rules.roster.filter(func(value):return value.id==study.study_character)[0]
  if exemplar.job!=arguments[1]:continue
  for id in study.get("campaign_characters",[study.study_character]):
   for path in rules.promotions.filter(func(value):return value.base==arguments[1]):
    var unit=rules.roster.filter(func(value):return value.id==id)[0].duplicate(true);unit.team="player";unit.promotion=path.id;unit.item=study.supported_items[0]
    var spec=study.duplicate(true);spec.appearance="Identity"
    var models=load("res://scripts/combat_models.gd").new("");models.catalog={"characters":{unit.id:spec}}
    var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.issues.is_empty(),str(models.issues));await process_frame;actor.set_process(false)
    var identity=actor.model.get_node("Identity");identity.set_process(false);identity.hair_motion.update(0,"down",2)
    var animation=actor.player.get_animation("Death01");animation.loop_mode=Animation.LOOP_NONE
    var root_path=NodePath("Armature/Skeleton3D:root");var track=animation.find_track(root_path,Animation.TYPE_POSITION_3D)
    if track>=0:animation.remove_track(track)
    track=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(track,root_path);animation.track_insert_key(track,0,Vector3.ZERO)
    var cache=Vertices.prepare(actor).filter(func(entry):
     var material=entry[0].get_active_material(0)
     return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
    var rows=[]
    for listener in actor.pose_listeners:listener.combat_pose("down")
    for index in range(COUNT):
     var time=animation.length*index/(COUNT-1);actor.player.stop();actor.player.play("Death01",0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
     rows.append([time,maxf(0,.012-Vertices.minimum(actor,cache))])
    var key="promotion:"+id+":"+path.id;output[key]=smooth_lift(rows)
    print(key,": ",COUNT," complete outfit samples -> ",output[key].size()," support keys")
    actor.queue_free();await process_frame
 assert(not output.is_empty(),"The selected class needs supported infantry studies")
 var file=FileAccess.open(arguments[0],FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(output,"  ")+"\n");file.close()
 world.queue_free();await process_frame;print("PASS: calibrated ",output.size()," private promotion falls; verify dense samples before shipping");quit()
