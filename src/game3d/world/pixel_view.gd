class_name PixelView
extends SubViewportContainer
## Vista "pixel art" del mundo 3D: el mundo (SubViewport "World") se renderiza a baja resolución y se amplía
## sin suavizado, con el filtro `pixel_post.gdshader` encima.
##
## Para que la imagen no tiemble al mover la cámara, FollowCamera3D se pega a la rejilla de píxeles y nos dice
## cuánto se ha desviado (`snap_offset`): aquí movemos la imagen ese trocito, así el scroll sigue siendo suave.
## El HUD va fuera, a resolución normal.

## Tamaño de cada píxel del mundo en unidades de la interfaz (960x540). 2 = mundo a 480x270 (en 1080p, 4x4 píxeles
## de pantalla). Se redondea para que cada píxel del mundo ocupe un número entero de píxeles de pantalla.
@export_range(1, 6) var pixel_scale := 2
@export var camera: FollowCamera3D

@onready var world: SubViewport = $World


func _process(_delta: float) -> void:
	# Píxeles de pantalla por píxel del mundo: siempre un entero (si no, unos píxeles salen más gordos que otros).
	var stretch := get_viewport().get_final_transform().get_scale().x
	var screen_px := maxi(1, roundi(pixel_scale * stretch))
	var canvas_px := screen_px / stretch
	var screen := get_viewport_rect().size
	# +2 píxeles de margen para el desplazamiento suave
	var low := Vector2i(ceili(screen.x / canvas_px) + 2, ceili(screen.y / canvas_px) + 2)
	if world.size != low:
		world.size = low
	size = Vector2(low)
	scale = Vector2(canvas_px, canvas_px)
	var offset := camera.snap_offset if camera else Vector2.ZERO
	position = ((Vector2(-1, -1) + offset) * screen_px).round() / stretch
