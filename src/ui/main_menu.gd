extends Control
## Menú principal: jugar solo, crear partida (host) o unirse por IP.

@onready var character: OptionButton = %Character
@onready var port_edit: LineEdit = %Port
@onready var address_edit: LineEdit = %Address
@onready var status: Label = %Status


func _ready() -> void:
	status.text = Net.last_error
	character.selected = Net.appearance_index
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
	Net.appearance_index = character.selected
	status.text = "Conectando..." if mode == Net.Mode.JOIN else ""
	Net.play(mode, address_edit.text.strip_edges(), port)
