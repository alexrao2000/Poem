import json,os,math,wave,array,struct,zlib
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
classes={
'Vanguard':dict(hp=27,pow=8,defense=6,speed=7,move=5,weapon='sword',reach=1),
'Knight':dict(hp=32,pow=9,defense=9,speed=3,move=4,weapon='lance',reach=1),
'Ranger':dict(hp=24,pow=8,defense=4,speed=8,move=5,weapon='bow',reach=2),
'Arcanist':dict(hp=22,pow=10,defense=3,speed=6,move=5,weapon='magic',reach=2),
'Warden':dict(hp=25,pow=7,defense=5,speed=6,move=5,weapon='staff',reach=1),
'Rider':dict(hp=28,pow=8,defense=5,speed=7,move=7,weapon='lance',reach=1),
'Corsair':dict(hp=30,pow=10,defense=4,speed=6,move=5,weapon='axe',reach=1),
'Duelist':dict(hp=23,pow=7,defense=3,speed=11,move=6,weapon='sword',reach=1)}
people=[('Lyra','Vanguard','An unwilling heir carrying a broken standard.','eac77c'),('Oren','Knight','A gatekeeper who chose his neighbors over his orders.','85a8bb'),('Sera','Ranger','A border scout who maps the stars as carefully as roads.','b8c989'),('Ivo','Warden','A field medic who refuses to call anyone expendable.','b7a4d1'),('Mara','Corsair','A river captain with debts in every harbor.','dd946e'),('Tarin','Arcanist','A scholar whose forbidden research predicted the eclipse.','a6d2dc'),('Nell','Duelist','A courier who knows how to leave a locked room.','dbb2b0'),('Bram','Rider','A farmhand riding the last horse from his village.','b6bf89'),('Esme','Warden','A temple singer preserving the names of the missing.','cbb1df'),('Rook','Knight','A deserter searching for the people his regiment displaced.','a4adbe'),('Faye','Ranger','A hunter who follows old paths through new battlefields.','99cba9'),('Cassian','Vanguard','A rival claimant learning what a crown actually costs.','dcc27d'),('Vela','Arcanist','A lighthouse keeper who reads storms in candle flames.','8ac9d0'),('Dax','Corsair','A dockworker who organized the first harbor uprising.','d5aa82'),('Una','Rider','A diplomat who has run out of peaceful roads.','d9b3b7'),('Silas','Duelist','A former royal spy determined to tell the truth once.','9faabd'),('Petra','Knight','A bridge engineer defending what she built.','c6b7a0'),('Ari','Ranger','A young falconer carrying messages between isolated towns.','a8c7c2'),('Noor','Arcanist','An astronomer trying to extinguish a man-made sun.','b3a2dc'),('Galen','Warden','A monastery gardener who knows every healing root.','aabf8a'),('Yuna','Duelist','A palace dancer who memorized the guards’ patrols.','d6a5ba'),('Hale','Corsair','A miner who helped excavate the enemy’s terrible engine.','cda68c'),('Elian','Rider','A loyal officer whose loyalty finally found its limit.','b6c6d2'),('Rhea','Vanguard','The regent’s estranged daughter, carrying his last letter.','e2c78f')]
roster=[]
for i,(n,c,b,color) in enumerate(people):
 roster.append(dict(id=n.lower(),name=n,job=c,bio=b,color='#'+color,join=0 if i<4 else 1+(i-4)//2,**classes[c]))
chapters=[
('Ash on the Water','Cinderford','rout','Captain Voss','The regent has ordered the river towns emptied. Lyra raises her broken standard at the first burning bridge.','The villagers cross in silence. At dawn, a river captain offers a passage north.'),
('The Broken Toll','Reed Crossing','seize','Tollmaster Renn','Mara’s boats cannot pass the chain towers. Take the eastern tollhouse before the river closes.','The chains fall. Tarin finds the eclipse engine’s seal on a confiscated cargo manifest.'),
('Lanterns in the Rain','Greywood','survive','Hunter Cale','Refugees are hidden in the wood. Hold the lantern road for six turns while Nell guides them to safety.','The final lantern disappears into the rain. Bram brings horses and news of the occupied abbey.'),
('The Silent Bell','Hallow Abbey','boss','Prior Ash','The abbey bell has been melted for the regent’s engine. Esme and Rook will help us silence its overseer.','The abbey opens its granaries. Inside the crypt, Lyra finds a map to the old royal causeway.'),
('An Unclaimed Crown','Kingsroad','seize','Marshal Orr','Cassian blocks the causeway with his own banner. Faye brokers a truce: together, take the imperial checkpoint.','Cassian lowers his claim for now. Two banners travel east under the same rain.'),
('Salt and Embers','Glass Harbor','rout','Admiral Vale','The harbor is under siege. Vela’s beacon and Dax’s dockworkers can turn the tide if the occupation falls.','The harbor fleet joins the cause. Beyond the water, the engine begins to wake.'),
('The Long Retreat','Windscar Pass','survive','General Kest','Una’s embassy has been betrayed. Hold the pass for six turns while Silas carries the proof to the cities.','The cities answer the message. For the first time, the regent’s army faces a country instead of fugitives.'),
('Stone Remembers','Old Aqueduct','seize','Engineer Mal','Petra knows a forgotten route across the aqueduct. Ari reports that the eastern gate is lightly guarded.','Water returns to the valley. A hidden observatory reveals what the engine will consume.'),
('A Borrowed Sun','Starfall','boss','Astrologer Sen','Noor has calculated the cost: the engine will burn the valley to sustain the capital. Galen opens a path through the monastery.','The observatory goes dark. Its charts reveal the engine’s three vulnerable anchors.'),
('Beneath the Furnace','Reddeep','rout','Warden Flint','Yuna knows the palace entrances. Hale knows the tunnels beneath them. First, free the workers chained to the furnace.','The furnace is empty. Workers and soldiers carry the wounded out together.'),
('The Last Oath','Crown Approach','seize','Lord Regent’s Guard','Elian opens the outer defenses. Rhea brings an offer of surrender, but the inner guard refuses to stand down.','The doors open. Rhea’s father waits beside a sun that no longer obeys him.'),
('Dawn Without Kings','The Sun Engine','boss','Regent Vael','The engine feeds on every oath sworn to the crown. Break its keeper’s hold before the valley becomes its fuel.','The artificial sun breaks into a thousand harmless lights. In the valley, morning arrives on its own. Lyra plants the broken standard beside the river. No throne is raised in its place.')]
cs=[]
for i,(title,place,obj,boss,intro,outro) in enumerate(chapters):
 grid=[list('..............') for _ in range(10)]
 # Distinct fixed layouts, with traversable center routes.
 for y in range(10):
  for x in range(14):
   if (x*3+y*5+i*7)%17<3: grid[y][x]='f'
   if (x*7+y*2+i)%29==0: grid[y][x]='h'
 if i%4==0:
  for y in range(10): grid[y][6]='~' if y not in [3,4,7] else '='
 elif i%4==1:
  for x in range(3,12): grid[5][x]='~' if x not in [4,9] else '='
 elif i%4==2:
  for y in [1,2,6,7,8]: grid[y][7]='#'
 else:
  for x in range(5,12): grid[2][x]='#' if x!=8 else '.'
 for x,y in [(1,3),(1,4),(1,5),(2,3),(2,4),(2,5)]:grid[y][x]='.'
 grid[4][12]='o';grid[3][3]='+';grid[7][10]='+'
 cs.append(dict(id=i,title=title,place=place,objective=obj,boss=boss,intro=intro,outro=outro,map=[''.join(r) for r in grid],turn_limit=6,deployment=6,enemy_count=5+i//2))
for chapter,theme in zip(cs,['village','river','forest','abbey','road','harbor','mountain','aqueduct','observatory','furnace','castle','engine']):chapter['environment']=theme
json.dump(dict(roster=roster,chapters=cs,classes=classes),open(root+'/data/campaign.json','w'),indent=2)
# Pixel silhouettes authored procedurally; transparent PNG sprites, 3 idle frames.
def png(path,w,h,data):
 def chunk(t,d):return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
 raw=b''.join(b'\0'+bytes(data[y*w*4:(y+1)*w*4]) for y in range(h))
 open(path,'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
for p in roster+[dict(id='enemy',color='#d87b79',weapon='axe')]:
 w,h=72,32; pix=[0]*(w*h*4); col=tuple(bytes.fromhex(p['color'][1:]));dark=tuple(int(a*.45) for a in col)
 def rect(x,y,ww,hh,c):
  for yy in range(y,y+hh):
   for xx in range(x,x+ww):
    if 0<=xx<w and 0<=yy<h:pix[(yy*w+xx)*4:(yy*w+xx)*4+4]=[*c,255]
 for frame in range(3):
  ox=frame*24; dy=1 if frame==1 else 0
  for x,y,ww,hh,c in [(7,24,4,5,(42,47,64)),(13,24,4,5,(42,47,64)),(6,12,12,13,dark),(8,12,9,10,col),(5,14,3,8,col),(17,14,3,8,col),(8,5,9,8,(227,189,152)),(7,3,11,4,(65,57,69)),(8,8,2,2,(39,43,57)),(14,8,2,2,(39,43,57)),(8,22,9,2,(223,199,135)),(20,7,2,17,(217,222,224))]:rect(ox+x,y+dy,ww,hh,c)
 png(root+'/assets/'+p['id']+'.png',w,h,pix)
# Original matched 16-bar arrangements; identical harmonic timeline.
sr=22050;bpm=112;beat=60/bpm;duration=32*beat;n=int(duration*sr)
for mode in ['calm','ablaze']:
 out=array.array('h')
 for k in range(n):
  t=k/sr;b=t/beat;ch=int(b//8)%4;rootnote=[57,53,60,55][ch];v=0
  for interval in [0,7,12]:
   f=440*2**((rootnote+interval-69)/12);v+=math.sin(2*math.pi*f*t)*.075
  seq=[0,7,12,14,12,7,3,7];note=rootnote+12+seq[int(b)%8];phase=b%1
  f=440*2**((note-69)/12);v+=math.sin(2*math.pi*f*t)*math.exp(-phase*4)*.15
  if mode=='ablaze':
   kick=b%1;v+=math.sin(2*math.pi*(55*t+3*(1-math.exp(-kick*20))))*math.exp(-kick*15)*.22
   f=440*2**((rootnote-12-69)/12);v+=(math.sin(2*math.pi*f*t)+.3*math.sin(6*math.pi*f*t))*.15
   v+=math.sin(2*math.pi*1760*t)*math.exp(-(b*2%1)*20)*.04
  out.append(int(max(-.95,min(.95,v))*22000))
 with wave.open(root+'/assets/'+mode+'.wav','wb') as f:f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes(out.tobytes())
