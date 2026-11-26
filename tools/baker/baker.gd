extends Node
## Prototipo: renderiza el personaje 3D (vóxeles hechos a partir de los sprites) a sprites 2D.
## godot --path . res://tools/baker/baker.tscn -- --out=/carpeta --anims=idle,run,attack

const PARTS := {
	"cloth": Vector3(0, 24, 0), "torso": Vector3(0, 30, 0), "head": Vector3(0, 44, 0), "hair": Vector3(0, 44, 0),
	"leg_l": Vector3(-5, 22, 0), "leg_r": Vector3(5, 22, 0), "hand_l": Vector3(-21, 28, 2), "hand_r": Vector3(21, 28, 2),
}
const HIERARCHY := {"torso": "hips", "cloth": "hips", "head": "torso", "hair": "head", "leg_l": "hips", "leg_r": "hips", "hand_l": "root", "hand_r": "root"}

var out_dir := "/tmp/bake"
var with_armor := true
var anims := ["idle"]
var gender := "male"
var nodes := {}
var material: StandardMaterial3D

@onready var viewport: SubViewport = $VP
@onready var root3d: Node3D = $VP/Model


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--anims="): anims = arg.trim_prefix("--anims=").split(",")
		if arg == "--no-armor": with_armor = false
	DirAccess.make_dir_recursive_absolute(out_dir)
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	_build()
	await _bake()
	get_tree().quit()


func _build() -> void:
	var hips := Node3D.new(); hips.name = "hips"; hips.position = Vector3(0, 24, 0); root3d.add_child(hips)
	nodes["hips"] = hips
	nodes["root"] = root3d
	for part in ["torso", "cloth", "head", "hair", "leg_l", "leg_r", "hand_l", "hand_r"]:
		var pivot := Node3D.new(); pivot.name = part
		var parent: Node3D = nodes[HIERARCHY[part]]
		var parent_world: Vector3 = parent.global_position if parent != root3d else Vector3.ZERO
		parent.add_child(pivot)
		pivot.position = PARTS[part] - _world_pos(parent)
		var scene := load("res://tools/baker/model/%s/%s.gltf" % [gender, part]) as PackedScene
		var inst := scene.instantiate()
		pivot.add_child(inst)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = material
		nodes[part] = pivot
	# Armadura: va colgada del MISMO pivote que el torso -> encaja sola en cualquier pose y dirección.
	if with_armor:
		_attach("armor_chest", nodes["torso"], Vector3.ZERO)
	# Espada en la mano derecha (empuñadura en el origen).
	var sword_pivot := Node3D.new(); sword_pivot.name = "sword"
	nodes["hand_r"].add_child(sword_pivot)
	_attach("sword", sword_pivot, Vector3.ZERO)
	nodes["sword"] = sword_pivot


func _attach(part: String, parent: Node3D, offset: Vector3) -> void:
	var inst := (load("res://tools/baker/model/%s/%s.gltf" % [gender, part]) as PackedScene).instantiate()
	parent.add_child(inst)
	inst.position = offset
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = material


func _world_pos(n: Node3D) -> Vector3:
	if n == root3d: return Vector3.ZERO
	var p := n.position
	var parent := n.get_parent()
	while parent is Node3D and parent != root3d:
		p += (parent as Node3D).position
		parent = parent.get_parent()
	return p


func _rest() -> void:
	for part in nodes:
		if part == "root":
			continue
		var n: Node3D = nodes[part]
		n.rotation = Vector3.ZERO
	nodes["hips"].position = Vector3(0, 24, 0)
	for part in ["torso", "cloth", "head", "hair", "leg_l", "leg_r", "hand_l", "hand_r"]:
		nodes[part].position = PARTS[part] - _world_pos(nodes[HIERARCHY[part]])


## Pose en el instante t (0..1) de cada animación.
func _pose(anim: String, t: float) -> void:
	_rest()
	var s := sin(t * TAU)
	var c := cos(t * TAU)
	nodes["sword"].visible = anim == "attack"
	match anim:
		"idle":
			nodes["torso"].position.y += 0.6 * (1.0 - c) * 0.5
			nodes["hand_l"].position.y += -c * 0.8
			nodes["hand_r"].position.y += -c * 0.8
		"run":
			nodes["hips"].position.y += 2.0 * absf(s)
			nodes["hips"].rotation.x = deg_to_rad(8) # inclinado hacia delante
			nodes["leg_l"].rotation.x = deg_to_rad(40) * s
			nodes["leg_r"].rotation.x = -deg_to_rad(40) * s
			nodes["hand_l"].position += Vector3(0, 2.0 * absf(s), -9.0 * s)
			nodes["hand_r"].position += Vector3(0, 2.0 * absf(s), 9.0 * s)
			nodes["torso"].rotation.y = deg_to_rad(8) * s
		"attack":
			# tajo de arriba abajo: mano derecha de arriba-atrás a abajo-delante, la espada gira con ella, el torso acompaña
			var k := clampf(t * 1.5, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			nodes["torso"].rotation.y = deg_to_rad(lerpf(-30.0, 30.0, e))
			nodes["hips"].rotation.x = deg_to_rad(lerpf(-4.0, 10.0, e))
			nodes["hand_r"].position = PARTS["hand_r"] + Vector3(lerpf(-8, -2, e), lerpf(22, 2, e), lerpf(-6, 18, e))
			nodes["sword"].rotation.x = deg_to_rad(lerpf(-40.0, 115.0, e))
			nodes["hand_l"].position = PARTS["hand_l"] + Vector3(lerpf(6, -2, e), lerpf(2, -2, e), lerpf(8, -6, e))
			nodes["leg_l"].rotation.x = deg_to_rad(lerpf(-12, 18, e))
			nodes["leg_r"].rotation.x = deg_to_rad(lerpf(12, -12, e))


func _bake() -> void:
	var frames := {"idle": 4, "run": 8, "attack": 6}
	for anim in anims:
		for dir in 8:
			root3d.rotation.y = deg_to_rad(dir * 45.0)
			for f in frames.get(anim, 4):
				_pose(anim, float(f) / frames.get(anim, 4))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png("%s/%s_d%d_f%d.png" % [out_dir, anim, dir, f])
