extends Node
## Renderiza el personaje 3D (prototypes/model3d/character_3d.tscn) a fotogramas 2D en 8 direcciones.
## godot --path . res://tools/baker/baker.tscn -- --out=/carpeta --anims=idle,run,attack
## Después: python3 tools/baker/post.py <raw> <px> (paleta + contorno) y make_sheets.py (hojas de sprites).

const FRAMES := {"idle": 4, "run": 8, "attack": 6}

var out_dir := "/tmp/bake"
var anims: PackedStringArray = ["idle", "run", "attack"]
var with_armor := true

@onready var viewport: SubViewport = $VP
@onready var rig: CharacterRig3D = $VP/Character3D
@onready var camera: Camera3D = $VP/Cam


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--anims="): anims = arg.trim_prefix("--anims=").split(",")
		if arg == "--no-armor": with_armor = false
	DirAccess.make_dir_recursive_absolute(out_dir)
	rig.show_armor = with_armor
	await RenderingServer.frame_post_draw
	# Dónde caen los pies (origen del modelo) en la celda: lo necesita el juego para alinear el sprite.
	var feet := camera.unproject_position(Vector3.ZERO)
	var meta := FileAccess.open(out_dir.path_join("meta.json"), FileAccess.WRITE)
	meta.store_string(JSON.stringify({"cell": viewport.size.x, "feet": [feet.x, feet.y], "frames": FRAMES}))
	meta.close()
	for anim in anims:
		var count: int = FRAMES.get(anim, 4)
		for dir in 8:
			rig.rotation.y = deg_to_rad(dir * 45.0)
			for f in count:
				rig.pose(StringName(anim), float(f) / count)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png("%s/%s_d%d_f%d.png" % [out_dir, anim, dir, f])
	get_tree().quit()
