extends Node
## Test de los prototipos de personaje 3D (A: sprites horneados, B: 3D real).
## Mueve al personaje en varias direcciones y ataca a un muñeco. Con --shots=<carpeta> guarda fotogramas.
## godot --path . res://tests/proto_test.tscn -- --shots=/tmp/proto

var _shots := ""
var _failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): _shots = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	await _test("a", "res://prototypes/proto_a/proto_a.tscn")
	await _test("b", "res://prototypes/proto_b/proto_b.tscn")
	print("PROTO OK" if _failures.is_empty() else "PROTO FAILED: %s" % [_failures])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test(tag: String, path: String) -> void:
	var scene := (load(path) as PackedScene).instantiate()
	add_child(scene)
	await _wait(0.3)
	var player: Node = scene.find_child("Player", true, false)
	var frame := 0
	for dirs in [["move_right"], ["move_right", "move_down"], ["move_down"], ["move_left"], ["move_up"], ["move_up", "move_right"]]:
		for a in dirs: Input.action_press(a)
		for i in 6:
			await _wait(0.05)
			await _shot("%s_run_%03d" % [tag, frame]); frame += 1
		for a in dirs: Input.action_release(a)
	await _wait(0.3)
	# atacar al muñeco: ponerse al lado y apuntar con el ratón hacia él
	var dummy: Node = scene.find_child("Dummy1", true, false)
	var before := _dummy_hits(dummy)
	for k in 3:
		if player is Node2D:
			player.global_position = dummy.global_position + Vector2(-34, 6)
			await _wait(0.1)
			var screen: Vector2 = get_viewport().get_screen_transform() * (get_viewport().get_canvas_transform() * (dummy.global_position + Vector2(0, -30)))
			Input.warp_mouse(screen)
		else:
			player.global_position = dummy.global_position + Vector3(-34, 0, 6)
			await _wait(0.1)
			var cam := get_viewport().get_camera_3d()
			Input.warp_mouse(get_viewport().get_screen_transform() * cam.unproject_position(dummy.global_position + Vector3(0, 10, 0)))
		await _wait(0.1)
		var ev := InputEventAction.new(); ev.action = &"attack_primary"; ev.pressed = true
		Input.parse_input_event(ev)
		for i in 6:
			await _wait(0.06)
			await _shot("%s_attack_%03d" % [tag, k * 6 + i])
		var up := InputEventAction.new(); up.action = &"attack_primary"; up.pressed = false
		Input.parse_input_event(up)
		await _wait(0.2)
	var hits := _dummy_hits(dummy) - before
	print("[%s] golpes al muñeco: %d" % [tag, hits])
	if hits <= 0:
		_failures.append("%s: no golpea al muñeco" % tag)
	scene.queue_free()
	await _wait(0.2)


func _dummy_hits(dummy: Node) -> int:
	return dummy._hit_count if dummy is TrainingDummy else int(dummy.get("hits"))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join(name + ".png"))
