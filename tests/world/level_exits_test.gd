extends TestCase
## Pruebas de las salidas: cada una sigue por un túnel abierto, para que el jugador vea por dónde
## continuar y llegue al tránsito sin toparse con una pared.

const LEVELS_WITH_EXIT: Array[int] = [1, 2, 3, 4]
const LEVEL_PATH := "res://src/world/level_%02d/level_%02d.tscn"
const SETTLE_FRAMES := 5
## El rayo sale a la altura de los ojos desde unos metros antes del túnel de salida.
const EYE := Vector3(0.0, 1.5, 0.0)
const APPROACH := Vector3(0.0, 0.0, 10.0)
## Y llega unos metros más allá del disparador del tránsito.
const BEYOND := Vector3(0.0, 0.0, -4.0)
const WORLD_MASK := 1


## Desde el último tramo del nivel se ve el túnel seguir hasta pasar el disparador.
func test_exits_lead_into_open_tunnels() -> void:
	for number in LEVELS_WITH_EXIT:
		var level: Node3D = load(LEVEL_PATH % [number, number]).instantiate()
		add_to_tree(level)
		await wait_physics_frames(SETTLE_FRAMES)
		var exit: Node3D = level.get_node("LevelExit")
		var from := exit.global_position + EYE + APPROACH
		var to := exit.global_position + EYE + BEYOND
		var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
		var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
		assert_true(hit.is_empty(), "La salida del nivel %d no debe estar tapiada" % number)
		level.free()
