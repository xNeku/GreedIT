class_name WorldStreamer
extends Node3D
## El mundo generado, cargado por trozos alrededor de los jugadores:
##   - terreno con relieve suave, montañas con laderas que no se pueden subir y el color de cada bioma
##   - su colisión (HeightMapShape3D) y la de lo que no deja pasar (troncos, rocas)
##   - la decoración de cada bioma (árboles, rocas, hierba...) en MultiMesh: pocas llamadas de dibujo
## El mapa grande (WorldMap) sale de la semilla, así que todos los peers ven lo mismo sin mandarlo por red. Se guarda
## en disco (user://worlds) para no recalcularlo cada vez.
## Los trozos se montan en tiempo de juego (como StaticBatcher): las reglas y la decoración se editan en los
## recursos (WorldSettings, BiomeData, DecorationData), no aquí.

signal map_ready(map: WorldMap)

@export var settings: WorldSettings
@export var world_seed := 1234
## Material del terreno (world_lit con colores por vértice).
@export var terrain_material: Material
## Lado de cada trozo (m).
@export var chunk_size := 32.0
## Separación entre vértices del terreno (m): más grande = más facetado y más ligero.
@export var vertex_spacing := 2.0
## Trozos alrededor de cada jugador que se mantienen cargados.
@export var view_radius := 3
## Trozos que se construyen como mucho por frame (para que no dé tirones al andar).
@export var chunks_per_frame := 1
## Guardar el mapa grande en disco para no recalcularlo.
@export var cache_to_disk := true

var map: WorldMap

var _chunks := {} # Vector2i -> Node3D
var _detail: FastNoiseLite
var _patches: FastNoiseLite
var _ridge: FastNoiseLite
var _warp: FastNoiseLite
var _clumps: FastNoiseLite
var _meshes := {} # PackedScene -> Array[[Mesh, Transform3D]]
var _shapes := {} # radio -> CylinderShape3D


## Genera (o carga) el mapa y monta los trozos alrededor del inicio. Llamar antes de crear a los jugadores.
func prepare() -> void:
	map = _load_or_generate()
	_detail = _make_noise(world_seed + 101, 0.035, 3)
	_patches = _make_noise(world_seed + 102, 0.06, 2)
	_ridge = _make_noise(world_seed + 103, 0.05, 3)
	_warp = _make_noise(world_seed + 104, 0.02, 2)
	_clumps = _make_noise(world_seed + 105, 0.045, 2)
	for cell in _wanted([Vector3.ZERO], 2):
		_build_chunk(cell)
	map_ready.emit(map)


func _make_noise(seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise


func _load_or_generate() -> WorldMap:
	var path := "user://worlds/%s_%d_%d.res" % [settings.display_name.to_snake_case(), world_seed, _settings_hash()]
	if cache_to_disk and ResourceLoader.exists(path):
		var cached := load(path) as WorldMap
		if cached:
			return cached
	var generated := WorldGenerator.generate(settings, world_seed)
	if cache_to_disk:
		DirAccess.make_dir_recursive_absolute("user://worlds")
		ResourceSaver.save(generated, path)
	return generated


## Si cambian las reglas del mundo, el mapa guardado ya no vale.
func _settings_hash() -> int:
	var parts: Array = [settings.size_km, settings.cells, settings.start_in_center, settings.border_warp,
		settings.logical_climate, settings.start_biome, settings.ranges, settings.range_length,
		settings.range_thickness, settings.passes_per_range, settings.dungeons, settings.mines, settings.caves,
		settings.camps, settings.bosses, settings.events, WorldGenerator.VERSION]
	for b in settings.biomes:
		parts.append_array([b.id, b.weight, b.climate, b.rocky])
	return absi(str(parts).hash())


func _process(_delta: float) -> void:
	if map == null:
		return
	var targets: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group(&"players"):
		targets.append((node as Node3D).global_position)
	if targets.is_empty():
		targets.append(Vector3.ZERO)
	var wanted := _wanted(targets, view_radius)
	var built := 0
	for cell in wanted:
		if built >= chunks_per_frame:
			break
		if not _chunks.has(cell):
			_build_chunk(cell)
			built += 1
	# fuera lo que queda lejos (con un trozo de margen para no montar y desmontar en el borde)
	var keep := {}
	for cell in _wanted(targets, view_radius + 1):
		keep[cell] = true
	for cell: Vector2i in _chunks.keys():
		if not keep.has(cell):
			(_chunks[cell] as Node).queue_free()
			_chunks.erase(cell)


## Trozos alrededor de unos puntos, los más cercanos primero.
func _wanted(points: Array[Vector3], radius: int) -> Array[Vector2i]:
	var found := {}
	var out: Array[Vector2i] = []
	var dist := {}
	for p in points:
		var center := Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := center + Vector2i(dx, dz)
				var d := Vector2(dx, dz).length()
				if not found.has(cell) or d < dist[cell]:
					dist[cell] = d
				if not found.has(cell):
					found[cell] = true
					out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist[a] < dist[b])
	return out


# --- Terreno ------------------------------------------------------------------------------------------------

## Altura del suelo en un punto y cuánta montaña hay (0..1). Es la misma función para el dibujo y la colisión.
func sample(x: float, z: float) -> Vector2:
	var wx := x + _warp.get_noise_2d(x, z) * 14.0
	var wz := z + _warp.get_noise_2d(x + 517.0, z - 291.0) * 14.0
	var m := smoothstep(0.38, 0.62, map.mountain_at(wx, wz))
	var ridge := 1.0 - absf(_ridge.get_noise_2d(x, z))
	var h := _detail.get_noise_2d(x, z) * settings.relief + m * settings.mountain_height * (0.55 + 0.7 * ridge)
	var from_base := sqrt(x * x + z * z)
	if from_base < settings.base_radius * 1.8:
		h *= smoothstep(settings.base_radius, settings.base_radius * 1.8, from_base)
	return Vector2(h, m)


func height_at(x: float, z: float) -> float:
	return sample(x, z).x


## Color del suelo: los biomas de alrededor mezclados (bordes suaves), sus manchas y la roca de las montañas.
func ground_color(x: float, z: float, mountain: float) -> Color:
	var biomes := settings.biomes
	var c1 := Color(0, 0, 0)
	var c2 := Color(0, 0, 0)
	for corner in map.corners(x + _warp.get_noise_2d(x - 77.0, z) * 10.0, z + _warp.get_noise_2d(x, z + 93.0) * 10.0):
		var b := biomes[map.biome[corner[0]]]
		c1 += b.ground_color * corner[1]
		c2 += b.ground_color_2 * corner[1]
	var patch := clampf(_patches.get_noise_2d(x, z) * 1.4 + 0.5, 0.0, 1.0)
	var ground := c1.lerp(c2, patch)
	var rock := settings.rock_color.lerp(settings.rock_color_2, clampf(_ridge.get_noise_2d(x * 2.0, z * 2.0) + 0.5, 0.0, 1.0))
	return ground.lerp(rock, smoothstep(0.15, 0.5, mountain))


func _build_chunk(cell: Vector2i) -> void:
	var origin := Vector3(cell.x * chunk_size, 0.0, cell.y * chunk_size)
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [cell.x, cell.y]
	chunk.position = origin
	add_child(chunk)
	_chunks[cell] = chunk
	# alturas cada metro (colisión) y cada `vertex_spacing` (dibujo)
	var size := int(chunk_size)
	var heights := PackedFloat32Array()
	heights.resize((size + 1) * (size + 1))
	var mountains := PackedFloat32Array()
	mountains.resize((size + 1) * (size + 1))
	for z in size + 1:
		for x in size + 1:
			var s := sample(origin.x + x, origin.z + z)
			heights[z * (size + 1) + x] = s.x
			mountains[z * (size + 1) + x] = s.y
	_build_terrain_mesh(chunk, origin, heights, mountains, size)
	var body := StaticBody3D.new()
	body.name = "Collision"
	chunk.add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = size + 1
	shape.map_depth = size + 1
	shape.map_data = heights
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(size * 0.5, 0.0, size * 0.5)
	body.add_child(collider)
	_scatter(chunk, cell, origin, body)


func _build_terrain_mesh(chunk: Node3D, origin: Vector3, heights: PackedFloat32Array, mountains: PackedFloat32Array,
		size: int) -> void:
	var step := maxi(1, int(vertex_spacing))
	var row := size + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(0, size, step):
		for x in range(0, size, step):
			var p00 := Vector3(x, heights[z * row + x], z)
			var p10 := Vector3(x + step, heights[z * row + x + step], z)
			var p01 := Vector3(x, heights[(z + step) * row + x], z + step)
			var p11 := Vector3(x + step, heights[(z + step) * row + x + step], z + step)
			var m := (mountains[z * row + x] + mountains[(z + step) * row + x + step]) * 0.5
			# dos triángulos con su color (facetado, como el resto del pack low poly)
			for tri in [[p00, p11, p10], [p00, p01, p11]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var center := (a + b + c) / 3.0
				var normal := (b - a).cross(c - a).normalized()
				# las laderas empinadas, de roca
				var steep := 1.0 - normal.y
				var color := ground_color(origin.x + center.x, origin.z + center.z, maxf(m, steep * 2.2))
				# orden de los vértices: el que Godot considera cara de delante vista desde arriba
				for v in [a, c, b]:
					st.set_color(color)
					st.set_normal(normal)
					st.add_vertex(v)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(mesh_instance)


# --- Decoración ---------------------------------------------------------------------------------------------

func _scatter(chunk: Node3D, cell: Vector2i, origin: Vector3, body: StaticBody3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, cell.x, cell.y])
	var area := chunk_size * chunk_size / 100.0
	var transforms := {} # Mesh -> Array[Transform3D]; shadows por malla
	var shadows := {}
	var present := {}
	for corner in map.corners(origin.x + chunk_size * 0.5, origin.z + chunk_size * 0.5):
		present[map.biome[corner[0]]] = true
	var jobs: Array = []
	for b in present:
		for deco in settings.biomes[b].decorations:
			jobs.append([deco, b])
	for deco in settings.mountain_decorations:
		jobs.append([deco, -1])
	for job in jobs:
		var deco: DecorationData = job[0]
		var biome_index: int = job[1]
		if deco.scene == null:
			continue
		var count := int(deco.per_100m2 * area + rng.randf())
		for k in count:
			var x := origin.x + rng.randf() * chunk_size
			var z := origin.z + rng.randf() * chunk_size
			var s := sample(x, z)
			if deco.on_mountains:
				if s.y < 0.5:
					continue
			else:
				if s.y > 0.08:
					continue
				# bioma del punto (con algo de temblor para que el borde entre biomas no sea recto)
				var here := map.biome[map.index(map.cell_at(x + rng.randf_range(-12.0, 12.0), z + rng.randf_range(-12.0, 12.0)))]
				if here != biome_index:
					continue
			if x * x + z * z < settings.base_radius * settings.base_radius:
				continue
			if deco.clumping > 0.0 and _clumps.get_noise_2d(x, z) * 0.5 + 0.5 < deco.clumping * 0.6 + rng.randf() * 0.25:
				continue
			var scale := rng.randf_range(deco.scale_min, deco.scale_max)
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			if deco.tilt_degrees > 0.0:
				basis = Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), deg_to_rad(rng.randf() * deco.tilt_degrees)) * basis
			var xf := Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(x, s.x - 0.05, z) - origin)
			for part in _meshes_of(deco.scene):
				var mesh: Mesh = part[0]
				if not transforms.has(mesh):
					transforms[mesh] = []
				(transforms[mesh] as Array).append(xf * (part[1] as Transform3D))
				shadows[mesh] = deco.cast_shadow
			if deco.block_radius > 0.0:
				var collider := CollisionShape3D.new()
				collider.shape = _cylinder(snappedf(deco.block_radius * scale, 0.1))
				collider.position = xf.origin + Vector3(0, 1.0, 0)
				body.add_child(collider)
	for mesh: Mesh in transforms:
		var list: Array = transforms[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows[mesh] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(mmi)


## Las mallas de un modelo con su colocación dentro de él (se calcula una vez por modelo).
func _meshes_of(scene: PackedScene) -> Array:
	if _meshes.has(scene):
		return _meshes[scene]
	var parts: Array = []
	var root := scene.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := mi.transform
		var parent := mi.get_parent()
		while parent and parent != root:
			if parent is Node3D:
				xf = (parent as Node3D).transform * xf
			parent = parent.get_parent()
		parts.append([mi.mesh, xf])
	root.free()
	_meshes[scene] = parts
	return parts


func _cylinder(radius: float) -> CylinderShape3D:
	if not _shapes.has(radius):
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = 2.0
		_shapes[radius] = shape
	return _shapes[radius]
