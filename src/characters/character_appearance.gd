class_name CharacterAppearance
extends Resource
## Aspecto de un personaje: un juego de capas por cada vista (estilo Diablo / Path of Exile).
## Con el volteo izquierda/derecha, 5 vistas cubren las 8 direcciones.
## Para un pelo / ropa / armadura nueva hay que pintar sus capas en cada vista.

@export_group("Vistas")
## Mirando hacia abajo (hacia la cámara).
@export var front: CharacterLayers
## Diagonal hacia abajo (3/4 de frente).
@export var front_side: CharacterLayers
## De perfil.
@export var side: CharacterLayers
## Diagonal hacia arriba (3/4 de espaldas).
@export var back_side: CharacterLayers
## Mirando hacia arriba (de espaldas).
@export var back: CharacterLayers

@export_group("Manos")
@export var hand_l: Texture2D
@export var hand_r: Texture2D

@export_group("Tonos")
@export var skin_tint := Color.WHITE
@export var hair_tint := Color.WHITE


func layers_for(view: int) -> CharacterLayers:
	var list: Array[CharacterLayers] = [front, front_side, side, back_side, back]
	var layers := list[clampi(view, 0, 4)]
	return layers if layers else front
