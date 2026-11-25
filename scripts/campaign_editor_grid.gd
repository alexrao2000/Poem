extends Control
## A single canvas stays usable for authored boards up to 32 by 24 tiles.
signal tile_edited(point: Vector2i,erase: bool)
const Valley=preload("res://scripts/world_map_battle.gd")
const COLORS={".":"bac08b","p":"ccb185","=":"bd9968","f":"547558","h":"9d937c","o":"ddbc68",
 "+":"85b29b","#":"474650","~":"6b9cad"}
var level: Dictionary
var cursor=Vector2i.ZERO
var last_tile=Vector2i(-1,-1)

func configure(source: Dictionary):
 level=source
 focus_mode=FOCUS_ALL;mouse_filter=MOUSE_FILTER_STOP
 mouse_default_cursor_shape=CURSOR_CROSS
 custom_minimum_size.y=306
 focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
 resized.connect(queue_redraw)

func board_size() -> Vector2i:
 return Vector2i(level.map[0].length(),level.map.size())

func cell_size() -> float:
 var board=Vector2(board_size())
 return floorf(minf((size.x-8)/board.x,(size.y-8)/board.y))

func board_rect() -> Rect2:
 var extent=Vector2(board_size())*cell_size()
 return Rect2((size-extent)*.5,extent)

func _draw():
 if level.is_empty() or cell_size()<=0:return
 var rect=board_rect()
 var cell=cell_size()
 var table=level.presentation=="valley_table"
 draw_rect(rect.grow(3),Color("40303a"))
 if table:draw_texture_rect(Valley.MAP,rect,false)
 for y in board_size().y:
  for x in board_size().x:
   var square=Rect2(rect.position+Vector2(x,y)*cell,Vector2.ONE*cell)
   var color=Color(COLORS[level.map[y][x]])
   if table:color.a=.24 if level.map[y][x] in ["~","#","h","f"] else .09
   draw_rect(square,color)
   draw_rect(square,Color(.20,.14,.10,.32),false,1)
 for index in level.deployment_positions.size():
  draw_token(level.deployment_positions[index],str(index+1),Color("294f70"))
 for index in level.enemies.size():
  var symbol="C" if index==0 else str(level.enemies[index].job).left(1)
  draw_token(level.enemies[index].position,symbol,Color("803c40"))
 for enemy in level.hard_enemies:draw_token(enemy.position,"H",Color("745076"))
 if level.objective=="seize":
  var point=Vector2i(level.objective_position[0],level.objective_position[1])
  if Rect2i(Vector2i.ZERO,board_size()).has_point(point):
   draw_rect(Rect2(rect.position+Vector2(point)*cell,Vector2.ONE*cell).grow(-2),Color("ffe8a5"),false,2)
 if has_focus():
  draw_rect(Rect2(rect.position+Vector2(cursor)*cell,Vector2.ONE*cell).grow(-1),Color("fcf5d8"),false,2)

func draw_token(position: Array,text: String,color: Color):
 var point=Vector2i(position[0],position[1])
 if not Rect2i(Vector2i.ZERO,board_size()).has_point(point):return
 var cell=cell_size()
 var center=board_rect().position+(Vector2(point)+Vector2.ONE*.5)*cell
 var font=get_theme_default_font()
 var font_size=mini(19,maxi(10,int(cell*.48)))
 draw_circle(center,cell*.39,color)
 var extent=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
 draw_string(font,center+Vector2(-extent.x*.5,font_size*.34),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff1d3"))

func _gui_input(event: InputEvent):
 if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  if not event.pressed:last_tile=Vector2i(-1,-1);return
  grab_focus()
  use_pointer(event.position,event.button_index==MOUSE_BUTTON_RIGHT)
 elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT)):
  use_pointer(event.position,(event.button_mask & MOUSE_BUTTON_MASK_RIGHT)!=0)
 elif event is InputEventKey and event.pressed:
  var edges={KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
  if edges.has(event.keycode):
   cursor=(cursor+edges[event.keycode]).clamp(Vector2i.ZERO,board_size()-Vector2i.ONE)
   queue_redraw();accept_event()
  elif event.keycode in [KEY_ENTER,KEY_SPACE,KEY_BACKSPACE] and not event.echo:
   tile_edited.emit(cursor,event.keycode==KEY_BACKSPACE);accept_event()

func use_pointer(position: Vector2,erase: bool):
 var rect=board_rect()
 if not rect.has_point(position):return
 var relative=(position-rect.position)/cell_size()
 var point=Vector2i(floori(relative.x),floori(relative.y))
 if point==last_tile:return
 cursor=point;last_tile=point
 tile_edited.emit(point,erase);queue_redraw();accept_event()
