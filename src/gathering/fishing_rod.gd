class_name FishingRod
extends GatherTool
## Caña de pescar: lanzar -> esperar -> ¡pica! (pulsa E a tiempo) -> recoger.
## Si tiras antes de tiempo o tarde, el pez se escapa y vuelves a lanzar.
## Animaciones: "cast" (llama a release_line()), "wait" (bucle), "bite" (bucle), "reel" (llama a finish_reel()).

enum State { CASTING, WAITING, BITE, REELING }

@export var min_wait := 1.2
@export var max_wait := 3.2
## Segundos que tienes para tirar cuando pica.
@export var bite_window := 0.8
## Fracción del camino desde el centro del agua hacia el jugador donde cae la boya.
@export var bobber_reach := 0.45

var state := State.CASTING
var _timer := 0.0
var _success := false
var _bobber_rest := Vector2.ZERO
var _bob_time := 0.0

@onready var bobber: Sprite2D = $Bobber
@onready var line: Line2D = $Line
@onready var tip: Marker2D = $Rig/Tip


func _ready() -> void:
	super()
	bobber.top_level = true
	line.top_level = true
	bobber.visible = false
	line.visible = false


func _begin() -> void:
	_cast()


func interact_pressed() -> bool:
	match state:
		State.BITE:
			_reel(true)
		State.WAITING:
			_reel(false) # demasiado pronto
	return true


func _cast() -> void:
	state = State.CASTING
	bobber.visible = false
	line.visible = false
	animation_player.play(&"cast")


## Pista de método de "cast": suelta la boya hacia el agua.
func release_line() -> void:
	var center := target.get_gather_point()
	_bobber_rest = center + (player.global_position - center) * bobber_reach
	bobber.global_position = tip.global_position
	bobber.visible = true
	line.visible = true
	var tween := create_tween()
	tween.tween_property(bobber, "global_position", _bobber_rest, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_waiting)


func _start_waiting() -> void:
	state = State.WAITING
	_timer = randf_range(min_wait, max_wait)
	animation_player.play(&"wait")


func _bite() -> void:
	state = State.BITE
	_timer = bite_window
	animation_player.play(&"bite")
	player.set_prompt("¡Tira!", true)


func _reel(success: bool) -> void:
	state = State.REELING
	_success = success
	player.set_prompt("")
	animation_player.play(&"reel")


## Pista de método de "reel": fin de la recogida.
func finish_reel() -> void:
	if _success:
		target.give(player)
	else:
		target.show_text("Se escapó...")
	_cast()


func _process(delta: float) -> void:
	super(delta)
	match state:
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_bite()
		State.BITE:
			_timer -= delta
			if _timer <= 0.0:
				_reel(false)
	if bobber.visible and state != State.CASTING:
		_bob_time += delta
		var dip := 3.0 if state == State.BITE and fmod(_bob_time, 0.2) < 0.1 else 0.0
		if state == State.REELING:
			bobber.global_position = bobber.global_position.move_toward(tip.global_position, 260.0 * delta)
		else:
			bobber.global_position = _bobber_rest + Vector2(0, roundf(sin(_bob_time * 4.0)) + dip)
	if line.visible:
		line.points = PackedVector2Array([tip.global_position, bobber.global_position])
