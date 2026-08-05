class_name CronoMobileArena
extends Node

const GAME_ID := "parkour"
const SEND_INTERVAL := 0.08

var socket := WebSocketPeer.new()
var owner_game: Node
var runner: Node3D
var player_id := ""
var room_code := ""
var server_url := ""
var send_left := 0.0
var joined := false

func start(game: Node, mobile_runner: Node3D) -> void:
	owner_game = game
	runner = mobile_runner
	room_code = room_code_from_url()
	server_url = resolve_server_url()
	if server_url.is_empty():
		owner_game.set_network_state("RUN LOCALE")
		return
	if socket.connect_to_url(server_url) != OK:
		owner_game.set_network_state("RUN LOCALE")
		return
	owner_game.set_network_state("CONNESSIONE…")

func _exit_tree() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify({"type": "leave"}))
	socket.close()

func _process(delta: float) -> void:
	if server_url.is_empty():
		return
	socket.poll()
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not joined:
		joined = true
		socket.send_text(JSON.stringify({"type": "join", "game": GAME_ID, "nickname": player_nickname(), "roomCode": room_code}))
		return
	while socket.get_available_packet_count() > 0:
		consume(socket.get_packet().get_string_from_utf8())
	send_left -= delta
	if not player_id.is_empty() and send_left <= 0.0:
		send_left = SEND_INTERVAL
		socket.send_text(JSON.stringify({"type": "input", "keys": current_keys(), "angle": runner.rotation.y, "jumping": owner_game.mobile_jump_active()}))

func consume(raw: String) -> void:
	var message = JSON.parse_string(raw)
	if not message is Dictionary:
		return
	match str(message.get("type", "")):
		"joined":
			player_id = str(message.get("id", ""))
			var code := ""
			if message.get("roomCode") != null:
				code = str(message.get("roomCode"))
			owner_game.set_network_state("CODICE " + code if not code.is_empty() else "ONLINE")
		"state":
			if str(message.get("game", "")) == GAME_ID:
				owner_game.sync_online_players(message, player_id)
		"error":
			owner_game.set_network_state("RUN LOCALE")

func current_keys() -> Array[String]:
	var keys: Array[String] = []
	var movement: Vector2 = owner_game.mobile_movement()
	if movement.x < -0.15: keys.append("a")
	if movement.x > 0.15: keys.append("d")
	if movement.y > 0.15: keys.append("w")
	if movement.y < -0.15: keys.append("s")
	return keys

func resolve_server_url() -> String:
	if OS.has_feature("web"):
		var configured := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('ws') || ''", true))
		if not configured.is_empty() and configured != "null":
			return configured
		var host := str(JavaScriptBridge.eval("window.location.hostname", true))
		var lan := bool(JavaScriptBridge.eval("(() => { const h = location.hostname; return h === 'localhost' || /^127\\./.test(h) || /^10\\./.test(h) || /^192\\.168\\./.test(h) || /^172\\.(1[6-9]|2[0-9]|3[0-1])\\./.test(h) || h.endsWith('.local'); })()", true))
		if lan:
			var protocol := str(JavaScriptBridge.eval("window.location.protocol === 'https:' ? 'wss:' : 'ws:'", true))
			var port := str(JavaScriptBridge.eval("window.location.port || '3001'", true))
			return "%s//%s:%s" % [protocol, host, port]
	return OS.get_environment("CRONOGAMES_WS_URL")

func room_code_from_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room') || ''", true)).to_upper().replace(" ", "")
	return ""

func player_nickname() -> String:
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.get_interface("window").localStorage.getItem("cronogames_account")
		if stored:
			var account = JSON.parse_string(stored)
			if account is Dictionary and account.has("username"):
				return str(account.username)
	return "Runner"
