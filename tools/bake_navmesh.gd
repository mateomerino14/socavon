extends SceneTree
## Hornea la malla de navegación de un nivel y la guarda en su archivo.
##
## Uso: godot --headless --path . -s tools/bake_navmesh.gd -- res://src/world/level_02/level_02.tscn

const REGION_PATH := "NavigationRegion3D"
const SETTLE_FRAMES := 3


## Carga el nivel pedido, hornea su región y guarda el resultado.
func _initialize() -> void:
	_bake.call_deferred(OS.get_cmdline_user_args()[0])


## Espera a que el nivel esté en el árbol para que las piezas CSG tengan geometría.
func _bake(scene_path: String) -> void:
	var level: Node = load(scene_path).instantiate()
	root.add_child(level)
	for frame in SETTLE_FRAMES:
		await process_frame
	var region: NavigationRegion3D = level.get_node(REGION_PATH)
	region.bake_navigation_mesh(false)
	var mesh := region.navigation_mesh
	ResourceSaver.save(mesh, mesh.resource_path)
	print("Malla horneada: %d polígonos en %s" % [mesh.get_polygon_count(), mesh.resource_path])
	quit()
