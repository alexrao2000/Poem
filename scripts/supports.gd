extends RefCounted
# Relationship data and progress stay independent of rendering and audio.
var entries: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/supports.json"))
var state: Dictionary={}
const RANKS=["—","C","B","A"]

func entry_for(id: String) -> Dictionary:
 for entry in entries:
  if entry.id==id:return entry
 return {}

func for_unit(id: String) -> Array:
 return entries.filter(func(entry):return id in entry.members)

func progress(id: String) -> Dictionary:
 return state.get(id,{"points":0,"rank":0,"chapter":-1,"earned":0,"turn":-1})

func can_read(id: String,chapter: int) -> bool:
 var entry=entry_for(id);var record=progress(id);var rank=int(record.rank)
 return not entry.is_empty() and rank<3 and chapter>=int(entry.chapters[rank]) and record.points>=entry.points[rank]

func complete_scene(id: String,chapter: int) -> bool:
 if not can_read(id,chapter):return false
 var record=progress(id).duplicate();record.rank+=1;state[id]=record
 return true

func earn(game,unit: Dictionary):
 if unit.get("team","")!="player" or unit.hp<=0:return
 for entry in for_unit(unit.id):
  var partner=game.living("player").filter(func(other):return other.id!=unit.id and other.id in entry.members)
  if partner.is_empty() or game.distance(unit,partner[0])>2:continue
  var record=progress(entry.id).duplicate()
  if record.chapter!=game.chapter:record.chapter=game.chapter;record.earned=0;record.turn=-1
  if record.earned>=3 or record.turn==game.turn:continue
  record.points=mini(6,int(record.points)+1);record.earned+=1;record.turn=game.turn;state[entry.id]=record

func nearby_rank(game,unit: Dictionary) -> int:
 if unit.get("team","")!="player" or unit.hp<=0:return 0
 var best=0
 for entry in for_unit(unit.id):
  for other in game.living("player"):
   if other.id!=unit.id and other.id in entry.members and game.distance(unit,other)<=2:
    best=maxi(best,int(progress(entry.id).rank))
 return best

func valid_state(value) -> bool:
 if not value is Dictionary or value.size()>entries.size():return false
 for id in value:
  if not id is String or entry_for(id).is_empty() or not value[id] is Dictionary:return false
  var record=value[id]
  for key in ["points","rank","chapter","earned","turn"]:
   if not (record.get(key) is int or record.get(key) is float) or not is_finite(float(record[key])) or record[key]!=int(record[key]):return false
  if record.points<0 or record.points>6 or record.rank<0 or record.rank>3 or record.chapter< -1 or record.chapter>11 or record.earned<0 or record.earned>3 or record.turn< -1:return false
  if record.rank>0 and record.points<entry_for(id).points[int(record.rank)-1]:return false
 return true
