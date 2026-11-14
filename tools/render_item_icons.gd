extends SceneTree
## Dibuja el ícono de cada objeto para el inventario, con luz de lámpara y fondo transparente.
##
## Uso (necesita pantalla, no funciona con --headless):
## godot --path . --script res://tools/render_item_icons.gd

const VISUALS_DIR := "res://src/items/visuals/%s.tscn"
const OUTPUT_DIR := "res://assets/ui/items/%s.png"
const ITEMS: Array[String] = ["carbide", "coca", "alcohol", "cigarette", "stone"]
const ICON_SIZE := 256
const SETTLE_FRAMES := 6
## Margen alrededor del objeto, en proporción a su tamaño.
const FRAME_MARGIN := 1.18
const CAMERA_PITCH := -0.42
const CAMERA_YAW := 0.6
const KEY_COLOR := Color(1.0, 0.78, 0.5)
const KEY_ENERGY := 2.0
const RIM_COLOR := Color(0.55, 0.62, 0.8)
const RIM_ENERGY := 1.2
const AMBIENT_ENERGY := 0.12
## La luz principal baja desde arriba y un costado; el contraluz, desde atrás.
const KEY_LIGHT_ROTATION := Vector3(-0.9, 0.5, 0.0)
const RIM_LIGHT_ROTATION := Vector3(-0.3, PI + 0.4, 0.0)


## Dibuja los íconos uno tras otro y cierra.
func _initialize() -> void:
	_render_all.call_deferred()


## Arma un estudio pequeño por objeto y guarda lo que ve la cámara.
func _render_all() -> void:
	for item in ITEMS:
		var viewport := _studio()
		var model: Node3D = load(VISUALS_DIR % item).instantiate()
		viewport.add_child(model)
		_frame(viewport.get_node("Camera3D"), model)
		for i in SETTLE_FRAMES:
			await process_frame
		viewport.get_texture().get_image().save_png(OUTPUT_DIR % item)
		print("ícono ", item)
		viewport.queue_free()
	quit()


## Ventana fuera de pantalla con fondo transparente, cámara, luz cálida y un contraluz frío.
func _studio() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = KEY_COLOR
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.light_color = KEY_COLOR
	key.light_energy = KEY_ENERGY
	key.rotation = KEY_LIGHT_ROTATION
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = RIM_COLOR
	rim.light_energy = RIM_ENERGY
	rim.rotation = RIM_LIGHT_ROTATION
	viewport.add_child(rim)
	return viewport


## Apunta la cámara al centro del objeto, a una distancia en que entra entero.
func _frame(camera: Camera3D, model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	var radius := bounds.size.length() * 0.5 * FRAME_MARGIN
	var distance := radius / tan(deg_to_rad(camera.fov * 0.5))
	var direction := Basis.from_euler(Vector3(CAMERA_PITCH, CAMERA_YAW, 0.0)) * Vector3.BACK
	camera.global_position = bounds.get_center() + direction * distance
	camera.look_at(bounds.get_center())
