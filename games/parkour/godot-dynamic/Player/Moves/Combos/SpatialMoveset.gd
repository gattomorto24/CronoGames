extends Combo
class_name SpatialMoveset

var area_awareness : AreaAwareness

enum Sensors {OVERHEAD_1, OVERHEAD_2, CHEST}
@export var sensor_type : Sensors
var sensor : Area3D

enum Objects {CLIMB_LEDGE, GRAB_LEDGE}
@export var target : Objects

@export var modifier_action : String

func is_triggered(input : InputPackage) -> bool:
	if not modifier_is_pressed(input):
		return false
	
	if target == Objects.CLIMB_LEDGE:
		# I specifically use this instead of OR to not trigger dynamic search if marked one is there
		if have_marked_climbable_ledge(): 
			return true 
		else:
			return area_awareness.can_climb_dynamic_ledge()
	
	if target == Objects.GRAB_LEDGE:
		if have_marked_grabable_ledge(): 
			return true 
		else:
			return area_awareness.can_grab_dynamic_ledge()
	
	return false

func have_marked_climbable_ledge() -> bool:
	for area in sensor.get_overlapping_areas():
		if area is MarkedLedge and area_awareness.can_climb_ledge(area):
			return true
	return false

# symbol by symbol have_marked_climbable_ledge(), but I add this for conistency,
# because a sane person would have them different, it's just me, demo, meh assets etc.
func have_marked_grabable_ledge() -> bool:
	for area in sensor.get_overlapping_areas():
		if area is MarkedLedge and area_awareness.can_climb_ledge(area):
			return true
	return false

func modifier_is_pressed(input : InputPackage) -> bool:
	return modifier_action == "" or input.actions.has(modifier_action) or input.movement_actions.has(modifier_action)

func init():
	area_awareness = move.area_awareness
	match sensor_type:
		Sensors.OVERHEAD_1 : sensor = move.area_awareness.overhead_sensor_1
		Sensors.OVERHEAD_2 : sensor = move.area_awareness.overhead_sensor_2
		Sensors.CHEST : sensor = move.area_awareness.before_chest_sensor
