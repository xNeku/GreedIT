class_name HandUtils
extends RefCounted
## Utilidades para las manos flotantes.


## Mantiene una mano siempre derecha (sin rotar con el arma) y espejada según hacia dónde mira el personaje.
## Respeta la posición y la escala que le ponga la animación.
static func keep_upright(hand: Node2D, facing: float) -> void:
	var s := hand.scale.abs()
	hand.global_transform = Transform2D(0.0, Vector2(s.x * signf(facing), s.y), 0.0, hand.global_position)


## Busca HandMain / HandOff dentro de `root` y les pone la textura y el tono de piel del aspecto.
static func apply_appearance(root: Node, appearance: CharacterAppearance) -> void:
	if appearance == null:
		return
	var hand_main := root.find_child("HandMain", true, false) as Sprite2D
	var hand_off := root.find_child("HandOff", true, false) as Sprite2D
	if hand_main and appearance.hand_r:
		hand_main.texture = appearance.hand_r
		hand_main.self_modulate = appearance.skin_tint
	if hand_off and appearance.hand_l:
		hand_off.texture = appearance.hand_l
		hand_off.self_modulate = appearance.skin_tint


static func find_hands(root: Node) -> Array[Node2D]:
	var hands: Array[Node2D] = []
	for hand_name in ["HandMain", "HandOff"]:
		var hand := root.find_child(hand_name, true, false) as Node2D
		if hand:
			hands.append(hand)
	return hands
