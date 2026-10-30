extends RefCounted
## Original open folio: two splayed covers, page blocks and a shared printed
## page texture. The glyphs are geometric decoration, not borrowed game text.
static var paper: StandardMaterial3D

static func page_material() -> StandardMaterial3D:
 if paper!=null:return paper
 var image=Image.create(128,192,false,Image.FORMAT_RGBA8);image.fill(Color("e8dfbf"))
 var ink=Color("656d72");var faint=Color("b7aa89")
 for y in range(192):
  var edge=minf(float(y),191-y)/18.0
  if edge<1:image.fill_rect(Rect2i(0,y,128,1),Color("d3c6a2").lerp(Color("e8dfbf"),edge))
 image.fill_rect(Rect2i(15,14,1,163),faint);image.fill_rect(Rect2i(111,14,1,163),faint)
 # A small lozenge above two groups of uneven strokes reads as manuscript.
 for y in range(22,49):
  var half=13-absi(y-35)
  if half>0:
   image.set_pixel(64-half,y,ink);image.set_pixel(64+half,y,ink)
 image.fill_rect(Rect2i(62,29,4,13),ink)
 for i in range(10):
  var y=60+i*10+(7 if i>4 else 0)
  var width=62-(i*17)%23
  image.fill_rect(Rect2i(29,y,width,2),ink)
  for mark in range(3):image.fill_rect(Rect2i(32+mark*18+(i%3)*2,y-2,2,5),ink)
 image.generate_mipmaps()
 paper=StandardMaterial3D.new();paper.albedo_texture=ImageTexture.create_from_image(image)
 paper.roughness=1;paper.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
 paper.set_meta("no_character_outline",true)
 return paper

static func build(fighters,hand: Node3D,gold: Color):
 var book=fighters.joint(hand,"Spellbook",Vector3(0,0,-.03))
 fighters.geo.block(book,Vector3(0,0,.015),Vector3(.035,.30,.045),gold)
 for side in [-1,1]:
  var leaf=fighters.joint(book,"LeftLeaf" if side<0 else "RightLeaf",Vector3(side*.012,0,0));leaf.rotation.y=side*.25
  fighters.geo.block(leaf,Vector3(side*.11,0,0),Vector3(.215,.30,.025),Color("344d65"))
  fighters.geo.block(leaf,Vector3(side*.108,0,-.025),Vector3(.195,.275,.024),Color("e8dfbf"))
  var page=MeshInstance3D.new();page.name="PrintedPage";var quad=QuadMesh.new();quad.size=Vector2(.19,.267);page.mesh=quad
  page.position=Vector3(side*.108,0,-.038);page.rotation.y=PI;page.material_override=page_material();leaf.add_child(page)
  for end in [-1,1]:fighters.geo.block(leaf,Vector3(side*.20,end*.13,-.016),Vector3(.035,.038,.008),gold)
 # A narrow ribbon projects below the binding, away from the open page plane.
 fighters.geo.block(book,Vector3(.018,-.19,.015),Vector3(.018,.10,.006),Color("8b4b4d"))
