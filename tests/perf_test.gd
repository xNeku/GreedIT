extends Node
## Test de rendimiento: carga el mundo, mete `--entities=N` entidades de prueba (muñecos: script, física, mallas,
## etiqueta) alrededor del jugador y mide durante `--seconds=S` segundos con el jugador moviéndose y atacando.
## Saca: frame medio y peor 1 %, tiempo de scripts (process) y de física, llamadas de dibujo, triángulos y nodos.
##
## Uso:  godot --path . res://tests/perf_test.tscn -- --entities=300 --seconds=10
## (con render; en --headless solo valen los tiempos de scripts y física)

var entities := 0
var no_terrain_collision := false
## Experimentos: apagar partes para ver cuánto cuestan (--off=GroundShape,PropCollision,Straw...)
var off: PackedStringArray = []
var idle := false
var disable_entities := false
## Qué entidad meter: "dummy" (muñeco con script) o una ruta de escena (p. ej. un árbol sin script)
var entity_scene := "res://src/enemies/training_dummy_3d.tscn"
var seconds := 8.0
var _frames: PackedFloat32Array = []
var _process_ms: PackedFloat32Array = []
var _physics_ms: PackedFloat32Array = []
var _draw_calls: PackedFloat32Array = []
var _primitives: PackedFloat32Array = []


func _ready() -> void:
	Engine.max_fps = 0 # sin límite: el tiempo de frame es lo que de verdad cuesta
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--entities="):
			entities = arg.trim_prefix("--entities=").to_int()
		elif arg.begins_with("--off="):
			off = arg.trim_prefix("--off=").split(",")
		elif arg == "--no-interp":
			get_tree().physics_interpolation = false
		elif arg.begins_with("--entity="):
			entity_scene = arg.trim_prefix("--entity=")
		elif arg == "--disable-entities":
			disable_entities = true
		elif arg == "--idle":
			idle = true
		elif arg == "--no-terrain-collision":
			no_terrain_collision = true
		elif arg.begins_with("--seconds="):
			seconds = arg.trim_prefix("--seconds=").to_float()
	_run.call_deferred()


func _run() -> void:
	var game := (load("res://src/world/game_3d.tscn") as PackedScene).instantiate() as Game3D
	add_child(game)
	if no_terrain_collision:
		for shape in game.find_child("Collision", true, false).get_children():
			if String(shape.name).begins_with("Tile_"):
				(shape as CollisionShape3D).disabled = true
	await get_tree().create_timer(1.0).timeout
	var player := game.players.get_node("1") as Player3D
	var dummy_scene := load(entity_scene) as PackedScene
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in entities:
		var d := dummy_scene.instantiate() as Node3D
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, 30.0)
		d.position = Vector3(cos(a) * r, 0.3, sin(a) * r)
		if disable_entities:
			d.process_mode = Node.PROCESS_MODE_DISABLED
		game.dummies.add_child(d, true)
	for name in off:
		for node in game.find_children(name, "", true, false):
			if node is CollisionShape3D:
				(node as CollisionShape3D).disabled = true
			elif node is CollisionObject3D:
				(node as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
				(node as CollisionObject3D).collision_layer = 0
			else:
				node.queue_free()
	await get_tree().create_timer(1.0).timeout
	var t := 0.0
	var step := 0
	var last := Time.get_ticks_usec()
	while t < seconds:
		# el jugador corre en círculo y ataca para que haya animación, golpes y efectos
		player.move_input_override = Vector2.ZERO if idle else Vector2(cos(t * 0.8), sin(t * 0.8))
		if step % 40 == 0 and not idle:
			player.primary_down()
			player.primary_up()
		if step % 200 == 100 and not idle:
			player.cast_spell()
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		step += 1
		var now := Time.get_ticks_usec()
		_frames.append((now - last) / 1000.0) # tiempo real (con --fixed-fps el motor no espera)
		last = now
		_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var sorted := _frames.duplicate()
	sorted.sort()
	var p99 := sorted[int(sorted.size() * 0.99)]
	print("PERF entidades=%d frames=%d | frame medio %.2f ms (%.0f fps) peor1%% %.2f ms | scripts %.2f ms | física %.2f ms | draw calls %.0f | triángulos %.0f | nodos %d" % [
		entities, _frames.size(), _avg(_frames), 1000.0 / _avg(_frames), p99, _avg(_process_ms), _avg(_physics_ms),
		_avg(_draw_calls), _avg(_primitives), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit()


func _avg(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1.0)
