extends TestCase
## Pruebas de los brazos en primera persona: quietos esperan abajo y lanzan al tirar una piedra;
## nunca se ven en otra capa que la suya.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const BODY_LAYER := 2048

var _tunnel: Node3D
var _body: FirstPersonBody
var _animation: AnimationPlayer


## Carga el túnel con el jugador.
func before_each() -> void:
	_tunnel = add_to_tree(TUNNEL_SCENE.instantiate())
	_body = _tunnel.get_node("Player").find_child("FirstPersonBody", true, false)
	_animation = _body.find_child("AnimationPlayer", true, false)


## Libera el túnel.
func after_each() -> void:
	_tunnel.free()


## Empiezan quietos y en su propia capa.
func test_starts_idle_on_own_layer() -> void:
	assert_true(_animation.current_animation == FirstPersonBody.IDLE, "Empiezan quietos")
	for mesh: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		assert_true(mesh.layers == BODY_LAYER, "Solo en la capa del cuerpo propio")


## Al lanzar tiran la piedra y al terminar vuelven a quedar quietos.
func test_gestures_follow_hands() -> void:
	_body.stone_thrower.thrown.emit()
	assert_true(_animation.current_animation == FirstPersonBody.THROW, "Lanzan la piedra")
	_animation.animation_finished.emit(FirstPersonBody.THROW)
	assert_true(_animation.current_animation == FirstPersonBody.IDLE, "Vuelven a bajar")
