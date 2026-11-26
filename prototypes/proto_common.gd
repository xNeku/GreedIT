extends Node
## PROTOTIPOS: Esc vuelve al menú.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave_game"):
		get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
