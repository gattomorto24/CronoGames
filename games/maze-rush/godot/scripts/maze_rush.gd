extends Node2D

const MAP := ["###############", "#...#.....#...#", "#.###.###.#.#.#", "#...#.#...#.#.#", "###.#.#.###.#.#", "#...#.#.....#.#", "#.###.#######.#", "#.............#", "###############"]
var cell := Vector2i(1, 1)
var key := Vector2i(13, 1)
var exit := Vector2i(13, 7)
var moves := 0
var unlocked := false
var complete := false

func _input(event: InputEvent) -> void:
	if not event.is_pressed(): return
	if complete: get_tree().reload_current_scene(); return
	var dir := Vector2i.ZERO
	if event is InputEventKey:
		if event.keycode in [KEY_LEFT, KEY_A]: dir = Vector2i.LEFT
		elif event.keycode in [KEY_RIGHT, KEY_D]: dir = Vector2i.RIGHT
		elif event.keycode in [KEY_UP, KEY_W]: dir = Vector2i.UP
		elif event.keycode in [KEY_DOWN, KEY_S]: dir = Vector2i.DOWN
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var center := size * 0.5; var d: Vector2 = event.position - center
		dir = Vector2i(int(sign(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, int(sign(d.y)))
	try_move(dir)

func try_move(dir: Vector2i) -> void:
	var next := cell + dir
	if dir == Vector2i.ZERO or next.y < 0 or next.y >= MAP.size() or next.x < 0 or next.x >= MAP[0].length() or MAP[next.y][next.x] == "#": return
	cell = next; moves += 1
	if cell == key: unlocked = true
	if cell == exit and unlocked: complete = true
	queue_redraw()

var size: Vector2:
	get: return get_viewport_rect().size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("071918"))
	var tile := minf((size.x - 130) / 15.0, (size.y - 140) / 9.0)
	var origin := (size - Vector2(tile * 15, tile * 9)) * 0.5 + Vector2(0, 25)
	for y in MAP.size():
		for x in MAP[y].length():
			var p := origin + Vector2(x, y) * tile
			draw_rect(Rect2(p, Vector2(tile - 2, tile - 2)), Color("27605c") if MAP[y][x] == "#" else Color("0c2825"))
	var key_pos := origin + Vector2(key) * tile + Vector2.ONE * tile * 0.5
	var exit_pos := origin + Vector2(exit) * tile + Vector2.ONE * tile * 0.5
	draw_circle(key_pos, tile * 0.22, Color("ffe679") if not unlocked else Color("536260"))
	draw_rect(Rect2(exit_pos - Vector2.ONE * tile * 0.24, Vector2.ONE * tile * 0.48), Color("8dffc5") if unlocked else Color("74474c"))
	var hero := origin + Vector2(cell) * tile + Vector2.ONE * tile * 0.5
	draw_circle(hero, tile * 0.27, Color("67f9e0"))
	text(Vector2(28, 42), "MAZE RUSH", 22, Color("b6fff1")); text(Vector2(28, 70), "MOSSE %d  •  %s" % [moves, "USCITA SBLOCCATA" if unlocked else "TROVA LA CHIAVE"], 16, Color("8ec5ba"))
	if complete: draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.12, 0.1, 0.72)); text(size * 0.5 + Vector2(-120, 0), "LABIRINTO RISOLTO", 26, Color("beffd2")); text(size * 0.5 + Vector2(-130, 32), "Tocca per una nuova mappa", 16, Color.WHITE)

func text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
