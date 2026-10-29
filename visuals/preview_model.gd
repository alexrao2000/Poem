## Minimal display data for the standalone package. No game or combat dependency.

extends RefCounted
var grid=["ffffffffffff","f....~~....f","f....~~..##f","fpppp==pp##f","f....~~....f","f....~~....f","fpppp==pppof","f.#..~~....f","f..h.~~.h..f","ffffffffffff"]
var units: Array=[]
func _init():
	var jobs=["Vanguard","Knight","Ranger","Arcanist","Warden","Rider","Corsair","Duelist"]
	for i in jobs.size():
		units.append({"id":"sample_"+str(i),"job":jobs[i],"x":2+i%4*2,"y":3+i/4*3,"hp":18 if i==0 else 24,"max_hp":24,"team":"player" if i<6 else "enemy","acted":i==1})
func board_size() -> Vector2i:return Vector2i(12,10)
func pos(unit: Dictionary) -> Vector2i:return Vector2i(unit.x,unit.y)
func terrain(cell: Vector2i) -> String:
	return grid[cell.y][cell.x] if cell.x>=0 and cell.y>=0 and cell.x<12 and cell.y<10 else "#"
