extends Node2D

var y:=0.0
var vy:=0.0
var obstacles:Array[Dictionary]=[]
var spawn:=0.0
var distance:=0
var ended:=false

func _ready()->void:y=size.y-132

func _process(delta:float)->void:
	if ended:return
	vy+=1250*delta;y+=vy*delta
	if y>size.y-132:y=size.y-132;vy=0
	spawn-=delta
	if spawn<=0:spawn=randf_range(0.75,1.25);obstacles.append({"x":size.x+40,"h":randf_range(38,86)})
	for obstacle in obstacles:
		obstacle.x-=390*delta
		if obstacle.x<130 and obstacle.x+30>82 and y+30>size.y-104-obstacle.h:ended=true
	obstacles=obstacles.filter(func(o:Dictionary)->bool:return o.x>-50);distance+=int(95*delta);queue_redraw()

func _input(event:InputEvent)->void:
	if event.is_pressed():
		if ended:get_tree().reload_current_scene()
		elif y>=size.y-133:vy=-515

var size:Vector2:
	get:return get_viewport_rect().size

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("091330"));draw_circle(Vector2(size.x*0.78,110),55,Color("ffcf89"))
	for i in 12:var h:=80+(i%5)*53;draw_rect(Rect2(i*120-30,size.y-105-h,85,h+105),Color("182856"))
	draw_rect(Rect2(0,size.y-103,size.x,103),Color("101a32"))
	for obstacle in obstacles:draw_rect(Rect2(obstacle.x,size.y-103-obstacle.h,30,obstacle.h),Color("ff5b8f"))
	draw_circle(Vector2(82,y),25,Color("83ffe4"));draw_line(Vector2(60,y+30),Vector2(104,y+30),Color("d6fff9"),3)
	text(Vector2(28,42),"SKYLINE RUN",22,Color("e2edff"));text(Vector2(28,70),"METRI %04d"%distance,16,Color("98afd8"))
	if ended:draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0,0.1,0.68));text(size*0.5+Vector2(-80,0),"CORSA FINITA",26,Color("ffb8df"));text(size*0.5+Vector2(-120,32),"Tocca per saltare ancora",16,Color.WHITE)

func text(pos:Vector2,value:String,font_size:int,color:Color)->void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
