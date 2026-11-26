extends Node
## Test de red: dos copias del juego en este ordenador, una HOST y otra CLIENTE.
##
## Uso (dos terminales, o la primera en segundo plano):
##   godot --headless --path . res://tests/net_test.tscn -- --role=host --port=7790
##   godot --headless --path . res://tests/net_test.tscn -- --role=client --port=7790
##
## El cliente: se conecta, ve al host y a los mobs, cambia de arma, pega al muñeco (el daño lo aplica
## el host y vuelve a todos), recibe golpes de un goblin del host y le pega hasta matarlo.
## El host: ve llegar al cliente, ve su arma y su posición, y ve el daño en el muñeco.

const WORLD := "res://src/world/sandbox.tscn"

var role := "host"
var port := 7790
var _failures: Array[String] = []
var _world: Game


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	Net.mode = Net.Mode.HOST if role == "host" else Net.Mode.JOIN
	Net.port = port
	Net.address = "127.0.0.1"
	Net.appearance_index = 0 if role == "host" else 1
	_world = (load(WORLD) as PackedScene).instantiate()
	add_child(_world)
	(_run_host if role == "host" else _run_client).call_deferred()


func _run_host() -> void:
	var dummy := _world.get_node("World/TrainingDummy1") as TrainingDummy
	if not await _wait_until(func() -> bool: return _world.players.get_child_count() >= 2, 20.0):
		_fail("el cliente no llegó a aparecer")
		return _finish()
	var client := _client_player()
	for node in _world.get_node("World").get_children():
		if node is Enemy:
			node.drop_chance = 1.0 # para comprobar que el botín llega al cliente
	print("[host] cliente conectado: jugador '%s', aspecto %d" % [client.name, client.appearance_index])
	if client.appearance_index != 1:
		_fail("el aspecto del cliente no llegó")
	if not await _wait_until(func() -> bool: return dummy._total > 0, 25.0):
		_fail("el muñeco no recibió el daño del cliente")
	else:
		print("[host] el muñeco recibió %d de daño del cliente" % dummy._total)
	if not await _wait_until(func() -> bool: return client.current_weapon != null and client.current_weapon.data.id == &"sword", 5.0):
		_fail("no se ve el cambio de arma del cliente")
	else:
		print("[host] veo al cliente con: %s" % client.current_weapon.data.display_name)
	if client.global_position.distance_to(dummy.global_position) > 80.0:
		_fail("la posición del cliente no se sincroniza (%s)" % client.global_position)
	else:
		print("[host] el cliente está junto al muñeco: posición sincronizada")
	# Esperar a que el cliente termine y se vaya.
	await _wait_until(func() -> bool: return _world.players.get_child_count() < 2, 40.0)
	print("[host] el cliente se ha ido")
	_finish()


func _run_client() -> void:
	if not await _wait_until(func() -> bool: return _world.local_player() != null, 20.0):
		_fail("no aparece mi jugador")
		return _finish()
	var me := _world.local_player()
	print("[cliente] conectado como peer %d" % multiplayer.get_unique_id())
	if not await _wait_until(func() -> bool: return _world.players.has_node("1"), 10.0):
		_fail("no veo al jugador del host")
	else:
		print("[cliente] veo al host")
	if not await _wait_until(func() -> bool: return _enemies().size() > 0, 10.0):
		_fail("no veo los mobs del host")
	else:
		print("[cliente] veo %d mobs replicados" % _enemies().size())
	me.select_slot(1) # espada
	await _wait(0.3)

	# 1) Pegar al muñeco: el host aplica el daño y nos lo devuelve en sus efectos.
	var dummy := _world.get_node("World/TrainingDummy1") as TrainingDummy
	for i in 4:
		_attack(me, dummy.global_position + Vector2(-38, 0), dummy.hurtbox.global_position)
		await _wait(0.45)
	if not await _wait_until(func() -> bool: return dummy._total > 0, 4.0):
		_fail("mis golpes no llegan al muñeco")
	else:
		print("[cliente] el muñeco muestra %d de daño (ida y vuelta por red)" % dummy._total)
	await _wait(1.0) # que el host vea la posición

	# 2) Un goblin del host me ataca.
	var goblin := _first_enemy("Goblin")
	if goblin == null:
		_fail("no hay goblins")
		return _finish()
	me.global_position = goblin.global_position + Vector2(-34, 0)
	me.health = me.max_health
	if not await _wait_until(func() -> bool: return me.health < me.max_health, 6.0):
		_fail("los mobs del host no me hacen daño")
	else:
		print("[cliente] un goblin me quitó %d de vida" % (me.max_health - me.health))

	# 3) Matar a un goblin.
	var start_health := goblin.health
	var t := 0.0
	while is_instance_valid(goblin) and goblin.net_anim.get_slice("#", 0) != "die" and t < 10.0:
		me.health = me.max_health
		_attack(me, goblin.global_position + Vector2(-30, 0), goblin.hurtbox.global_position)
		await _wait(0.4)
		t += 0.4
	if is_instance_valid(goblin) and goblin.net_anim.get_slice("#", 0) != "die":
		_fail("no consigo matar al goblin (vida %d -> %d)" % [start_health, goblin.health])
	else:
		print("[cliente] goblin muerto en %.1fs" % t)
		if not await _wait_until(func() -> bool: return me.inventory.count_by_id(&"goblin_ear") > 0, 3.0):
			_fail("el botín del goblin no me llega")
		else:
			print("[cliente] botín recibido: %d oreja(s) de goblin" % me.inventory.count_by_id(&"goblin_ear"))
	_finish()


func _attack(me: Player, at: Vector2, aim: Vector2) -> void:
	me.global_position = at
	me.velocity = Vector2.ZERO
	me.aim_target_override = aim
	me.draw_weapon()
	me._aim_at_target()
	me.weapon_action(Player.WeaponAction.PRIMARY_DOWN)
	me.weapon_action(Player.WeaponAction.PRIMARY_UP)


func _client_player() -> Player:
	for p in _world.players.get_children():
		if p.name != "1":
			return p
	return null


func _enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in _world.get_node("World").get_children():
		if node is Enemy:
			list.append(node)
	return list


func _first_enemy(prefix: String) -> Enemy:
	for e in _enemies():
		if String(e.name).begins_with(prefix) and e.health > 0:
			return e
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
