class_name StoneThrower
extends Marker3D
## Punto desde donde el jugador lanza piedras hacia donde mira.

## Salió una piedra de la mano.
signal thrown

const STONE_SCENE := preload("res://src/items/thrown_stone.tscn")

@export var throw_speed := 11.0
@export var upward_boost := 1.5


## Lanza una piedra dentro del contenedor, sumando la velocidad del jugador.
func throw(container: Node, inherited_velocity: Vector3) -> ThrownStone:
	var stone: ThrownStone = STONE_SCENE.instantiate()
	container.add_child(stone)
	stone.global_transform = global_transform
	stone.linear_velocity = (
		-global_basis.z * throw_speed + Vector3.UP * upward_boost + inherited_velocity
	)
	thrown.emit()
	return stone
