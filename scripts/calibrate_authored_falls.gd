extends SceneTree
# Offline fit only. Run with --script scripts/calibrate_authored_falls.gd -- OUTPUT.json
# Samples every styled infantry outfit, including hair and enemy headgear, then conservatively smooths the
# required root lift. Verify all floor/pose suites before replacing shipped data.
const Vertices=preload("res://tests/helpers/authored_vertices.gd")
const COUNT=257
const RADIUS=6
const SIGMA=3.0
func _initialize():call_deferred("run")
func reduce_curve(rows: Array) -> Array:
 var first=rows[0];var last=rows[-1];var worst=0.0;var selected=0
 for index in range(rows.size()):
  var row=rows[index];var estimate=lerpf(first[1],last[1],(row[0]-first[0])/(last[0]-first[0]));var error=absf(row[1]-estimate)
  if error>worst:worst=error;selected=index
 if worst<=.0004:return [first,last]
 var left=reduce_curve(rows.slice(0,selected+1));left.pop_back();left.append_array(reduce_curve(rows.slice(selected)));return left
func smooth_lift(rows: Array) -> Array:
 var envelope=[];var result=[]
 for index in range(rows.size()):
  var peak=0.0
  for sample in range(maxi(0,index-RADIUS),mini(rows.size(),index+RADIUS+1)):peak=maxf(peak,rows[sample][1])
  envelope.append(peak)
 for index in range(rows.size()):
  var total=0.0;var weight=0.0
  for offset in range(-RADIUS,RADIUS+1):
   var amount=exp(-.5*pow(offset/SIGMA,2));total+=envelope[clampi(index+offset,0,rows.size()-1)]*amount;weight+=amount
  var value=total/weight
  assert(value>=rows[index][1]-.0000001,"The smoothing envelope must never sink beneath the measured floor")
  result.append([snappedf(rows[index][0],.0000001),snappedf(value+.002 if value>0 else 0,.0000001)])
 return reduce_curve(result)
func run():
 var arguments=OS.get_cmdline_user_args()
 if arguments.size()!=1:push_error("Pass one output JSON path after --");quit(1);return
 var world=Node3D.new();root.add_child(world);var rules=load("res://scripts/rules.gd").new();var output={};var entries={}
 var studies=JSON.parse_string(FileAccess.get_file_as_string("res://data/model_studies.json"))
 for key in studies:
  var spec=studies[key]
  if spec.has("mount"):continue
  if spec.has("study_enemy_class"):
   entries["enemy:"+spec.study_enemy_class]=[spec,spec.study_character]
  else:
   for id in spec.get("campaign_characters",[spec.study_character]):entries["recruit:"+id]=[spec,id]
 for key in entries:
  var spec=entries[key][0].duplicate(true);spec.appearance="Identity"
  var unit=rules.roster.filter(func(value):return value.id==entries[key][1])[0].duplicate(true);unit.team="enemy" if key.begins_with("enemy:") else "player";unit.item=spec.supported_items[0]
  if key.begins_with("enemy:"):unit.id=key;unit.job=spec.study_enemy_class
  var models=load("res://scripts/combat_models.gd").new("");models.catalog={"characters":{unit.id:spec}}
  var actor=models.build(world,unit,Vector3.ZERO);assert(actor!=null and models.issues.is_empty(),str(models.issues));await process_frame;actor.set_process(false)
  var identity=actor.model.get_node("Identity");identity.set_process(false);identity.hair_motion.update(0,"down",2)
  var animation=actor.player.get_animation("Death01");animation.loop_mode=Animation.LOOP_NONE
  var path=NodePath("Armature/Skeleton3D:root");var track=animation.find_track(path,Animation.TYPE_POSITION_3D)
  if track>=0:animation.remove_track(track)
  track=animation.add_track(Animation.TYPE_POSITION_3D);animation.track_set_path(track,path);animation.track_insert_key(track,0,Vector3.ZERO)
  var cache=Vertices.prepare(actor).filter(func(entry):
   var material=entry[0].get_active_material(0)
   return not (material is ShaderMaterial and material.shader.resource_path.ends_with("character.gdshader") and material.get_shader_parameter("cloth_floor_enabled")))
  var rows=[]
  for listener in actor.pose_listeners:listener.combat_pose("down")
  for index in range(COUNT):
   var time=animation.length*index/(COUNT-1);actor.player.stop();actor.player.play("Death01",0);actor.player.seek(time,true,true);actor.player.pause();actor.refresh_skeleton()
   rows.append([time,maxf(0,.012-Vertices.minimum(actor,cache))])
  output[key]=smooth_lift(rows)
  print(key,": ",COUNT," full-outfit poses -> ",output[key].size()," conservative root-height keys")
  actor.queue_free();await process_frame
 var file=FileAccess.open(arguments[0],FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(output,"  ")+"\n");file.close()
 world.queue_free();await process_frame;print("PASS: generated ",output.size()," measured outfit fall curves; verify dense poses before shipping");quit()
