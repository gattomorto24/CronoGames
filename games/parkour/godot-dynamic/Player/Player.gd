extends CharacterBody3D


@onready var input_gatherer = $Input as InputGatherer
@onready var model = $Model as PlayerModel
@onready var visuals = $Visuals as PlayerVisuals
@onready var camera_mount = $CameraMount
@onready var collider = $Collider
@onready var flat_wall_climber = $FlatWallClimber as FlatWallClimber


func _ready():
	visuals.accept_model(model)
	flat_wall_climber.setup(self, model)
	#$CameraMount/PlayerCamera.current = false
	#print_tree_pretty()


func _physics_process(delta):
	var input : InputPackage = input_gatherer.gather_input()
	if flat_wall_climber.update_climb(input, delta):
		return
	model.update(input, delta)
	# Visuals -> follow parent transformations
