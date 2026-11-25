extends RefCounted

const SIZE=Vector2i(1200,800)
const MAX_FILE_BYTES=6*1024*1024
const MAX_EMBEDDED_BYTES=480000
const MAX_ENCODED_LENGTH=640000
const PNG_SIGNATURE=[137,80,78,71,13,10,26,10]
const JPEG_FRAME_MARKERS=[0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf]

static func pack(source: PackedByteArray) -> Dictionary:
 var picture=read_image(source)
 if picture==null:return {"error":"Choose a readable PNG or JPEG up to 6 MB and 8 megapixels."}
 var original=picture.get_size()
 var unit=mini(original.x/3,original.y/2)
 var crop=Vector2i(3,2)*unit
 picture=picture.get_region(Rect2i((original-crop)/2,crop))
 picture.resize(SIZE.x,SIZE.y,Image.INTERPOLATE_LANCZOS)
 if picture.detect_alpha()!=Image.ALPHA_NONE:
  var parchment=Image.create_empty(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
  parchment.fill(Color("eee0bf"));picture.convert(Image.FORMAT_RGBA8)
  parchment.blend_rect(picture,Rect2i(Vector2i.ZERO,SIZE),Vector2i.ZERO)
  picture=parchment
 picture.convert(Image.FORMAT_RGB8)
 var compressed=picture.save_jpg_to_buffer(.88)
 if compressed.size()>MAX_EMBEDDED_BYTES:compressed=picture.save_jpg_to_buffer(.72)
 if compressed.is_empty() or compressed.size()>MAX_EMBEDDED_BYTES:return {"error":"This image is too large to store in the campaign."}
 return {"encoded":Marshalls.raw_to_base64(compressed)}

static func unpack(encoded: String) -> Image:
 if encoded.is_empty() or encoded.length()>MAX_ENCODED_LENGTH or encoded.length()%4!=0:return null
 if RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$").search(encoded)==null:return null
 var bytes=Marshalls.base64_to_raw(encoded)
 if bytes.is_empty() or bytes.size()>MAX_EMBEDDED_BYTES or jpeg_dimensions(bytes)!=SIZE:return null
 return read_image(bytes)

static func read_image(source: PackedByteArray) -> Image:
 if source.size()>MAX_FILE_BYTES:return null
 var png=source.size()>=24 and source.slice(0,8)==PackedByteArray(PNG_SIGNATURE)
 var size=png_dimensions(source) if png else jpeg_dimensions(source)
 if size.x<3 or size.y<2 or size.x>4096 or size.y>4096 or size.x*size.y>8000000:return null
 var picture=Image.new()
 var result=picture.load_png_from_buffer(source) if png else picture.load_jpg_from_buffer(source)
 return picture if result==OK and picture.get_size()==size else null

static func png_dimensions(source: PackedByteArray) -> Vector2i:
 if source.slice(12,16).get_string_from_ascii()!="IHDR":return Vector2i.ZERO
 var width=(source[16]<<24)|(source[17]<<16)|(source[18]<<8)|source[19]
 var height=(source[20]<<24)|(source[21]<<16)|(source[22]<<8)|source[23]
 if width>4096 or height>4096:return Vector2i.ZERO
 return Vector2i(width,height)

static func jpeg_dimensions(source: PackedByteArray) -> Vector2i:
 if source.size()<4 or source[0]!=0xff or source[1]!=0xd8:return Vector2i.ZERO
 var offset=2
 while offset<source.size():
  if source[offset]!=0xff:return Vector2i.ZERO
  while offset<source.size() and source[offset]==0xff:offset+=1
  if offset>=source.size():return Vector2i.ZERO
  var marker=source[offset];offset+=1
  if marker in [0xd9,0xda] or offset+2>source.size():return Vector2i.ZERO
  if marker==0x01 or (marker>=0xd0 and marker<=0xd7):continue
  var length=(source[offset]<<8)|source[offset+1]
  if length<2 or offset+length>source.size():return Vector2i.ZERO
  if marker in JPEG_FRAME_MARKERS:
   if length<7:return Vector2i.ZERO
   return Vector2i((source[offset+5]<<8)|source[offset+6],(source[offset+3]<<8)|source[offset+4])
  offset+=length
 return Vector2i.ZERO
