class_name TestCase
extends RefCounted
## Base de las pruebas: cada método test_ es una prueba y sus aserciones acumulan fallos.

const DEFAULT_TOLERANCE := 0.001

var failures := PackedStringArray()
var tree: SceneTree


## Se ejecuta antes de cada prueba; las pruebas lo sobrescriben si lo necesitan.
func before_each() -> void:
	pass


## Se ejecuta después de cada prueba; las pruebas lo sobrescriben si lo necesitan.
func after_each() -> void:
	pass


## Falla si la condición no se cumple.
func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## Falla si la condición se cumple.
func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


## Falla si los dos números difieren más que la tolerancia.
func assert_almost_eq(
	actual: float, expected: float, message: String, tolerance := DEFAULT_TOLERANCE
) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (esperado %.3f, obtenido %.3f)" % [message, expected, actual])


## Agrega un nodo a la escena de pruebas y lo devuelve ya listo.
func add_to_tree(node: Node) -> Node:
	tree.root.add_child(node)
	return node


## Espera la cantidad de frames de física indicada.
func wait_physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
