extends Node2D

var drone:=Vector2.ZERO
var target:=Vector2.ZERO
var bots:Array[Dictionary]=[]
var bolts:Array[Dictionary]=[]
var cooldown:=0.0
var points:=0
var hp:=3

func _ready()->void:
	drone=size*0.5;target=drone+Vector2.RIGHT
	for i in 12:bots.append({"pos":Vector2(randf_range(40,size.x-40),randf_range(70,size.y-40)),"phase":randf()*TAU})

func _process(delta:float)->void:
	if hp<=0:return
	drone=(drone+Input.get_vector("ui_left","ui_right","ui_up","ui_down")*280*delta).clamp(Vector2(20,20),size-Vector2(20,20));cooldown-=delta
	for bot in bots:
		bot.phase+=delta;bot.pos+=(drone-bot.pos).normalized()*45*delta+Vector2(cos(bot.phase),sin(bot.phase))*35*delta
		if bot.pos.distance_to(drone)<19:hp-=1;bot.pos=Vector2(-999,-999)
	for bolt in bolts:bolt.pos+=bolt.dir*680*delta
	for bolt in bolts.duplicate():for bot in bots.duplicate():if bolt.pos.distance_to(bot.pos)<16:bolts.erase(bolt);bots.erase(bot);points+=1
	bots=bots.filter(func(b:Dictionary)->bool:return b.pos.x>-100);bolts=bolts.filter(func(b:Dictionary)->bool:return Rect2(Vector2.ZERO,size).grow(30).has_point(b.pos))
	if bots.size()<4:for i in 9:bots.append({"pos":Vector2(randf_range(20,size.x-20),randf_range(50,size.y-20)),"phase":randf()*TAU})
	queue_redraw()

func _input(event:InputEvent)->void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:target=event.position
	if event.is_pressed() and cooldown<=0 and hp>0:cooldown=0.18;bolts.append({"pos":drone,"dir":(target-drone).normalized()})
	if hp<=0 and event.is_pressed():get_tree().reload_current_scene()

var size:Vector2:
	get:return get_viewport_rect().size
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("071d20"));for x in range(0,int(size.x),55):draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.12,0.45,0.44,0.18));for bot in bots:draw_circle(bot.pos,12,Color("ff8472"));for bolt in bolts:draw_circle(bolt.pos,4,Color("fff18a"));draw_circle(drone,18,Color("66f8e4"));draw_line(drone,drone+(target-drone).normalized()*29,Color.WHITE,3);text(Vector2(28,42),"DRONE ARENA",22,Color("dafffb"));text(Vector2(28,70),"ELIMINATI %03d  •  INTEGRITÀ %d/3"%[points,hp],16,Color("91c6c0"));if hp<=0:draw_rect(Rect2(Vector2.ZERO,size),Color(0.1,0,0,0.7));text(size*0.5+Vector2(-92,0),"DRONE DISTRUTTO",25,Color("ffb1a4"));text(size*0.5+Vector2(-112,32),"Tocca per ricostruire",16,Color.WHITE)
func text(pos:Vector2,value:String,font_size:int,color:Color)->void:draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
