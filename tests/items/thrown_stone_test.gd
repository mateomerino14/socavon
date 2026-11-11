extends TestCase
## Pruebas de las piedras: lanzarlas gasta la bolsa, hacen ruido al caer y vuelven a ser recogibles.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const STONE_SCENE := preload("res://src/items/thrown_stone.tscn")
const SETTLE_FRAMES := 10
const FALL_FRAMES := 180
const DROP_POSITION := Vector3(0, 1.5, -8)
const DROP_VELOCITY := Vector3(0, -4, 0)

var _tunnel: Node3D
var _player: Player
var _loudest_noise := 0.0


## Carga el túnel y escucha los ruidos.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_player = _tunnel.get_node("Player")
	EventBus.noise_emitted.connect(_on_noise_emitted)


## Libera el túnel.
func after_each() -> void:
	EventBus.noise_emitted.disconnect(_on_noise_emitted)
	_tunnel.free()


## Lanzar gasta una piedra y la pone en el mundo; sin piedras no lanza.
func test_throw_uses_a_stone() -> void:
	_player.inventory.add(ItemCatalog.Type.STONE)
	_player.throw_stone()
	assert_true(_player.inventory.count(ItemCatalog.Type.STONE) == 0, "Debe gastar la piedra")
	assert_true(_count_thrown_stones() == 1, "Debe haber una piedra en el aire")
	_player.throw_stone()
	assert_true(_count_thrown_stones() == 1, "Sin piedras no debe lanzar otra")


## Una piedra que cae hace ruido y al detenerse se puede recoger otra vez.
func test_stone_makes_noise_and_becomes_pickup() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var pickups_before := _count_pickups()
	var stone: ThrownStone = STONE_SCENE.instantiate()
	_tunnel.add_child(stone)
	stone.global_position = DROP_POSITION
	stone.linear_velocity = DROP_VELOCITY
	await wait_physics_frames(FALL_FRAMES)
	assert_true(
		_loudest_noise >= ThrownStone.FIRST_IMPACT_LOUDNESS - DEFAULT_TOLERANCE,
		"El primer golpe debe sonar fuerte (sonó %.2f)" % _loudest_noise
	)
	assert_true(_count_thrown_stones() == 0, "La piedra lanzada debe desaparecer al detenerse")
	assert_true(_count_pickups() == pickups_before + 1, "Debe quedar una piedra recogible")


## Cuenta las piedras lanzadas que siguen en el túnel.
func _count_thrown_stones() -> int:
	var total := 0
	for child in _tunnel.get_children():
		if child is ThrownStone and not child.is_queued_for_deletion():
			total += 1
	return total


## Cuenta los objetos recogibles sueltos en el túnel.
func _count_pickups() -> int:
	var total := 0
	for child in _tunnel.get_children():
		if child is Pickup:
			total += 1
	return total


## Guarda el ruido más fuerte escuchado.
func _on_noise_emitted(_origin: Vector3, loudness: float) -> void:
	_loudest_noise = maxf(_loudest_noise, loudness)
