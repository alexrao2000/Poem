extends RefCounted

static func write(path: String,payload: String) -> bool:
 var temporary=path+".%d-%d.tmp"%[OS.get_process_id(),Time.get_ticks_usec()]
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return false
 file.store_string(payload)
 file.flush()
 var written=file.get_error()==OK
 file.close()
 if written and DirAccess.rename_absolute(temporary,path)==OK:return true
 DirAccess.remove_absolute(temporary)
 return false
