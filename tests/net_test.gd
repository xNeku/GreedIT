extends Node
## Test de red del mundo 3D: dos copias del juego, una HOST y otra CLIENTE.
##
## Uso (dos terminales, o la primera en segundo plano):
##   godot --headless --path . res://tests/net_test.tscn -- --role=host --port=7795
##   godot --headless --path . res://tests/net_test.tscn -- --role=client --port=7795
##
## El cliente: se conecta, ve al host, cambia de hueco, pega al muñeco con la espada (el host aplica el daño y lo
## devuelve a todos) y le dispara con la ballesta.
## El host: ve llegar al cliente, su arma, su posición y sus animaciones, y ve el daño en el muñeco.

const WORLD := "res://src/world/game_3d.tscn"

var role := "host"
var port := 7795
var _failures: Array[String] = []
var _world: Game3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	Net.mode = Net.Mode.HOST if role == "host" else Net.Mode.JOIN
	Net.port = port
	Net.address = "127.0.0.1"
	_world = (load(WORLD) as PackedScene).instantiate() as Game3D
	add_child(_world)
	(_run_host if role == "host" else _run_client).call_deferred()


func _run_host() -> void:
	var dummy := _world.dummies.get_node("Dummy1") as TrainingDummy3D
	if not await _wait_until(func() -> bool: return _world.players.get_child_count() >= 2, 20.0):
		_fail("el cliente no llegó a aparecer")
		return _finish()
	var client := _client_player()
	await _wait(0.3)
	print("[host] cliente conectado: jugador '%s' con %s" % [client.name, client.avatar.name])
	if client.avatar.equipped(EquipmentData.Slot.BODY) == null:
		_fail("el personaje del cliente no llegó vestido")
	if not await _wait_until(func() -> bool: return dummy.total_hits > 0, 25.0):
		_fail("el muñeco no recibió el daño del cliente")
	else:
		print("[host] el muñeco recibió %d golpe(s) del cliente" % dummy.total_hits)
	if not await _wait_until(func() -> bool: return client.current_weapon != null and client.current_weapon.id == &"sword", 5.0):
		_fail("no se ve el cambio de arma del cliente")
	else:
		print("[host] veo al cliente con: %s" % client.current_weapon.display_name)
	if client.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("no veo el escudo del cliente")
	else:
		print("[host] veo su escudo")
	if not await _wait_until(func() -> bool: return client.net_anim.begins_with("1H_Melee"), 8.0):
		_fail("no veo las animaciones de ataque del cliente (%s)" % client.net_anim)
	else:
		print("[host] veo su animación: %s" % client.net_anim.get_slice("#", 0))
	if client.global_position.distance_to(dummy.global_position) > 8.0:
		_fail("la posición del cliente no se sincroniza (%s)" % client.global_position)
	else:
		print("[host] el cliente está junto al muñeco: posición sincronizada")
	await _wait_until(func() -> bool: return _world.players.get_child_count() < 2, 40.0)
	print("[host] el cliente se ha ido")
	_finish()


func _run_client() -> void:
	if not await _wait_until(func() -> bool: return _world.local_player() != null, 20.0):
		_fail("no aparece mi jugador")
		return _finish()
	var me := _world.local_player()
	print("[cliente] conectado como peer %d con %s" % [multiplayer.get_unique_id(), me.avatar.name])
	if not await _wait_until(func() -> bool: return _world.players.has_node("1"), 10.0):
		_fail("no veo al jugador del host")
	else:
		print("[cliente] veo al host (%s)" % (_world.players.get_node("1") as Player3D).avatar.name)
	me.slot_index = 0 # espada y escudo
	await _wait(0.3)

	# 1) Espada: el host aplica el daño y nos devuelve los efectos.
	var dummy := _world.dummies.get_node("Dummy1") as TrainingDummy3D
	for i in 3:
		me.global_position = dummy.global_position + Vector3(0, 0, 1.6)
		me.velocity = Vector3.ZERO
		me.aim_target_override = dummy.global_position
		me.primary_down(); me.primary_up()
		await _wait(0.8)
	if not await _wait_until(func() -> bool: return dummy.total_hits > 0, 4.0):
		_fail("mis espadazos no llegan al muñeco")
	else:
		print("[cliente] el muñeco muestra %d golpe(s) (ida y vuelta por red)" % dummy.total_hits)

	# 2) Ballesta: los virotes se crean en todos, pero solo el mío hace daño.
	var before := dummy.total_hits
	me.slot_index = 4 # ballesta
	await _wait(0.2)
	me.global_position = dummy.global_position + Vector3(0, 0, 6)
	me.primary_down(); me.primary_up()
	if not await _wait_until(func() -> bool: return dummy.total_hits > before, 4.0):
		_fail("mis virotes no llegan al muñeco")
	else:
		print("[cliente] virote en el muñeco: %d golpe(s) más" % (dummy.total_hits - before))
	me.slot_index = 0
	me.global_position = dummy.global_position + Vector3(0, 0, 1.6)
	me.primary_down(); me.primary_up() # para que el host vea la animación de espada al final
	await _wait(1.5)
	_finish()


func _client_player() -> Player3D:
	for p in _world.players.get_children():
		if p.name != "1":
			return p
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait_until(condition: Callable, timeout: float) -> bool:
	var t := 0.0
	while not condition.call():
		if t >= timeout:
			return false
		await _wait(0.1)
		t += 0.1
	return true


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("[%s] FALLO: %s" % [role, message])


func _finish() -> void:
	print("NET %s %s" % [role.to_upper(), "OK" if _failures.is_empty() else "FAILED (%d)" % _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
