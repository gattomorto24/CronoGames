extends Node2D

var basket_x := 640.0
var crystals: Array[Dictionary] = []
var spawn := 0.0
var score := 0
var misses := 0
var over := false

func _process(delta: float) -> void:
	if over: return
	basket_x = clampf(basket_x + Input.get_axis("ui_left", "ui_right") * 520 * delta, 55, size.x - 55)
	spawn -= delta
	if spawn < 0:
		spawn = randf_range(0.28, 0.7); crystals.append({"pos": Vector2(randf_range(25, size.x - 25), -25), "speed": randf_range(160, 330), "value": randi_range(1, 3)})
	for crystal in crystals.duplicate():
		crystal.pos.y += crystal.speed * delta
		if crystal.pos.y > size.y - 92 and absf(crystal.pos.x - basket_x) < 62:
			score += crystal.value * 10; crystals.erase(crystal)
		elif crystal.pos.y > size.y + 20:
			misses += 1; crystals.erase(crystal)
	if misses >= 5: over = true
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		basket_x = clampf(event.position.x, 55, size.x - 55)
	if over and event.is_pressed(): get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("071b2b"))
	for crystal in crystals:
		var p: Vector2 = crystal.pos; draw_colored_polygon(PackedVector2Array([p + Vector2(0,-17),p + Vector2(13,0),p + Vector2(0,17),p + Vector2(-13,0)]), [Color("67efff"), Color("ce7aff"), Color("fff28c")][crystal.value - 1])
	draw_colored_polygon(PackedVector2Array([Vector2(basket_x - 56,size.y - 77),Vector2(basket_x + 56,size.y - 77),Vector2(basket_x + 39,size.y - 42),Vector2(basket_x - 39,size.y - 42)]), Color("e6b95f"))
	text(Vector2(28,42),"CRYSTAL CATCH",22,Color("d9fbff")); text(Vector2(28,70),"PUNTI %04d  •  CADUTI %d/5" % [score,misses],16,Color("8bc2df"))
	if over: draw_rect(Rect2(Vector2.ZERO,size),Color(0,0.05,0.12,0.72)); text(size*0.5+Vector2(-105,0),"SCORTA ESAURITA",25,Color("ffbd92")); text(size*0.5+Vector2(-115,32),"Tocca per ricaricare",16,Color.WHITE)

func text(pos: Vector2,value: String,font_size: int,color: Color) -> void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
