extends Node2D

var player:=Vector2.ZERO
var enemies:Array[Dictionary]=[]
var shots:Array[Dictionary]=[]
var spawn:=0.0
var fire:=0.0
var xp:=0
var level:=1
var hp:=5

func _ready()->void:player=size*0.5

func _process(delta:float)->void:
	if hp<=0:return
	player=(player+Input.get_vector("ui_left","ui_right","ui_up","ui_down")*260*delta).clamp(Vector2(15,15),size-Vector2(15,15));spawn-=delta;fire-=delta
	if spawn<0:spawn=maxf(0.22,0.75-level*0.03);var edge: Vector2=[Vector2(randf_range(0,size.x),-30),Vector2(randf_range(0,size.x),size.y+30),Vector2(-30,randf_range(0,size.y)),Vector2(size.x+30,randf_range(0,size.y))].pick_random();enemies.append({"pos":edge,"hp":1+level/3})
	if fire<0 and not enemies.is_empty():fire=0.33;var closest:Dictionary=enemies.reduce(func(a:Dictionary,b:Dictionary)->Dictionary:return a if player.distance_to(a.pos)<player.distance_to(b.pos) else b);shots.append({"pos":player,"dir":(closest.pos-player).normalized()})
	for enemy in enemies:enemy.pos+=(player-enemy.pos).normalized()*(45+level*4)*delta;if enemy.pos.distance_to(player)<20:hp-=1;enemy.pos=Vector2(-999,-999)
	for shot in shots:shot.pos+=shot.dir*620*delta
	for shot in shots.duplicate():for enemy in enemies.duplicate():if shot.pos.distance_to(enemy.pos)<18:enemy.hp-=1;shots.erase(shot);if enemy.hp<=0:enemies.erase(enemy);xp+=1
	shots=shots.filter(func(s:Dictionary)->bool:return Rect2(Vector2.ZERO,size).grow(40).has_point(s.pos));enemies=enemies.filter(func(e:Dictionary)->bool:return e.pos.x>-100)
	if xp>=level*9:xp=0;level+=1;hp=min(5,hp+1)
	queue_redraw()

func _input(event:InputEvent)->void:
	if event is InputEventScreenDrag or event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):player=event.position
	if hp<=0 and event.is_pressed():get_tree().reload_current_scene()

var size:Vector2:
	get:return get_viewport_rect().size

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("09031d"));for enemy in enemies:draw_circle(enemy.pos,14,Color("ff5da2"));for shot in shots:draw_circle(shot.pos,4,Color("fff27d"));draw_circle(player,17,Color("8d7dff"));draw_arc(player,24,0,TAU,20,Color("e1dcff"),2)
	text(Vector2(28,42),"VOID SURVIVOR  •  LIVELLO %d"%level,22,Color("e4dfff"));text(Vector2(28,70),"SCUDI %d/5   ESSENZA %d/%d"%[hp,xp,level*9],16,Color("aca1dc"))
	if hp<=0:draw_rect(Rect2(Vector2.ZERO,size),Color(0.08,0,0.14,0.72));text(size*0.5+Vector2(-90,0),"IL VUOTO VINCE",25,Color("ffc6ef"));text(size*0.5+Vector2(-110,32),"Tocca per resistere",16,Color.WHITE)

func text(pos:Vector2,value:String,font_size:int,color:Color)->void:draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
