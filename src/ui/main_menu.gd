extends Control
## Menú principal: jugar solo, crear partida (host) o unirse por IP.

@onready var world: OptionButton = %World
@onready var character: OptionButton = %Character
@onready var character_3d: OptionButton = %Character3D
@onready var port_edit: LineEdit = %Port
@onready var address_edit: LineEdit = %Address
@onready var status: Label = %Status


func _ready() -> void:
	status.text = Net.last_error
	world.selected = 0 if Net.world_scene == Net.WORLD_3D_SCENE else 1
	world.item_selected.connect(func(_i: int) -> void: _update_world())
	_update_world()
	var picker := character_3d if world.selected == 0 else character
	picker.selected = clampi(Net.appearance_index, 0, picker.item_count - 1)
	address_edit.text = Net.address
	port_edit.text = str(Net.port)
	%Solo.pressed.connect(func() -> void: _play(Net.Mode.SOLO))
	%Host.pressed.connect(func() -> void: _play(Net.Mode.HOST))
	%Join.pressed.connect(func() -> void: _play(Net.Mode.JOIN))
	%ProtoA.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://prototypes/proto_a/proto_a.tscn"))
	%ProtoB.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://prototypes/proto_b/proto_b.tscn"))
	%Solo.grab_focus()


func _play(mode: Net.Mode) -> void:
	var port := port_edit.text.to_int()
	if port <= 0 or port > 65535:
		status.text = "Puerto no válido"
		return
	if mode == Net.Mode.JOIN and address_edit.text.strip_edges().is_empty():
		status.text = "Escribe la IP del host"
		return
	var is_3d := world.selected == 0
	Net.world_scene = Net.WORLD_3D_SCENE if is_3d else Net.WORLD_2D_SCENE
	Net.appearance_index = character_3d.selected if is_3d else character.selected
	status.text = "Conectando..." if mode == Net.Mode.JOIN else ""
	Net.play(mode, address_edit.text.strip_edges(), port)


## Cada mundo tiene sus personajes: 3D (KayKit de muestra) o 2D (pixel art).
func _update_world() -> void:
	character_3d.visible = world.selected == 0
	character.visible = world.selected == 1
