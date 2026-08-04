extends Node3D
class_name AreaAwareness

var last_pushback_vector : Vector3
var last_wall_jump_normal : Vector3
var last_input_package : InputPackage

@export var asdf : Transform3D

enum Area {FLOOR, AIR, WATER, SWAMP, LEDGE}

# This is the primary ray to scan the surface beneath us
# Default root position in T-pos is 1.042 meters high and 0.932 meters in current idle pose
# Due to CharacterBody3D's is_on_floor having unwanted consequences and not being customisable enough,
# I quit using it and instead with this ray I define two methods for floor detection.
# is_on_floor() and is_falling()
@onready var downcast = $Downcast as RayCast3D
var on_floor_height : float = 1

@onready var downcast_2 = $Downcast2 as RayCast3D
@onready var wallcast_1 = $WallCast1 as RayCast3D
@onready var wallcast_2 = $WallCast2 as RayCast3D

@onready var model = $".." as PlayerModel
@onready var resources = $"../Resources" as HumanoidResources
@onready var states = $"../States" as HumanoidStates

@onready var overhead_sensor_1 = $OverheadSensor1 as Area3D
@onready var overhead_sensor_2 = $OverheadSensor2 as Area3D
@onready var before_chest_sensor = $BeforeChestSensor as Area3D



#enum MovementMode { FLOOR, AIR, LEDGE, BEAM }
## we export it to be able to include into MovesDatabase animation player as a track
#@export var current_mode : MovementMode = MovementMode.FLOOR

var current_beam : ProtoBeam
var last_beam_fall : float = 0
var beam_cooldown : float = 0.2

var current_ledge : MarkedLedge
var ledge_climbing_point : Vector3

# We don't have a lot of forced contexts here, but they have a shared formula,
# essentially, a forced context can be formulated as "floor is [something]".
# Currently we just push another action to movement actions,
# but I can see the future where it becomes an enum field in area awareness, just "what is the floor here".
func add_context(input : InputPackage) -> InputPackage:
	if feel_beam():
		input.movement_actions.append("beam_walk")
		current_beam = downcast_2.get_collider()
	if not is_on_floor():
		input.movement_actions.append("midair")
	last_input_package = input
	return input


func eligible_for_wall_jump() -> bool:
	wallcast_1.force_raycast_update()
	wallcast_2.force_raycast_update()
	if wallcast_1.is_colliding():
		$test_marker.global_position = wallcast_1.get_collision_point()
		last_wall_jump_normal = wallcast_1.get_collision_normal()
		return true and resources.can_be_paid(states.get_move_by_name("jump_wall"))
	if wallcast_2.is_colliding():
		$test_marker.global_position = wallcast_2.get_collision_point()
		last_wall_jump_normal = wallcast_2.get_collision_normal()
		return true and resources.can_be_paid(states.get_move_by_name("jump_wall"))
	return false

func feel_beam() -> bool:
	downcast_2.force_raycast_update()
	if downcast_2.is_colliding() and Time.get_unix_time_from_system() - last_beam_fall > beam_cooldown:
		#$test_marker.global_position = downcast_2.get_collision_point()
		return true
	return false

func is_on_floor() -> bool:
	#print(get_floor_distance())
	return get_floor_distance() <= on_floor_height

func get_floor_distance() -> float:
	downcast.force_raycast_update()
	if downcast.is_colliding():
		#$Downcast2.global_position = downcast.get_collision_point()
		return downcast.global_position.distance_to(downcast.get_collision_point())
	return 999999


func can_climb_ledge(area : MarkedLedge) -> bool:
	var points = area.get_curve_points()
	var minimal_altitude : Vector3 = Vector3(99999999, 99999999, 99999999) # dirty, TODO idk
	var found_suitable_altitude : bool = false
	for i in points.size() - 1:
		var delta = points[i + 1] - points[i]
		var reduced_player_pos = model.player.global_position - points[i]
		var altitude_point = reduced_player_pos.project(delta)
		# if vectors are not opposite and altitude_point is shorter than delta,
		# i.e. if altitude from player_pos is landing between points[i] and points[i+1]
		if altitude_point.length_squared() < delta.length_squared() and altitude_point.dot(delta) > 0:
			var altitude = altitude_point - reduced_player_pos
			if altitude.length_squared() < minimal_altitude.length_squared():
				minimal_altitude = altitude
				found_suitable_altitude = true
	if found_suitable_altitude:
		current_ledge = area
		ledge_climbing_point = minimal_altitude + model.player.global_position
		$test_marker.global_position = ledge_climbing_point
		print("sensed a marked ledge")
		return true
	return false

# TODO refactor into 3d rectangle check maybe?
func can_climb_dynamic_ledge() -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin : Vector3 = global_position + Vector3(0, 1.7, 0) # lowest point of static ledges collider also
	var end : Vector3 = origin + model.player.basis.z * 0.43
	var query = PhysicsRayQueryParameters3D.create(origin, end, 1)
	var result = space_state.intersect_ray(query)
	#$test_marker.global_position = result["position"]
	if not result.is_empty():
		var normal : Vector3 = result["normal"]
		var distance : Vector3= origin - result["position"]
		#end = origin - (origin - result["position"]).reflect(normal)
		end = result["position"] + normal.rotated(Vector3.UP, (PI / 2) * sign(normal.signed_angle_to(distance, Vector3.UP)) ) * 0.5
		#$test_marker.global_position = end
		query = PhysicsRayQueryParameters3D.create(origin, end, 1)
		result = space_state.intersect_ray(query)
		if not result.is_empty():
			end = origin - normal * distance.length() * cos(normal.angle_to(distance)) * 1.2
			#$test_marker.global_position = end
			origin = end + Vector3(0, 1.2, 0)
			#$test_marker.global_position = origin
			query = PhysicsRayQueryParameters3D.create(origin, end, 1)
			result = space_state.intersect_ray(query)
			if not result.is_empty():
				ledge_climbing_point = result["position"]
				$test_marker.global_position = ledge_climbing_point
				print("dynamically sensed a ledge")
				return true
	return false

func can_grab_dynamic_ledge() -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin : Vector3 = global_position + Vector3(0, 1.426, 0) 
	var end : Vector3 = origin + model.player.basis.z * 0.629
	var query = PhysicsRayQueryParameters3D.create(origin, end, 1)
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		var normal : Vector3 = result["normal"]
		var distance : Vector3= origin - result["position"]
		#end = origin - (origin - result["position"]).reflect(normal)
		end = result["position"] + normal.rotated(Vector3.UP, (PI / 2) * sign(normal.signed_angle_to(distance, Vector3.UP)) ) * 0.5
		#$test_marker.global_position = end
		query = PhysicsRayQueryParameters3D.create(origin, end, 1)
		result = space_state.intersect_ray(query)
		if not result.is_empty():
			end = origin - normal * distance.length() * cos(normal.angle_to(distance)) * 1.2
			#$test_marker.global_position = end
			origin = end + Vector3(0, 0.3, 0)
			#$test_marker.global_position = origin
			query = PhysicsRayQueryParameters3D.create(origin, end, 1)
			result = space_state.intersect_ray(query)
			if not result.is_empty():
				ledge_climbing_point = result["position"]
				$test_marker.global_position = ledge_climbing_point
				return true
	return false
	
	
	
	
	
	
