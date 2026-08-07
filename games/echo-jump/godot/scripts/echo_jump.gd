extends Node2D

var beat := 0.0
var combo := 0
var best := 0
var life := 4
var started := false
var flash := 0.0

func _process(delta: float) -> void:
	if started:
		beat = fmod(beat + delta * 0.82, 1.0); flash = maxf(0, flash - delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not event.is_pressed(): return
	if not started: started = true; return
	var timing := absf(beat - 0.5)
	if timing < 0.12:
		combo += 1; best = max(best, combo); flash = 0.22
	else:
		life -= 1; combo = 0
		if life <= 0: started = false; life = 4; combo = 0

var size: Vector2:
	get: return get_viewport_rect().size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("06121e"))
	var c := size * 0.5
	var radius := lerpf(280.0, 45.0, beat)
	draw_arc(c, 92, 0, TAU, 64, Color("2c6b7b"), 4)
	draw_arc(c, radius, 0, TAU, 64, Color("8bfff2") if flash > 0 else Color("548c9c"), 9)
	draw_circle(c, 34, Color("eafff9")); draw_circle(c, 16, Color("3edbcb"))
	text(Vector2(28, 42), "ECHO JUMP", 22, Color("d9ffff")); text(Vector2(28, 70), "COMBO %02d  •  RECORD %02d  •  VITE %d" % [combo, best, life], 16, Color("85bec6"))
	if not started: text(c + Vector2(-155, 150), "TOCCA QUANDO L'ONDA TOCCA IL CERCHIO", 17, Color("dffdfa"))

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
