class_name WorldMapView
extends Control
## Mapa de prueba del mundo generado (tecla M): biomas, montañas, caminos, sitios y dónde está cada jugador.
## Es una herramienta para probar la generación, no la interfaz final.

## Lado del mapa en pantalla (px).
@export var map_size := 600.0
@export var site_colors := {
	"base": Color.WHITE, "camp": Color(0.5, 0.82, 1.0), "boss": Color(1.0, 0.3, 0.3), "dungeon": Color(1.0, 0.7, 0.28),
	"mine": Color(0.79, 0.76, 0.69), "cave": Color(0.71, 0.55, 1.0), "event": Color(1.0, 0.88, 0.4),
	"well": Color(1.0, 0.48, 0.1), "guardian": Color(1.0, 0.96, 0.69),
}

var land: WorldStreamer
var _texture: ImageTexture


func _ready() -> void:
	visible = false
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map") and land and land.map:
		visible = not visible
		set_process(visible)
		if visible and _texture == null:
			_texture = ImageTexture.create_from_image(_render())
		queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw() # los jugadores se mueven


func _render() -> Image:
	var map := land.map
	var image := Image.create(map.n, map.n, false, Image.FORMAT_RGB8)
	var rock := Color(0.33, 0.3, 0.27)
	for y in map.n:
		for x in map.n:
			var i := y * map.n + x
			var c := land.settings.biomes[map.biome[i]].ground_color
			if map.wall[i]:
				c = rock if map.wall[i] == WorldMap.Wall.BARRIER else rock.lightened(0.25)
			elif map.road[i]:
				c = c.lerp(Color(0.95, 0.9, 0.75), 0.7)
			image.set_pixel(x, y, c)
	return image


func _draw() -> void:
	if _texture == null:
		return
	var map := land.map
	var origin := (size - Vector2(map_size, map_size)) * 0.5
	draw_rect(Rect2(origin - Vector2(6, 6), Vector2(map_size + 12, map_size + 12)), Color(0.07, 0.08, 0.07, 0.92))
	draw_texture_rect(_texture, Rect2(origin, Vector2(map_size, map_size)), false)
	var k := map_size / map.n
	for site: Dictionary in map.pois:
		var cell: Vector2i = site.cell
		var p := origin + (Vector2(cell) + Vector2(0.5, 0.5)) * k
		var color: Color = site_colors.get(site.kind, Color.WHITE)
		var r := 2.5 if site.kind == "event" else 4.5
		draw_circle(p, r + 1.5, Color.BLACK)
		draw_circle(p, r, color)
	for node in get_tree().get_nodes_in_group(&"players"):
		var pos := (node as Node3D).global_position
		var cell := Vector2(pos.x / map.cell_m + map.start.x + 0.5, pos.z / map.cell_m + map.start.y + 0.5)
		var p := origin + cell * k
		draw_circle(p, 6.0, Color.BLACK)
		draw_circle(p, 4.5, Color(0.3, 1.0, 0.4))
	draw_string(get_theme_default_font(), origin + Vector2(0, -14), "Mapa de prueba (M): blanco = base, rojo = boss, naranja = dungeon, azul = campamento, verde = tú", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
