extends Node
## Test de humo del mundo 3D.
## - Aparece el jugador con su personaje y la cámara lo sigue.
## - Se mueve con WASD relativo a la cámara (isométrica), salta hacia donde corre (y esquiva golpes) y esquiva.
## - Cada arma hace daño al muñeco con todos sus ataques: clic, mantener (carga o ráfaga), clic derecho,
##   mantener clic derecho (salto aplastante) y ataque en el aire.
## - Bola de fuego con maná.
## - Equipo: escudo con armas de una mano, casco y capa de serie, armadura con esqueleto.
## - Cambio de personaje.
##
## Uso:   godot --headless --path . res://tests/smoke_test_3d.tscn
## Con capturas (necesita render, no --headless):
##        godot --path . res://tests/smoke_test_3d.tscn -- --shots=/ruta/carpeta

var _failures: Array[String] = []
var _shots_dir := ""
var _scene: Game3D
var _player: Player3D
var _dummy: TrainingDummy3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	_scene = (load("res://src/game3d/world/game_3d.tscn") as PackedScene).instantiate() as Game3D
	add_child(_scene)
	await _wait(0.5)
	_player = _scene.players.get_node_or_null("1") as Player3D
	_dummy = _scene.dummies.get_node("Dummy1") as TrainingDummy3D
	if _player == null or _player.avatar == null:
		_fail("no aparece el jugador 3D")
		return _finish()
	print("jugador 3D: %s con %s" % [_player.avatar.name, _player.current_weapon.display_name])
	await _shot("00_overview")

	await _test_movement()
	for i in _player.weapons.size():
		await _test_weapon(i)
	await _test_fireball()
	await _test_equipment()
	await _test_avatars()
	_finish()


func _test_movement() -> void:
	# Con la cámara isométrica (girada 45°), "derecha" en el teclado = derecha en pantalla.
	var cam := _player.get_viewport().get_camera_3d() as FollowCamera3D
	if not cam.isometric:
		_fail("la cámara no empieza en isométrica")
	var start := _player.global_position
	_player.move_input_override = Vector2(1, 0)
	await _wait(0.5)
	_player.move_input_override = null
	await _wait(0.2)
	var moved := _player.global_position - start
	var screen_right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
	if moved.length() < 1.5 or moved.normalized().dot(screen_right) < 0.9:
		_fail("el movimiento no va hacia la derecha de la pantalla (%s)" % moved)
	# Salto estilo Conquer: hacia donde corres, con aterrizaje.
	start = _player.global_position
	_player.move_input_override = Vector2(0, -1)
	await _wait(0.1)
	_player.jump()
	await _wait(0.25)
	if _player.global_position.y < 0.8:
		_fail("el salto no eleva al jugador (y = %.2f)" % _player.global_position.y)
	if not _player.is_invulnerable():
		_fail("en lo alto del salto deberías esquivar los golpes")
	_player.move_input_override = null
	await _wait(1.0)
	if not _player.is_on_floor():
		_fail("el jugador no vuelve al suelo tras saltar")
	if (_player.global_position - start).length() < 3.0:
		_fail("el salto no avanza hacia donde corres")
	var before := _player.global_position
	_player.dodge()
	await _wait(0.35)
	if _player.global_position.distance_to(before) < 2.0:
		_fail("la esquiva no desplaza al jugador")
	print("movimiento (relativo a la cámara), salto y esquiva OK")


## Coloca al jugador a `distance` del muñeco, apuntándole.
func _place(distance: float) -> void:
	_player._cancel_attack()
	_player._cancel_charge()
	_player.global_position = _dummy.global_position + Vector3(0, 0, distance)
	_player.velocity = Vector3.ZERO
	_player.aim_target_override = _dummy.global_position
	await _wait(0.2)


func _check(label: String, hits_before: int, at_least: int = 1) -> void:
	var got := _dummy.total_hits - hits_before
	if got < at_least:
		_fail("%s: %d golpe(s), esperaba %d" % [label, got, at_least])
	else:
		print("  %s: %d golpe(s)" % [label, got])


func _test_weapon(index: int) -> void:
	_player.weapon_index = index
	var w := _player.current_weapon
	var ranged := w.kind != Weapon3DData.Kind.MELEE
	var near := 6.0 if ranged else w.reach * 0.5 + 0.7
	print("%d %s" % [index + 1, w.display_name])
	# Pulsar = combo
	await _place(near)
	var hits := _dummy.total_hits
	_player.primary_down()
	await _wait(0.05)
	_player.primary_up()
	await _wait(0.4)
	await _shot("w%d_%s_combo" % [index + 1, w.id])
	await _wait(0.6)
	await _check("clic", hits)
	# Mantener = carga o ráfaga
	if w.hold_mode == Weapon3DData.HoldMode.CHARGE and w.heavy:
		await _place(2.0 if w.heavy.area else near)
		hits = _dummy.total_hits
		_player.primary_down()
		await _wait(w.max_charge_time + 0.3)
		if not _player.charging:
			_fail("%s: al mantener no carga" % w.display_name)
		await _shot("w%d_%s_charge" % [index + 1, w.id])
		_player.primary_up()
		await _wait(0.45)
		await _shot("w%d_%s_heavy" % [index + 1, w.id])
		await _wait(1.0)
		await _check("cargado", hits)
	elif w.hold_mode == Weapon3DData.HoldMode.REPEAT:
		await _place(near)
		hits = _dummy.total_hits
		_player.primary_down()
		await _wait(1.6)
		_player.primary_up()
		await _wait(0.6)
		await _check("ráfaga", hits, 2)
	# Clic derecho
	if w.alt:
		var alt_near := 2.0 if w.alt.area else (4.0 if w.alt.leap == Attack3D.Leap.BACKWARD else near)
		await _place(alt_near)
		hits = _dummy.total_hits
		_player.secondary_down()
		await _wait(0.05)
		_player.secondary_up()
		await _wait(0.45)
		await _shot("w%d_%s_alt" % [index + 1, w.id])
		await _wait(1.2)
		await _check("clic derecho", hits)
	# Mantener clic derecho (salto aplastante)
	if w.alt_hold:
		await _place(6.0)
		hits = _dummy.total_hits
		_player.secondary_down()
		await _wait(0.5)
		_player.secondary_up()
		await _wait(0.3)
		await _shot("w%d_%s_leap" % [index + 1, w.id])
		await _wait(1.3)
		await _check("salto aplastante", hits)
		if _player.global_position.distance_to(_dummy.global_position) > 2.5:
			_fail("el salto aplastante no te lleva hacia el ratón")
	# En el aire
	if w.air:
		await _place(1.6 if not ranged else 6.0)
		hits = _dummy.total_hits
		_player.jump()
		await _wait(0.3)
		_player.primary_down()
		await _wait(0.05)
		_player.primary_up()
		await _wait(0.25)
		await _shot("w%d_%s_air" % [index + 1, w.id])
		await _wait(1.2)
		await _check("en el aire", hits)
	_player.aim_target_override = null
	if w.allows_shield and _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("%s debería llevar escudo" % w.display_name)
	if w.offhand_scene and _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("%s debería llevar arma en la otra mano" % w.display_name)


func _test_fireball() -> void:
	_player.weapon_index = 1
	await _place(7.0)
	_player.mana = _player.max_mana
	var hits := _dummy.total_hits
	_player.cast_spell()
	if _player.mana > _player.max_mana - _player.spell.mana_cost + 1.0:
		_fail("la bola de fuego no gasta maná")
	await _wait(0.5)
	await _shot("85_fireball")
	await _wait(0.8)
	await _check("bola de fuego", hits)
	_player.mana = 1.0
	var before := _player.mana
	_player.cast_spell()
	if _player.is_attacking():
		_fail("sin maná no debería lanzar")
	_player.mana = maxf(before, _player.mana)
	_player.aim_target_override = null


func _test_equipment() -> void:
	_player.weapon_index = 1 # espada y escudo
	_player.global_position = _dummy.global_position + Vector3(0, 0, 4)
	await _wait(0.2)
	# El explorador (Quaternius): ropa y capucha de serie con su esqueleto; la capucha se quita con H.
	if _player.avatar.equipped(EquipmentData.Slot.OUTFIT) == null or _player.avatar.equipped(EquipmentData.Slot.HEAD) == null:
		_fail("el explorador no lleva su ropa y su capucha")
	_player.avatar_index = 2 # caballero (KayKit): casco de serie
	await _wait(0.2)
	var helmet := _player.avatar.skeleton.find_child("Knight_Helmet", true, false) as Node3D
	if helmet == null or not helmet.visible:
		_fail("el casco de serie no se ve")
	_player.helmet_on = false
	_player.cape_on = false
	_player.shield_on = false
	await _wait(0.1)
	if helmet.visible:
		_fail("H no quita el casco")
	if _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) != null:
		_fail("V no quita el escudo")
	await _shot("80_sin_casco")
	_player.helmet_on = true
	_player.cape_on = true
	_player.shield_on = true
	_player.avatar_index = 4 # maga (KayKit), con la armadura de caballero encima
	_player.chest_on = true
	await _wait(0.3)
	var armor := _player.avatar.equipped(EquipmentData.Slot.CHEST)
	var body := _player.avatar.skeleton.find_child("Mage_Body", false, false) as Node3D
	var dressed := _player.avatar.skeleton.find_child("Knight_Body", false, false) as MeshInstance3D
	if armor == null or dressed == null:
		_fail("la armadura con esqueleto no se viste")
	elif body.visible:
		_fail("la armadura no oculta el cuerpo de debajo")
	elif dressed.get_node_or_null(dressed.skeleton) != _player.avatar.skeleton:
		_fail("la armadura no usa el esqueleto del personaje")
	else:
		print("armadura con esqueleto OK (Knight_Body sobre la maga)")
	_player.weapon_index = 0
	_player.primary_down()
	_player.primary_up()
	await _wait(0.25)
	await _shot("81_maga_con_armadura")
	await _wait(0.6)
	_player.chest_on = false
	await _wait(0.1)
	if not body.visible:
		_fail("al quitar la armadura no vuelve el cuerpo")


func _test_avatars() -> void:
	var names: PackedStringArray = []
	for i in _player.avatars.size():
		_player.avatar_index = i
		await _wait(0.15)
		names.append(_player.avatar.name)
		await _shot("9%d_%s" % [i, _player.avatar.name])
	if names.size() != 6 or Array(names).has(""):
		_fail("no cambian los personajes: %s" % names)
	print("personajes: %s" % ", ".join(names))


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FALLO: ", message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE 3D OK")
	else:
		print("SMOKE 3D FAILED (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(shot_name + ".png"))
