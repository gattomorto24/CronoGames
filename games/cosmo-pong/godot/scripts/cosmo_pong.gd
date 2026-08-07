extends Node2D

var ball:=Vector2.ZERO
var vel:=Vector2(360,210)
var hero_y:=300.0
var cpu_y:=300.0
var hero:=0
var cpu:=0

func _ready()->void:ball=size*0.5;hero_y=size.y*0.5;cpu_y=size.y*0.5

func _process(delta:float)->void:
	hero_y=clampf(hero_y+Input.get_axis("ui_up","ui_down")*460*delta,55,size.y-55);cpu_y=move_toward(cpu_y,ball.y,235*delta);ball+=vel*delta
	if ball.y<12 or ball.y>size.y-12:vel.y*=-1
	if ball.x<75 and absf(ball.y-hero_y)<65:vel.x=absf(vel.x)*1.05;vel.y+=(ball.y-hero_y)*3
	if ball.x>size.x-75 and absf(ball.y-cpu_y)<65:vel.x=-absf(vel.x)*1.05;vel.y+=(ball.y-cpu_y)*3
	if ball.x<-20:cpu+=1;reset(-1)
	if ball.x>size.x+20:hero+=1;reset(1)
	queue_redraw()

func reset(direction:float)->void:ball=size*0.5;vel=Vector2(360*direction,randf_range(-230,230))

func _input(event:InputEvent)->void:if event is InputEventScreenDrag or event is InputEventMouseMotion:hero_y=event.position.y
var size:Vector2:
	get:return get_viewport_rect().size
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("050d27"));for y in range(0,int(size.y),28):draw_rect(Rect2(size.x*0.5-2,y,4,15),Color("2d4d85"));draw_rect(Rect2(46,hero_y-55,13,110),Color("8cf4ff"));draw_rect(Rect2(size.x-59,cpu_y-55,13,110),Color("ff9ccd"));draw_circle(ball,11,Color("fff4a8"));text(Vector2(size.x*0.5-70,55),"%d  :  %d"%[hero,cpu],32,Color("edf5ff"));text(Vector2(28,42),"COSMO PONG",20,Color("b8d7ff"))
func text(pos:Vector2,value:String,font_size:int,color:Color)->void:draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
