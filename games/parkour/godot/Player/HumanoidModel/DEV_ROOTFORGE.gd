extends Node

@onready var skeleton_animator = $"../DEV_SkeletonAnimator"
@onready var move_database = $"../States/MovesData/MoveDatabase"
@onready var model = $".."

func _ready():
	#DEV_pin_root("ledge_climb_up_legs", "ledge_climb_up_params", Vector3(0, 0.894, 0.026))
	#DEV_nail_z_coordinate("beam_fall_right_legs", "beam_fall_params", -0.062)
	pass

#DEVELOPMENT LEAYER FUNCTIONAL, IT DOES MODIFY ASSETS, UNCOMMENT IF YOU KNOW WHAT YOU ARE DOING
#AND DID BACKUPS
#func DEV_nail_z_coordinate(animation_name : String, into_backend_animation : String, value : float):
	#var animation = skeleton_animator.get_animation(animation_name) as Animation
	#var backend_animation = move_database.get_animation(into_backend_animation) as Animation
	#var backend_track = backend_animation.find_track("MoveDatabase:root_position", Animation.TYPE_VALUE)
	#var hips_track = animation.find_track("%GeneralSkeleton:Hips", Animation.TYPE_POSITION_3D)
	#print(animation.track_get_key_count(hips_track))
	#for i : int in animation.track_get_key_count(hips_track):
		#var position = animation.track_get_key_value(hips_track, i)
		#var time = animation.track_get_key_time(hips_track, i)
		#backend_animation.track_insert_key(backend_track, time, position)
		#print(str(position) + " at " + str(time))
		#var position_without_z = position
		#position_without_z.z = value
		#animation.track_set_key_value(hips_track, i, position_without_z)
	#ResourceSaver.save(animation, "res://Assets/Ready Animations/" + animation_name + "_Z_PROJECTED.res")
	#ResourceSaver.save(backend_animation, "res://Player/Moves/BackendAnimations/" + into_backend_animation + "_WITH_ROOT.res")


#func DEV_pin_root(animation_name : String, into_backend_animation : String, value : Vector3):
	#var animation = skeleton_animator.get_animation(animation_name) as Animation
	#var backend_animation = move_database.get_animation(into_backend_animation) as Animation
	#var backend_track = backend_animation.find_track("MoveDatabase:root_position", Animation.TYPE_VALUE)
	#var hips_track = animation.find_track("%GeneralSkeleton:Hips", Animation.TYPE_POSITION_3D)
	#for i : int in animation.track_get_key_count(hips_track):
		#var position = animation.track_get_key_value(hips_track, i)
		#var time = animation.track_get_key_time(hips_track, i)
		#backend_animation.track_insert_key(backend_track, time, position)
		#print(str(position) + " at " + str(time))
		#animation.track_set_key_value(hips_track, i, value)
	#ResourceSaver.save(animation, "res://Assets/Ready Animations/" + animation_name + "_ROOT_PINNED.res")
	#ResourceSaver.save(backend_animation, "res://Player/Moves/BackendAnimations/" + into_backend_animation + "_WITH_ROOT.res")
	
	
	
	
	
	
	
	
	
	
