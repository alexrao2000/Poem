extends "res://tests/test_knight_studies.gd"
const Rider=preload("res://scripts/imported_rider.gd")
var hoof_contacts=0
func _initialize():
 study_pairs=[["rider_female","una"],["rider_male","bram"]];save_name="rider"
 super()
func watch(node):
 if node is Rider:
  node.travel_contact.connect(func(_index):
   assert(absf(node.ground_contact_position().y-node.global_position.y)<.0001,"Actual cinematic hoof contacts stay at ground height")
   hoof_contacts+=1)
 super(node)
func verify_extras():
 assert(hoof_contacts>=8,"Actual mounted approaches and retreats emit hoof contacts")
 print("PASS: revised mounted cinematic emits ",hoof_contacts," grounded hoof contacts")
