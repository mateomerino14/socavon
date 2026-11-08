extends TestCase
## Pruebas de los escondites: entrar y salir, lo que ve el Tío y cuándo saca al jugador.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const HIDE_FRAMES := 60
const SENSE_FRAMES := 5
const FRAMES_PER_SECOND := 60
const SEARCH_SECONDS := 8
const FACING_WEST := Vector3(0.0, PI / 2.0, 0.0)

var _tunnel: Node3D
var _player: Player
var _tio: Tio
var _niche: HidingSpot
var _lamp: CarbideLamp
var _caught := 0


## Carga el túnel con el Tío quieto y escucha las capturas.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_player = _tunnel.get_node("Player")
	_tio = _tunnel.get_node("Tio")
	_niche = _tunnel.get_node("HidingSpots/SideNicheSpot")
	_lamp = _player.get_node("Head/Camera3D/CarbideLamp")
	_tio.patrol_points.clear()
	EventBus.player_caught.connect(_on_caught)


## Libera el túnel.
func after_each() -> void:
	EventBus.player_caught.disconnect(_on_caught)
	_tunnel.free()


## Entra al escondite con animación y sale por su salida.
func test_hide_and_leave() -> void:
	_player.hide_in(_niche)
	assert_false(_player.is_hidden, "Mientras entra todavía no está escondido")
	await wait_physics_frames(HIDE_FRAMES)
	assert_true(_player.is_hidden, "Al terminar la animación queda escondido")
	var inside := _player.global_position.distance_to(_niche.get_hide_transform().origin)
	assert_true(inside < 0.1, "Debe quedar en el punto del escondite")
	_player.leave_hiding()
	await wait_physics_frames(HIDE_FRAMES)
	assert_true(_player.hiding_spot == null, "Debe salir del escondite")
	var outside := _player.global_position.distance_to(_niche.get_exit_transform().origin)
	assert_true(outside < 0.3, "Debe quedar en la salida del escondite")


## Escondido y a oscuras, el Tío no lo ve aunque esté cerca.
func test_hidden_in_dark_is_invisible() -> void:
	_lamp.set_lit(false)
	await _hide_unseen()
	_place_tio_facing_niche(2.0)
	await wait_physics_frames(SENSE_FRAMES)
	assert_false(_tio.state == Tio.State.HUNT, "No debe verlo escondido a oscuras")


## Escondido con la lámpara encendida, la luz lo delata de cerca.
func test_hidden_with_lamp_is_seen_up_close() -> void:
	await _hide_unseen()
	_place_tio_facing_niche(2.0)
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(_tio.state == Tio.State.HUNT, "La lámpara encendida debe delatarlo a 2 metros")


## Si el Tío no sabe del escondite, pasar al lado no lo atrapa.
func test_tio_passing_by_does_not_catch() -> void:
	_lamp.set_lit(false)
	await _hide_unseen()
	_tio.global_position = _niche.get_exit_transform().origin
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(_caught == 0, "No debe atraparlo si no sabe que está ahí")


## Si lo vio entrar, lo saca del escondite.
func test_tio_who_saw_you_hide_catches_you() -> void:
	_place_tio_facing_niche(5.0)
	_player.global_position = _niche.get_exit_transform().origin
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(_tio.state == Tio.State.HUNT, "Debe estar cazando antes de que se esconda")
	_player.hide_in(_niche)
	await wait_physics_frames(SEARCH_SECONDS * FRAMES_PER_SECOND)
	assert_true(_caught == 1, "Debe sacarlo del escondite donde lo vio entrar")


## Al buscar, revisa los escondites cercanos.
func test_search_checks_hiding_spots() -> void:
	_lamp.set_lit(false)
	await _hide_unseen()
	_tio.spot_check_chance = 1.0
	_tio.global_position = _niche.get_exit_transform().origin + Vector3(4.0, 0.0, 0.0)
	EventBus.noise_emitted.emit(_niche.get_exit_transform().origin, 1.0)
	_tio.set("_last_known_position", _niche.get_exit_transform().origin)
	_tio.call("_enter_state", Tio.State.SEARCH)
	await wait_physics_frames(SEARCH_SECONDS * FRAMES_PER_SECOND)
	assert_true(_caught == 1, "Debe revisar el escondite y encontrarlo")


## Mete al jugador al nicho sin que el Tío lo vea.
func _hide_unseen() -> void:
	_player.hide_in(_niche)
	await wait_physics_frames(HIDE_FRAMES)


## Pone al Tío en el pasillo, a esa distancia al este del nicho, mirando hacia él.
func _place_tio_facing_niche(distance: float) -> void:
	var exit := _niche.get_exit_transform().origin
	_tio.global_position = Vector3(exit.x + distance, 0.0, exit.z)
	_tio.rotation = FACING_WEST


## Cuenta las capturas.
func _on_caught() -> void:
	_caught += 1
