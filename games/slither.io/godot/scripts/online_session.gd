extends Node

var socket := WebSocketPeer.new()
var game: Node
var nickname := "Pilota"
var skin := "mint"
var player_id := ""
var send_timer := 0.0
var server_url := ""
var room_code := ""
var join_sent := false

func start_session(game_ref: Node, nickname_value: String, skin_value: String) -> void:
	game = game_ref
	nickname = nickname_value if not nickname_value.is_empty() else "Pilota"
	skin = skin_value
	room_code = room_code_from_url()
	server_url = resolve_server_url()
	if server_url.is_empty():
		game.announce("Arena locale · aggiungi ?ws=wss://tuo-server per il multiplayer pubblico")
		return
	if socket.connect_to_url(server_url) != OK:
		game.announce("Arena locale · server multiplayer non raggiungibile")

func _exit_tree() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify({"type": "leave"}))
	socket.close()

func _process(delta: float) -> void:
	socket.poll()
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not join_sent:
		join_sent = true
		socket.send_text(JSON.stringify({"type": "join", "game": "slither", "nickname": nickname, "skin": skin, "roomCode": room_code}))
		return
	while socket.get_available_packet_count() > 0:
		consume(socket.get_packet().get_string_from_utf8())
	if player_id.is_empty():
		return
	send_timer += delta
	if send_timer >= 0.07:
		send_timer = 0.0
		socket.send_text(JSON.stringify({"type": "input", "keys": current_keys(), "angle": game.player.direction.angle(), "shooting": Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("cg_slither_boost")}))

func consume(raw: String) -> void:
	var message = JSON.parse_string(raw)
	if not message is Dictionary:
		return
	match str(message.get("type", "")):
		"joined":
			player_id = str(message.get("id", ""))
			var code = str(message.get("roomCode", ""))
			game.announce("ONLINE · %s · bot attivi" % ("Codice " + code if not code.is_empty() else "Stanza " + str(message.get("roomId", ""))))
		"state": game.apply_online_state(message, player_id)
		"notice": game.announce(str(message.get("message", "")))
		"error": game.announce(str(message.get("message", "Errore di connessione.")))

func current_keys() -> Array[String]:
	var keys: Array[String] = []
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("cg_slither_up"): keys.append("w")
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("cg_slither_down"): keys.append("s")
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("cg_slither_left"): keys.append("a")
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("cg_slither_right"): keys.append("d")
	return keys

func resolve_server_url() -> String:
	if OS.has_feature("web"):
		var configured = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('ws') || ''", true))
		if not configured.is_empty() and configured != "null": return configured
		var host = str(JavaScriptBridge.eval("window.location.hostname", true))
		var is_lan_host = bool(JavaScriptBridge.eval("(() => { const h = location.hostname; return h === 'localhost' || /^127\\./.test(h) || /^10\\./.test(h) || /^192\\.168\\./.test(h) || /^172\\.(1[6-9]|2[0-9]|3[0-1])\\./.test(h) || h.endsWith('.local'); })()", true))
		if is_lan_host:
			var protocol = str(JavaScriptBridge.eval("window.location.protocol === 'https:' ? 'wss:' : 'ws:'", true))
			var port = str(JavaScriptBridge.eval("window.location.port || '3001'", true))
			return "%s//%s:%s" % [protocol, host, port]
	return OS.get_environment("CRONOGAMES_WS_URL")

func room_code_from_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room') || ''", true)).to_upper().replace(" ", "")
	return ""
