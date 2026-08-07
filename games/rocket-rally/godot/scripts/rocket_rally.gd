extends Node2D

var rocket:=Vector2.ZERO
var velocity:=Vector2.ZERO
var rings:PackedVector2Array=[]
var next:=0
var fuel:=100.0
var finished:=false

func _ready()->void:
	rocket=Vector2(90,size.y-90)
	for i in 9:rings.append(Vector2(150+i*(size.x-300)/8.0,randf_range(110,size.y-110)))

func _process(delta:float)->void:
	if finished:return
	var thrust:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if thrust.length()>0 and fuel>0:velocity+=thrust.normalized()*350*delta;fuel-=18*delta
	velocity*=0.988;rocket=(rocket+velocity*delta).clamp(Vector2(15,15),size-Vector2(15,15));fuel=minf(100,fuel+4*delta)
	if rocket.distance_to(rings[next])<34:next+=1;if next>=rings.size():finished=true
	queue_redraw()

func _input(event:InputEvent)->void:
	if event is InputEventScreenDrag:velocity+=(event.position-rocket).normalized()*21
	if finished and event.is_pressed():get_tree().reload_current_scene()

var size:Vector2:
	get:return get_viewport_rect().size

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("07152a"));for ring in rings:draw_arc(ring,28,0,TAU,30,Color("3f7ca8"),4);if next<rings.size():draw_arc(rings[next],32,0,TAU,30,Color("d9ff7b"),4)
	draw_colored_polygon(PackedVector2Array([rocket+Vector2(20,0),rocket+Vector2(-13,12),rocket+Vector2(-13,-12)]),Color("ff8d65"));draw_line(rocket-velocity.normalized()*26,rocket-velocity.normalized()*48,Color("ffe179"),5)
	text(Vector2(28,42),"ROCKET RALLY",22,Color("ddf5ff"));text(Vector2(28,70),"ANELLO %d/%d  •  CARBURANTE %d%%"%[next+1,rings.size(),int(fuel)],16,Color("89b9d8"))
	if finished:draw_rect(Rect2(Vector2.ZERO,size),Color(0.0,0.1,0.15,0.7));text(size*0.5+Vector2(-95,0),"RALLY COMPLETATO",25,Color("e3ff9b"));text(size*0.5+Vector2(-115,32),"Tocca per un nuovo circuito",16,Color.WHITE)

func text(pos:Vector2,value:String,font_size:int,color:Color)->void:draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
