extends RefCounted
# A personal reply needs its addressed companions as well as its speaker.
# If a beat loses someone it requires, use its first available authored alternate.
# Support replays are handled separately as memories by the dialogue caller.
static func available(line: Dictionary,losses: Array) -> bool:
 return line.speaker not in losses and line.get("requires",[]).all(func(id):return id not in losses)

static func resolve(lines: Array,losses: Array) -> Array:
 var result=[]
 for line in lines:
  if available(line,losses):
   result.append(line.duplicate(true));continue
  for alternative in line.get("when_absent",[]):
   if available(alternative,losses):
    result.append(alternative.duplicate(true));break
 return result
