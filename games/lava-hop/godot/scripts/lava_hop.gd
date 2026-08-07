extends Node2D

var row := 0
var col := 2
var safe: Array[int] = []
var alive := true
var score := 0

func _ready() -> void:
	for y in 12: safe.append(randi_range(0, 4))

func _input(event: InputEvent) -> void:
	if not event.is_pressed(): return
	if not alive: get_tree().reload_current_scene(); return
	var dir := Vector2i.ZERO
	if event is InputEventKey:
		if event.keycode in [KEY_LEFT, KEY_A]: dir.x = -1
		elif event.keycode in [KEY_RIGHT, KEY_D]: dir.x = 1
		elif event.keycode in [KEY_UP, KEY_W, KEY_SPACE]: dir.y = 1
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var d: Vector2 = event.position - size * 0.5; dir = Vector2i(int(sign(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(-sign(d.y)))
	if dir.x != 0: col = clampi(col + dir.x, 0, 4)
	if dir.y > 0:
		row += 1; score += 1
		if col != safe[row % safe.size()]: alive = false
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("230805"))
	var tile := minf(size.x/5.7,size.y/8.8); var origin := Vector2((size.x-tile*5)/2,size.y-tile*7.1)
	for y in 7:
		for x in 5:
			var p:=origin+Vector2(x,y)*tile
			var platform:= x==safe[(row+6-y)%safe.size()]
			draw_rect(Rect2(p+Vector2(4,4),Vector2(tile-8,tile-8)),Color("76513c") if platform else Color("ee4e1d"))
			if not platform: draw_circle(p+Vector2(tile*0.5,tile*0.5),5,Color("ffca55"))
	var hero:=origin+Vector2(col,6)*tile+Vector2.ONE*tile*0.5; draw_circle(hero,tile*0.25,Color("bafeee"))
	text(Vector2(28,42),"LAVA HOP",22,Color("ffe0a2")); text(Vector2(28,70),"ISOLE %03d"%score,16,Color("f39a64"))
	if not alive: draw_rect(Rect2(Vector2.ZERO,size),Color(0.2,0,0,0.7)); text(size*0.5+Vector2(-85,0),"TROPPO CALDO",27,Color("ffd3a1")); text(size*0.5+Vector2(-110,32),"Tocca per riprovare",16,Color.WHITE)

func text(pos: Vector2,value: String,font_size: int,color: Color)->void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
