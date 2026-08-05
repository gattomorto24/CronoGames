extends Node

const GAME_ID := "parkour"
const SERVER_TICK_INTERVAL := 0.08

var socket := WebSocketPeer.new()
var player_id := ""
var room_id := ""
var server_url := ""
var send_timer := 0.0
var remote_avatars: Dictionary = {}
var status_label: Label

func _ready() -> void:
	build_status()
	call_deferred("connect_to_room")

func _exit_tree() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify({"type": "leave"}))
	socket.close()

func connect_to_room() -> void:
	server_url = resolve_server_url()
	if server_url.is_empty():
		set_status("OFFLINE · Avvia il server CronoGames per le stanze online")
		return
	if socket.connect_to_url(server_url) != OK:
		set_status("OFFLINE · Server non raggiungibile")
		return
	set_status("CONNESSIONE ALLA STANZA…")

func _process(delta: float) -> void:
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			consume_message(socket.get_packet().get_string_from_utf8())
		send_timer += delta
		if not player_id.is_empty() and send_timer >= SERVER_TICK_INTERVAL:
			send_timer = 0.0
			socket.send_text(JSON.stringify({"type": "input", "keys": current_keys(), "angle": 0.0, "jumping": Input.is_action_pressed("go_up")}))
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED and not server_url.is_empty() and player_id.is_empty():
		set_status("OFFLINE · Server non raggiungibile")

func consume_message(raw: String) -> void:
	var decoded = JSON.parse_string(raw)
	if not decoded is Dictionary:
		return
	if decoded.type == "joined":
		player_id = str(decoded.id)
		room_id = str(decoded.roomId)
		set_status("ONLINE · %s · stanza %s" % [str(decoded.capacity), room_id])
	elif decoded.type == "state":
		apply_state(decoded)
	elif decoded.type == "notice":
		set_status(str(decoded.message))

func current_keys() -> Array[String]:
	var keys: Array[String] = []
	if Input.is_action_pressed("forward"): keys.append("w")
	if Input.is_action_pressed("backward"): keys.append("s")
	if Input.is_action_pressed("left"): keys.append("a")
	if Input.is_action_pressed("right"): keys.append("d")
	return keys

func apply_state(state: Dictionary) -> void:
	if str(state.get("game", "")) != GAME_ID:
		return
	set_status("ONLINE · %s giocatori · %s bot · %s" % [str(state.get("humans", 0)), str(state.get("bots", 0)), room_id])
	var active := {}
	var rendered := 0
	var remote_limit := 8 if is_touch_device() else 20
	var actors: Array = state.get("players", []).duplicate()
	actors.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return not bool(first.get("bot", false)) and bool(second.get("bot", false)))
	for actor in actors:
		var actor_id := str(actor.get("id", ""))
		if actor_id == player_id or actor_id.is_empty():
			continue
		if rendered >= remote_limit:
			continue
		rendered += 1
		active[actor_id] = true
		var avatar: Node3D = remote_avatars.get(actor_id)
		if avatar == null:
			avatar = create_avatar(str(actor.get("nickname", "Runner")), bool(actor.get("bot", false)))
			remote_avatars[actor_id] = avatar
			get_parent().add_child(avatar)
		var target := Vector3(-25.0 + float(actor.get("x", 60.0)) / 120.0 * 50.0, 1.0, -15.0 + float(actor.get("y", 60.0)) / 120.0 * 30.0)
		avatar.global_position = avatar.global_position.lerp(target, 0.2)
	for actor_id in remote_avatars.keys():
		if active.has(actor_id):
			continue
		var stale: Node3D = remote_avatars[actor_id]
		stale.queue_free()
		remote_avatars.erase(actor_id)

func create_avatar(name_text: String, is_bot: bool) -> Node3D:
	var avatar := Node3D.new()
	avatar.name = "Remote_" + name_text
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.5
	mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7ae8ff") if is_bot else Color("ffcf73")
	material.emission_enabled = true
	material.emission = material.albedo_color.darkened(0.35)
	mesh.material_override = material
	avatar.add_child(mesh)
	var label := Label3D.new()
	label.text = name_text + (" · BOT" if is_bot else "")
	label.position = Vector3(0.0, 1.25, 0.0)
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color("dffaff") if is_bot else Color("fff0d0")
	avatar.add_child(label)
	return avatar

func build_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(18, 18)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("e9f6ff"))
	status_label.add_theme_color_override("font_outline_color", Color("0a1020"))
	status_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(status_label)
	set_status("PREPARAZIONE ARENA…")

func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func resolve_server_url() -> String:
	if OS.has_feature("web"):
		var configured = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('ws') || ''", true))
		if not configured.is_empty() and configured != "null":
			return configured
		var hostname = str(JavaScriptBridge.eval("window.location.hostname", true))
		var is_lan_host = bool(JavaScriptBridge.eval("(() => { const h = location.hostname; return h === 'localhost' || /^127\\./.test(h) || /^10\\./.test(h) || /^192\\.168\\./.test(h) || /^172\\.(1[6-9]|2[0-9]|3[0-1])\\./.test(h) || h.endsWith('.local'); })()", true))
		if is_lan_host:
			var protocol = str(JavaScriptBridge.eval("window.location.protocol === 'https:' ? 'wss:' : 'ws:'", true))
			var port = str(JavaScriptBridge.eval("window.location.port || '3001'", true))
			return "%s//%s:%s" % [protocol, hostname, port]
	return OS.get_environment("CRONOGAMES_WS_URL")

func is_touch_device() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(pointer: coarse)').matches", true))
	return false
