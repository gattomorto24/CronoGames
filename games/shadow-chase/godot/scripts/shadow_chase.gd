extends Node2D

var player := Vector2.ZERO
var shard := Vector2.ZERO
var guards: Array[Dictionary] = []
var stolen := 0
var caught := false

func _ready()->void:
	player=Vector2(90,size.y-90); shard=Vector2(size.x-90,90)
	for i in 4: guards.append({"pos":Vector2(randf_range(240,size.x-180),randf_range(100,size.y-100)),"angle":randf()*TAU,"speed":randf_range(0.5,1.1)})

func _process(delta:float)->void:
	if caught:return
	player=(player+Input.get_vector("ui_left","ui_right","ui_up","ui_down")*220*delta).clamp(Vector2(20,20),size-Vector2(20,20))
	for guard in guards:
		guard.angle+=guard.speed*delta; var sight:=Vector2.from_angle(guard.angle)
		if guard.pos.distance_to(player)<150 and sight.dot((player-guard.pos).normalized())>0.55: caught=true
	if player.distance_to(shard)<25: stolen+=1; shard=Vector2(randf_range(80,size.x-80),randf_range(80,size.y-80))
	queue_redraw()

func _input(event:InputEvent)->void:
	if event is InputEventScreenDrag or event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): player=event.position
	if caught and event.is_pressed():get_tree().reload_current_scene()

var size:Vector2:
	get:return get_viewport_rect().size

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("050713"))
	for guard in guards:
		var sight:=Vector2.from_angle(guard.angle); draw_colored_polygon(PackedVector2Array([guard.pos,guard.pos+sight.rotated(0.55)*170,guard.pos+sight.rotated(-0.55)*170]),Color(0.55,0.3,1,0.14));draw_circle(guard.pos,15,Color("a67bff"))
	draw_circle(shard,13,Color("fff07d"));draw_circle(player,14,Color("81fff0"))
	text(Vector2(28,42),"SHADOW CHASE",22,Color("d9d5ff"));text(Vector2(28,70),"FRAMMENTI RUBATI %02d"%stolen,16,Color("9e9bcf"))
	if caught:draw_rect(Rect2(Vector2.ZERO,size),Color(0.06,0,0.14,0.72));text(size*0.5+Vector2(-72,0),"TI HANNO VISTO",25,Color("f1c2ff"));text(size*0.5+Vector2(-108,32),"Tocca per svanire",16,Color.WHITE)

func text(pos:Vector2,value:String,font_size:int,color:Color)->void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
