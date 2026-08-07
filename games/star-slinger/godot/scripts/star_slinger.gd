extends Node2D

var anchor := Vector2(130, 570)
var star := Vector2.ZERO
var velocity := Vector2.ZERO
var dragging := false
var targets: Array[Vector2] = []
var ammo := 5

func _ready() -> void:
	star = anchor
	for i in 7: targets.append(Vector2(randf_range(size.x*0.57,size.x-80),randf_range(100,size.y-100)))

func _process(delta: float) -> void:
	if velocity.length() > 0:
		velocity.y += 360*delta; star += velocity*delta
		for target in targets.duplicate():
			if star.distance_to(target)<35: targets.erase(target)
		if not Rect2(Vector2.ZERO,size).grow(90).has_point(star): velocity=Vector2.ZERO; star=anchor; ammo-=1
	queue_redraw()

func _input(event: InputEvent)->void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed and star.distance_to(anchor)<4: dragging=true
		elif not event.pressed and dragging:
			velocity=(anchor-event.position).limit_length(250)*3.1; dragging=false
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if dragging: star=event.position.clamp(anchor-Vector2(120,120),anchor+Vector2(90,120))
	if (ammo<=0 or targets.is_empty()) and event.is_pressed() and not dragging: get_tree().reload_current_scene()

var size: Vector2:
	get:return get_viewport_rect().size

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0a0727"))
	for target in targets: draw_circle(target,24,Color("ff79b7")); draw_arc(target,32,0,TAU,22,Color("ffd6eb"),2)
	draw_line(anchor,star,Color("8fd9ff"),4); draw_circle(anchor,15,Color("b9f3ff")); draw_circle(star,14,Color("fff381"))
	text(Vector2(28,42),"STAR SLINGER",22,Color("e5deff"));text(Vector2(28,70),"BERSAGLI %d  •  STELLE %d"%[targets.size(),ammo],16,Color("af9ee8"))
	if targets.is_empty(): text(size*0.5+Vector2(-92,0),"COSTELLAZIONE LIBERA",22,Color("fff9a4"))
	elif ammo<=0: text(size*0.5+Vector2(-104,0),"SCORTE TERMINATE",22,Color("ffbadf"))

func text(pos:Vector2,value:String,font_size:int,color:Color)->void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
