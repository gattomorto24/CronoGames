extends Node2D

var tiles:Array[int]=[]
var turns:=0
var solved:=false

func _ready()->void:for i in 16:tiles.append(randi_range(0,3))

func _input(event:InputEvent)->void:
	if not event.is_pressed():return
	if solved:get_tree().reload_current_scene();return
	var tile:=minf(size.x/4.8,size.y/5.6);var origin:=(size-Vector2(tile*4,tile*4))*0.5+Vector2(0,35);var c:=Vector2i((event.position-origin)/tile)
	if c.x>=0 and c.x<4 and c.y>=0 and c.y<4:
		for d in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:var p: Vector2i=c+d;if p.x>=0 and p.x<4 and p.y>=0 and p.y<4:tiles[p.y*4+p.x]=(tiles[p.y*4+p.x]+1)%4
		turns+=1;solved=tiles.all(func(v:int)->bool:return v==0);queue_redraw()

var size:Vector2:
	get:return get_viewport_rect().size

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b0820"));var tile:=minf(size.x/4.8,size.y/5.6);var origin:=(size-Vector2(tile*4,tile*4))*0.5+Vector2(0,35);var colors=[Color("ff83bb"),Color("77e9ff"),Color("fff27d"),Color("af8cff")]
	for y in 4:for x in 4:var p:=origin+Vector2(x,y)*tile;draw_rect(Rect2(p+Vector2(5,5),Vector2(tile-10,tile-10)),colors[tiles[y*4+x]]);draw_arc(p+Vector2.ONE*tile*0.5,tile*0.27,0,TAU,4,Color.WHITE,2)
	text(Vector2(28,42),"PRISM PUZZLE",22,Color("f0e7ff"));text(Vector2(28,70),"ROTAZIONI %03d  •  PORTA TUTTO AL BIANCO"%turns,16,Color("bcaee4"))
	if solved:draw_rect(Rect2(Vector2.ZERO,size),Color(0.06,0.03,0.17,0.72));text(size*0.5+Vector2(-92,0),"PRISMA ALLINEATO",25,Color("e4ffae"));text(size*0.5+Vector2(-110,32),"Tocca per rimescolare",16,Color.WHITE)

func text(pos:Vector2,value:String,font_size:int,color:Color)->void:draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
