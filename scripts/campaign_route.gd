extends Control
## Read-only campaign geography. Buttons review reached chapters; selecting a
## marker never changes campaign state or reveals an unreached briefing.
signal chapter_selected(index: int)
signal seal_spacing_changed(crowded: bool)
signal pin_placed(index: int,position: Vector2)
signal battle_tile_selected(tile: Vector2i)
const MAP=preload("res://assets/art/campaign-valley-v1.png")
const Grid=preload("res://scripts/campaign_editor_grid.gd")
const Rules=preload("res://scripts/rules.gd")
const RouteSeals=preload("res://scripts/route_seals.gd")
const Valley=preload("res://scripts/world_map_battle.gd")
const SEAL_SIZE=36.0
const SEAL_INSET=20.0
const STANDARD_INSET=41.0
var positions=PackedVector2Array()
var survey_cells: Array[Vector2i]=[]
var markers: Array[Button]=[]
var current=0
var selected=0
var complete=false
var section_starts=false
var rally_points=PackedInt32Array()
var retreat_chapter=0
var show_retreat_path=false
var crowded=false
var clock=0.0
var map_rect=Rect2()
var seal_scale=1.0
var editable=false
var map_picture: Texture2D=MAP
var survey_terrain: Array
var survey_standards: Array[Vector2i]
var battle_counters: Dictionary
var battle_claims: Dictionary
var battle_tile_picker=false
var battle_tile=Vector2i(-1,-1)
var battle_path: Array[Vector2i]

func configure(chapters: Array,index: int,finished=false,rallies=PackedInt32Array(),retreat=0,atlas: Texture2D=null):
 map_picture=MAP if atlas==null else atlas
 for chapter in chapters:
  var pin=chapter.get("route_position",[])
  assert(pin is Array and pin.size()==2 and pin[0]>=0 and pin[0]<=1 and pin[1]>=0 and pin[1]<=1,"Route positions use normalized image coordinates")
  positions.append(Vector2(pin[0],pin[1]))
  survey_cells.append(Valley.route_tile(pin))
 current=clampi(index,0,positions.size()-1);selected=current;complete=finished
 rally_points=rallies;retreat_chapter=retreat;section_starts=not rally_points.is_empty()
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
 custom_minimum_size=Vector2(350,240)
 for i in positions.size():
  var marker=Button.new();marker.name="Chapter"+str(i+1);marker.text=str(i+1)
  marker.tooltip_text=chapters[i].place+" · "+chapters[i].title if i<=current or complete else "Unreached destination"
  if rally_points.has(i) and (i<=current or complete):marker.tooltip_text+="\nSection %d start%s"%[rally_points.find(i)+1," · Current retreat point" if i==retreat_chapter and not complete else ""]
  marker.disabled=i>current and not complete;marker.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  for state in ["normal","hover","pressed","disabled"]:marker.add_theme_stylebox_override(state,StyleBoxEmpty.new())
  var focus=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.set_border_width_all(2);focus.border_color=Color("fff0b0");focus.set_corner_radius_all(18)
  marker.add_theme_stylebox_override("focus",focus)
  marker.add_theme_font_size_override("font_size",14)
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:marker.add_theme_color_override(state,Color("fff1cc"))
  marker.add_theme_color_override("font_disabled_color",Color("b4ad99"))
  if i==current and not complete:marker.draw.connect(func():draw_current_pulse(marker))
  marker.pressed.connect(func():select_chapter(i));add_child(marker);markers.append(marker)
 resized.connect(arrange);arrange()
 set_process(not complete)

func select_chapter(index: int):
 if index<0 or index>=positions.size() or (index>current and not complete):return
 selected=index;queue_redraw();chapter_selected.emit(index)

func enable_pin_editor():
 editable=true
 mouse_filter=Control.MOUSE_FILTER_STOP

func set_war_table_overlay(battle: Dictionary):
 survey_terrain=battle.get("map",[])
 survey_standards=Rules.standard_tiles(battle)
 queue_redraw()

func set_battle_positions(occupants: Dictionary,standards: Array[Vector2i]):
 battle_counters.clear();battle_claims.clear()
 for tile in occupants:
  var unit=occupants[tile]
  battle_counters[tile]={"team":unit.team,"downed":Rules.DeathDoor.downed(unit)}
 for tile in standards:battle_claims[tile]=Valley.standard_claim(occupants.get(tile))
 queue_redraw()

func battle_tile_box(tile: Vector2i) -> Rect2:
 var cell=map_rect.size/Vector2(Valley.WIDTH,Valley.HEIGHT)
 return Rect2(map_rect.position+Vector2(tile)*cell,cell)

func battle_counter_point(tile: Vector2i) -> Vector2:
 var seal=survey_cells.find(tile)
 if seal>=0 and seal<=current:return point(seal)+Vector2(11,9)*seal_scale
 return battle_tile_box(tile).get_center()

func enable_battle_tile_picker(enabled: bool):
 battle_tile_picker=enabled
 mouse_filter=Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
 focus_mode=Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
 tooltip_text="Click a tile or use the arrow keys with the atlas focused." if enabled else ""
 queue_redraw()

func select_battle_tile(tile: Vector2i):
 battle_tile=tile.clamp(Vector2i.ZERO,Vector2i(Valley.WIDTH-1,Valley.HEIGHT-1))
 battle_tile_selected.emit(battle_tile)
 queue_redraw()

func set_battle_path(path: Array):
 battle_path.assign(path)
 queue_redraw()

func draw_battle_positions():
 for tile in battle_claims:
  var color=Valley.STANDARD_COLORS[battle_claims[tile]].lightened(.26)
  draw_rect(battle_tile_box(tile).grow(-1),color,false,2.0)
 var cell=map_rect.size/Vector2(Valley.WIDTH,Valley.HEIGHT)
 var radius=clampf(minf(cell.x,cell.y)*.19,3.0,5.5)
 var paper=Color("f9e8bb")
 for tile in battle_counters:
  var counter=battle_counters[tile]
  var center=battle_counter_point(tile)
  var color=Valley.STANDARD_COLORS[counter.team]
  if counter.team=="player":
   var square=Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2)
   draw_rect(square.grow(1),paper);draw_rect(square,color)
  else:
   for inset in [1.3,0.0]:
    var edge=radius*1.24+inset
    var diamond=PackedVector2Array([center+Vector2.UP*edge,center+Vector2.RIGHT*edge,center+Vector2.DOWN*edge,center+Vector2.LEFT*edge])
    draw_colored_polygon(diamond,paper if inset>0 else color)
  if counter.downed:
   draw_line(center+Vector2.LEFT*radius*.62,center+Vector2.RIGHT*radius*.62,paper,1.4,true)
   draw_line(center+Vector2.UP*radius*.62,center+Vector2.DOWN*radius*.62,paper,1.4,true)

func draw_war_table_overlay():
 var cell=map_rect.size/Vector2(survey_terrain[0].length(),survey_terrain.size())
 var ink=Color(.22,.16,.12,.44)
 for y in survey_terrain.size():
  for x in survey_terrain[y].length():
   var tile=Vector2i(x,y)
   var rect=Rect2(map_rect.position+Vector2(tile)*cell,cell)
   var symbol=survey_terrain[y][x]
   var tint=Color(Grid.COLORS[symbol])
   tint.a=.44 if symbol in ["~","#","f","h"] else .25
   draw_rect(rect,tint)
   draw_rect(rect,ink,false,1.0)
   if tile in survey_standards and not battle_claims.has(tile):draw_rect(rect.grow(-1),Color("ffe8a5"),false,2.0)

func place_pin(position: Vector2):
 if not editable:return
 positions[selected]=position.clamp(Vector2.ZERO,Vector2.ONE)
 var pin=positions[selected]
 survey_cells[selected]=Valley.route_tile([pin.x,pin.y])
 arrange()
 pin_placed.emit(selected,positions[selected])

func _gui_input(event):
 if battle_tile_picker and event is InputEventKey and event.pressed:
  var steps={KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
  if steps.has(event.keycode):
   select_battle_tile(battle_tile+steps[event.keycode]);accept_event()
  return
 if not (editable or battle_tile_picker) or not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return
 if not map_rect.has_point(event.position):return
 var pin=(event.position-map_rect.position)/map_rect.size
 if editable:place_pin(pin)
 else:
  grab_focus()
  select_battle_tile(Valley.route_tile([pin.x,pin.y]))
 accept_event()

func arrange():
 var available=(size-Vector2(32 if size.x<500 else 48,64)).max(Vector2.ONE)
 var atlas_size=map_picture.get_size()
 var scale_value=minf(available.x/atlas_size.x,available.y/atlas_size.y)
 for seal in positions:
  var offset=(seal-Vector2(.5,.5))*atlas_size
  if not is_zero_approx(offset.x):
   scale_value=minf(scale_value,maxf(1,size.x*.5-SEAL_INSET)/absf(offset.x))
  if not is_zero_approx(offset.y):
   var inset=STANDARD_INSET if offset.y<0 else SEAL_INSET
   scale_value=minf(scale_value,maxf(1,size.y*.5-inset)/absf(offset.y))
 var extent=atlas_size*scale_value;map_rect=Rect2((size-extent)*.5,extent)
 var clearance=SEAL_SIZE+1
 for i in range(markers.size()):
  for previous in range(i):
   var gap=(point(i)-point(previous)).abs()
   clearance=minf(clearance,maxf(gap.x,gap.y))
 var hit_size=clampf(floorf(clearance-1),24,SEAL_SIZE)
 var target=Vector2.ONE*hit_size
 seal_scale=hit_size/SEAL_SIZE
 var font_size=roundi(8+6*seal_scale)
 for i in range(markers.size()):
  markers[i].add_theme_font_size_override("font_size",font_size)
  markers[i].position=point(i)-target*.5
  markers[i].size=target
 var overlaps=clearance<24
 if overlaps!=crowded:
  crowded=overlaps
  seal_spacing_changed.emit(crowded)
 queue_redraw()

func point(index: int) -> Vector2:
 return map_rect.position+positions[index]*map_rect.size

func _process(dt):
 if markers.is_empty():return
 clock+=dt
 markers[current].queue_redraw()

func draw_current_pulse(marker: Button):
 var pulse=Color("f5dc94");pulse.a=.35+.22*sin(clock*2.2)
 marker.draw_arc(marker.size*.5,20.0*seal_scale,0,TAU,48,pulse,2.0*seal_scale,true)

func _draw():
 if map_rect.size.x<=0:return
 draw_texture_rect(map_picture,map_rect,false)
 if not survey_terrain.is_empty():draw_war_table_overlay()
 if battle_tile_picker and battle_path.size()>1:
  var path=PackedVector2Array(battle_path.map(func(tile):return battle_tile_box(tile).get_center()))
  draw_polyline(path,Color("674c30"),4.0,true)
  draw_polyline(path,Color("f6d48b"),2.0,true)
 var tick=Color(.34,.23,.14,.53)
 for index in range(1,Valley.WIDTH):
  var x=map_rect.position.x+map_rect.size.x*index/Valley.WIDTH
  draw_line(Vector2(x,map_rect.end.y-4),Vector2(x,map_rect.end.y),tick)
 for index in range(1,Valley.HEIGHT):
  var y=map_rect.position.y+map_rect.size.y*index/Valley.HEIGHT
  draw_line(Vector2(map_rect.position.x,y),Vector2(map_rect.position.x+4,y),tick)
 if not editable:
  var cell=Vector2(survey_cells[selected])+Vector2(.5,.5)
  var mark=map_rect.position+map_rect.size*cell/Vector2(Valley.WIDTH,Valley.HEIGHT)
  var stamp=Color("5f3e20")
  draw_line(Vector2(mark.x,map_rect.end.y-7),Vector2(mark.x,map_rect.end.y),stamp,2)
  draw_line(Vector2(map_rect.position.x,mark.y),Vector2(map_rect.position.x+7,mark.y),stamp,2)
 for i in range(positions.size()-1):
  var a=point(i);var b=point(i+1);var delta=b-a
  var side=Vector2(-delta.y,delta.x).normalized()*minf(18,delta.length()*.1)
  var reached=i<current or complete
  var withdrawal=show_retreat_path and i>=retreat_chapter and i<current
  var distance=delta.length()
  var arrow=withdrawal and distance>40
  var color=Color("786344") if reached else Color("8c826b")
  color.a=.9 if reached else .43
  if withdrawal:color=Color("8a3e38")
  var samples=maxi(2,int(distance/8))
  for step in range(1,samples):
   var t=float(step)/samples
   if arrow and absf(t-.5)*distance<11:continue
   var pos=a.lerp(b,t)+side*sin(t*PI)
   draw_circle(pos,2.8 if withdrawal else 2.0 if reached else 1.1,color)
  if arrow:
   var direction=delta.normalized()
   var wing=direction.orthogonal()*4.5
   var center=a.lerp(b,.5)+side
   var tip=center-direction*7.0
   var base=center+direction*4.0
   draw_colored_polygon(PackedVector2Array([tip,base+wing,base-wing]),color)
 for i in range(markers.size()):
  draw_set_transform(point(i),0,Vector2.ONE*seal_scale)
  var reached=i<=current or complete
  if rally_points.has(i) and reached:
   var corners=PackedVector2Array([Vector2(0,-20),Vector2(20,0),Vector2(0,20),Vector2(-20,0),Vector2(0,-20)])
   draw_polyline(corners,Color("f5dc94") if i==retreat_chapter and not complete else Color("a88b55"),2,true)
  RouteSeals.draw_seal(self,Vector2.ZERO,1.0,reached,i==current,1.0)
  if i==selected:draw_arc(Vector2.ZERO,17,0,TAU,40,Color("f5dc94"),2,true)
  if i==current and not complete:
   var pole=Vector2(0,-17)
   draw_line(pole,pole+Vector2(0,-24),Color("51412c"),2,true)
   draw_colored_polygon(PackedVector2Array([pole+Vector2(0,-24),pole+Vector2(16,-21),pole+Vector2(12,-13),pole+Vector2(0,-15)]),Color("f1dfb5"))
 draw_set_transform(Vector2.ZERO)
 if not battle_counters.is_empty() or not battle_claims.is_empty():draw_battle_positions()
 if battle_tile_picker:
  var selection=battle_tile_box(battle_tile).grow(-2)
  draw_rect(selection,Color(1.0,.86,.60,.20))
  draw_rect(selection,Color("fff1cc" if has_focus() else "d9b77c"),false,2.0)
