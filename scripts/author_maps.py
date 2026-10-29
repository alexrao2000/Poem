"""Authored campaign layouts. Run to update maps without overwriting story or art."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
path=ROOT/'data/campaign.json'
content=json.loads(path.read_text())
W,H=14,10
maps=[]
def blank(tile='.'):
    return [[tile for _ in range(W)] for _ in range(H)]
def rect(g,x0,y0,x1,y1,t):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):g[y][x]=t
def put(g,points,t):
    for x,y in points:g[y][x]=t
def enemy(x,y,job,ai='pursue'):
    return dict(position=[x,y],job=job,ai=ai)
def save(g,objective,spawns,enemies,brief,landmarks):
    g[objective[1]][objective[0]]='o'
    for x,y in spawns:
        if g[y][x] in '#~':raise ValueError('Blocked deployment')
    enemies[0]['ai']='guard'
    for e in enemies:
        x,y=e['position']
        assert g[y][x] not in '#~',(len(maps),x,y)
    assert len(set(tuple(e['position']) for e in enemies))==len(enemies)
    maps.append(dict(map=[''.join(r) for r in g],objective_position=objective,
                     deployment_positions=spawns,enemies=enemies,enemy_count=len(enemies),
                     tactical_brief=brief,landmarks=landmarks))
west=[[1,3],[1,4],[1,5],[2,3],[2,4],[2,5]]
# Cinderford: plaza and two unequal river crossings.
g=blank();rect(g,0,1,6,8,'p');rect(g,7,0,7,9,'~');put(g,[(7,4),(7,7)],'=')
rect(g,8,4,13,4,'p');rect(g,8,7,12,7,'p')
put(g,[(0,0),(3,0),(5,0),(0,9),(4,9),(9,1),(10,1),(12,2),(9,6),(11,8),(13,8)],'f')
put(g,[(3,3),(10,7)],'+');put(g,[(9,8),(11,0)],'h')
city_houses=[]
for x,y in [(0,0),(4,1),(0,7),(4,7),(12,7)]:
    rect(g,x,y,x+1,y+1,'#')
    city_houses.append({'kind':'house','position':[x+.5,y+.5],'footprint':[x,y,2,2]})
save(g,[12,4],west,[enemy(12,4,'Vanguard'),enemy(9,4,'Corsair'),enemy(10,6,'Ranger'),enemy(10,2,'Knight','sentry'),enemy(8,8,'Vanguard')],
     'Two bridges cross the canal. Oren can hold the main crossing while Sera attacks from behind him; the southern bridge offers a wider approach.',
     city_houses+[{'kind':'house','position':[-2,3]},{'kind':'house','position':[11,-2]},{'kind':'fountain','position':[3,3]}])
# Reed Crossing: double-width river, separated bridges, fortified eastern tollhouse.
g=blank();rect(g,5,0,6,9,'~');rect(g,5,2,6,2,'=');rect(g,5,7,6,7,'=')
rect(g,0,2,4,2,'p');rect(g,7,2,9,2,'p');rect(g,7,7,12,7,'p');rect(g,10,2,10,7,'#');put(g,[(10,4),(10,6)],'p')
rect(g,11,3,13,5,'p');put(g,[(3,1),(8,6)],'+');put(g,[(1,0),(2,0),(8,0),(12,0),(2,7),(3,8),(8,4),(12,9)],'f')
save(g,[12,4],west,[enemy(12,4,'Knight'),enemy(8,2,'Ranger'),enemy(9,7,'Corsair'),enemy(11,6,'Vanguard','sentry'),enemy(8,3,'Arcanist','sentry'),enemy(4,7,'Corsair')],
     'Choose the northern bridge for speed or the southern approach for cover. Tarin’s magic cuts through the tollhouse knight’s armor. Any ally can seize the marked gate.',
     [{'kind':'tower','position':[10,1]},{'kind':'tower','position':[10,8]}])
# Greywood: a refuge with three approach lanes; enemies enter from two sides.
g=blank('f');rect(g,0,4,13,5,'.');rect(g,3,1,4,8,'.');rect(g,9,0,10,9,'.');rect(g,1,3,5,6,'.')
put(g,[(2,4),(8,7)],'+');put(g,[(6,1),(6,2),(7,7),(7,8)],'#')
save(g,[3,4],[[2,3],[2,4],[2,5],[3,3],[3,5],[4,4]],
     [enemy(12,4,'Ranger'),enemy(9,1,'Corsair'),enemy(10,8,'Vanguard'),enemy(6,4,'Arcanist'),enemy(1,8,'Corsair'),enemy(4,0,'Duelist')],
     'Hold for six enemy phases. Forest slows both sides and reduces incoming damage. Keep the healer near the refuge; attackers approach from the north and south as well as the east.',
     [{'kind':'camp','position':[1,1]}])
# Hallow Abbey: nave, side chapels and doorways instead of an open meadow.
g=blank('p');rect(g,4,1,13,1,'#');rect(g,4,8,13,8,'#');rect(g,4,1,4,8,'#');put(g,[(4,4),(4,5)],'p')
rect(g,7,2,7,7,'#');rect(g,10,2,10,7,'#');put(g,[(7,3),(7,6),(10,3),(10,6)],'p')
put(g,[(6,2),(9,7)],'+');put(g,[(1,0),(1,9),(3,9)],'f')
save(g,[12,4],west,[enemy(12,4,'Arcanist'),enemy(6,4,'Knight'),enemy(8,3,'Ranger'),enemy(9,6,'Vanguard'),enemy(12,6,'Knight','sentry'),enemy(11,2,'Arcanist','sentry')],
     'The abbey’s side chapels connect through narrow doors. Use both aisles to avoid a queue at the entrance. Defeat Prior Ash; clearing every guard is optional.',
     [{'kind':'spire','position':[12,0]},{'kind':'ruin','position':[6,9]}])
# Kingsroad: causeway, central barricade, risky narrow bypass.
g=blank('~');rect(g,0,3,13,6,'p');rect(g,0,0,2,9,'.');rect(g,11,0,13,9,'.')
rect(g,3,1,10,1,'=');rect(g,3,1,3,3,'=');rect(g,10,1,10,3,'=');put(g,[(7,3),(7,6)],'#');put(g,[(4,5),(11,5)],'+')
put(g,[(0,0),(1,1),(12,8),(13,8)],'f')
save(g,[12,4],west,[enemy(12,4,'Rider'),enemy(6,4,'Knight'),enemy(6,5,'Ranger'),enemy(9,4,'Vanguard','sentry'),enemy(9,6,'Arcanist','sentry'),enemy(10,1,'Duelist'),enemy(11,7,'Corsair')],
     'The broad causeway favors armored units, but the northern maintenance bridge lets riders bypass the central barricade. Seize the eastern standard.',
     [{'kind':'tower','position':[8,2]},{'kind':'tower','position':[8,7]}])
# Glass Harbor: three piers, one warehouse and a coastal lane.
g=blank('~');rect(g,0,0,13,4,'p');rect(g,0,0,2,9,'.')
for x in [4,8,12]:rect(g,x,5,x,9,'=')
rect(g,6,1,8,2,'#');put(g,[(2,2),(8,6)],'+');put(g,[(0,0),(1,8),(2,8)],'f')
save(g,[12,3],[[1,2],[1,3],[1,4],[2,3],[2,4],[3,3]],
     [enemy(12,3,'Vanguard'),enemy(4,7,'Corsair'),enemy(8,8,'Ranger'),enemy(12,8,'Arcanist'),enemy(9,3,'Knight'),enemy(10,1,'Ranger','sentry'),enemy(5,0,'Corsair')],
     'Clear the occupation from all three piers. Archers can fire across the narrow water gaps; the warehouse blocks movement but has routes along both sides.',
     [{'kind':'warehouse','position':[7,1.5]},{'kind':'boat','position':[6,8]},{'kind':'boat','position':[10,7]}])
# Windscar: a switchback with a defended western exit.
g=blank('#');rect(g,0,4,6,6,'h');rect(g,5,1,7,6,'h');rect(g,5,1,12,2,'h');rect(g,10,1,12,8,'h');rect(g,2,7,12,8,'h');rect(g,2,5,3,8,'h')
rect(g,0,5,6,5,'.');rect(g,6,1,6,5,'.');rect(g,6,2,11,2,'.');rect(g,11,2,11,8,'.');rect(g,3,8,11,8,'.');put(g,[(3,5),(9,8)],'+')
save(g,[1,5],[[1,4],[1,5],[1,6],[2,4],[2,5],[2,6]],
     [enemy(12,2,'Knight'),enemy(6,3,'Rider'),enemy(6,1,'Ranger'),enemy(9,2,'Arcanist'),enemy(8,8,'Rider'),enemy(5,7,'Corsair'),enemy(12,7,'Ranger'),enemy(10,8,'Vanguard')],
     'Hold the western exit for six enemy phases. Hills slow every advance. The two switchback routes meet beside the healing spring; do not let your healer become the front line.',
     [{'kind':'ruin','position':[0,2]}])
# Aqueduct: parallel routes over water with two connecting stairs.
g=blank('~');rect(g,0,4,13,5,'p');rect(g,1,1,12,2,'p');rect(g,1,1,2,5,'p');rect(g,11,1,12,5,'p')
rect(g,0,3,3,6,'p');rect(g,10,3,13,6,'p');put(g,[(5,4),(8,5)],'#');put(g,[(4,1),(10,5)],'+')
save(g,[12,4],west,[enemy(12,4,'Knight'),enemy(6,5,'Ranger'),enemy(7,4,'Corsair'),enemy(8,2,'Arcanist'),enemy(10,1,'Vanguard','sentry'),enemy(11,5,'Ranger','sentry'),enemy(4,4,'Knight'),enemy(5,2,'Duelist')],
     'The upper inspection gallery is longer but offers a healing station. Split the company or use the lower channel as a shielded advance. Petra can anchor either narrow route.',
     [{'kind':'arch','position':[4,6]},{'kind':'arch','position':[8,6]}])
# Starfall: four rooms around a central crossing, upper-right boss chamber.
g=blank('p');rect(g,6,0,6,9,'#');rect(g,0,4,13,4,'#');put(g,[(6,2),(6,7),(3,4),(10,4)],'p')
put(g,[(2,1),(3,1),(10,8),(11,8)],'#');put(g,[(4,7),(9,2)],'+')
save(g,[11,1],[[1,7],[1,8],[2,7],[2,8],[3,7],[3,8]],
     [enemy(11,1,'Arcanist'),enemy(4,3,'Knight'),enemy(3,2,'Ranger'),enemy(8,6,'Arcanist'),enemy(10,5,'Vanguard'),enemy(9,1,'Knight','sentry'),enemy(12,3,'Ranger','sentry'),enemy(7,8,'Duelist')],
     'Four observatory chambers connect at narrow doors. Choose the northern library or southern instrument hall, then converge on Sen’s telescope chamber.',
     [{'kind':'observatory','position':[11,-1]},{'kind':'ruin','position':[-1,3]}])
# Reddeep: furnaces divide the floor; crossing catwalks create flanking routes.
g=blank('p');rect(g,5,1,6,8,'~');rect(g,10,1,10,8,'~');rect(g,5,3,6,3,'=');rect(g,5,7,6,7,'=');put(g,[(10,2),(10,6)],'=')
put(g,[(3,2),(3,3),(8,4),(8,5),(12,7)],'#');put(g,[(2,6),(8,1)],'+')
save(g,[12,4],west,[enemy(12,4,'Knight'),enemy(4,7,'Corsair'),enemy(7,3,'Arcanist'),enemy(8,7,'Ranger'),enemy(11,2,'Knight'),enemy(12,6,'Vanguard'),enemy(9,0,'Arcanist'),enemy(7,8,'Corsair'),enemy(12,8,'Duelist')],
     'The furnace channels cannot be crossed except at catwalks. Secure one crossing before opening the next. Clear every guard to free the workers.',
     [{'kind':'furnace','position':[5.5,5]},{'kind':'furnace','position':[10,8]}])
# Crown Approach: central gate and two side breaches, open staging court.
g=blank('p');rect(g,8,0,8,9,'#');put(g,[(8,1),(8,4),(8,5),(8,8)],'p')
rect(g,9,2,12,2,'#');rect(g,9,7,12,7,'#');put(g,[(11,2),(11,7)],'p')
put(g,[(1,0),(2,0),(3,0),(1,8),(2,8),(4,8),(5,1),(5,2),(5,7)],'f');put(g,[(4,4),(10,5)],'+')
save(g,[12,4],west,[enemy(12,4,'Knight'),enemy(7,4,'Knight'),enemy(9,1,'Ranger'),enemy(9,8,'Arcanist'),enemy(11,3,'Vanguard','sentry'),enemy(11,6,'Rider','sentry'),enemy(5,5,'Corsair'),enemy(6,2,'Rider'),enemy(12,0,'Duelist')],
     'The inner wall has a broad central gate and two side breaches. Draw the mobile riders into the courtyard, then advance on the throne standard with healing support.',
     [{'kind':'tower','position':[8,-1]},{'kind':'tower','position':[8,10]},{'kind':'spire','position':[14,4]}])
# Sun Engine: a ring around the sealed core, north/south approach to the keeper.
g=blank('#');rect(g,0,3,3,6,'p');rect(g,2,1,11,2,'p');rect(g,2,7,11,8,'p');rect(g,2,2,4,7,'p');rect(g,10,2,12,7,'p');rect(g,11,3,13,6,'p')
rect(g,5,3,9,6,'~');put(g,[(4,4),(10,5)],'+');put(g,[(7,1),(7,8)],'h')
save(g,[12,4],west,[enemy(12,4,'Arcanist'),enemy(4,2,'Knight'),enemy(4,7,'Knight'),enemy(6,1,'Ranger'),enemy(6,8,'Arcanist'),enemy(9,2,'Vanguard'),enemy(9,7,'Rider'),enemy(11,3,'Knight','sentry'),enemy(11,6,'Duelist','sentry'),enemy(12,2,'Arcanist','sentry')],
     'The sealed engine core forces a northern or southern approach. Both routes have armored defenders and ranged support. Break through to Vael; defeating his remaining guards is optional.',
     [{'kind':'engine','position':[7,4.5]}])
assert len(maps)==12
for chapter,layout in zip(content['chapters'],maps):chapter.update(layout)
path.write_text(json.dumps(content,indent=2)+'\n')
print('Authored 12 distinct maps, deployment formations, objectives and enemy squads.')
