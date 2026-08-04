extends Node
class_name PlayerModel

@onready var player = $".." as CharacterBody3D
@onready var skeleton = %GeneralSkeleton
@onready var animator = $SplitBodyAnimator
@onready var combat = $Combat as HumanoidCombat
@onready var resources = $Resources as HumanoidResources
@onready var hurtbox = $Root/Hitbox as Hurtbox
@onready var legs = $Legs as Legs
@onready var area_awareness = $AreaAwareness as AreaAwareness

@onready var active_weapon : Weapon = $RightWrist/WeaponSocket/Sword as Sword

@onready var current_move : Move
@onready var moves_container = $States as HumanoidStates


func _ready():
	moves_container.player = player
	moves_container.accept_moves()
	current_move = moves_container.moves["idle"]
	legs.current_legs_move = moves_container.get_move_by_name("idle")
	legs.accept_behaviours()


func update(input : InputPackage, delta : float):
	input = area_awareness.add_context(input)
	input = combat.contextualize(input)
	var relevance = current_move.check_relevance(input)
	if relevance != "okay":
		switch_to(relevance)
	#print(current_move.move_name)
	current_move.update_resources(delta) # moved back here for now, because of TorsoMoves triggering _update from legs behaviour -> doubledipping
	current_move._update(input, delta)


func switch_to(state : String):
	print(current_move.move_name + " -> " + state)
	current_move._on_exit_state()
	current_move = moves_container.moves[state]
	current_move._on_enter_state()
