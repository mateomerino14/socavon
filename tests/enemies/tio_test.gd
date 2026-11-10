extends TestCase
## Pruebas del Tío en el túnel: oído, vista según la luz, calma, pérdida de vista y captura.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const SETTLE_FRAMES := 10
const SENSE_FRAMES := 5
const FACING_CORRIDOR := Vector3(0.0, PI / 2.0, 0.0)
const SIDE_CORRIDOR_SPOT := Vector3(13.0, 0.05, -18.0)
const HIDDEN_SPOT := Vector3(0.0, 0.05, 0.5)
const CLOSE_OFFSET := Vector3(-0.8, 0.05, 0.0)
const LOUD := 1.0
const WALKING := 0.35
const FRAMES_PER_SECOND := 60
const EXTRA_FRAMES := 30
const PATROL_SECONDS := 5
const MIN_PATROL_PROGRESS := 3.0

var _tunnel: Node3D
var _tio: Tio
var _player: Player
var _lamp: CarbideLamp
var _caught_count := 0


## Carga el túnel, deja quieto al Tío mirando al pasillo y escucha las capturas.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_tio = _tunnel.get_node("Tio")
	_player = _tunnel.get_node("Player")
	_lamp = _player.get_node("Head/Camera3D/CarbideLamp")
	_tio.patrol_points.clear()
	_tio.rotation = FACING_CORRIDOR
	EventBus.player_caught.connect(_on_player_caught)


## Libera el túnel.
func after_each() -> void:
	EventBus.player_caught.disconnect(_on_player_caught)
	_tunnel.free()


## Un ruido fuerte cercano lo pone a investigar y camina hacia él.
func test_loud_noise_makes_him_investigate() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var start_x := _tio.global_position.x
	EventBus.noise_emitted.emit(_tio.global_position + Vector3(-6.0, 0.0, 0.0), LOUD)
	assert_true(_tio.state == Tio.State.SUSPICION, "Debe pasar a sospecha")
	await wait_physics_frames(FRAMES_PER_SECOND)
	assert_true(_tio.global_position.x < start_x, "Debe caminar hacia el ruido")


## Un paso lejano no lo alcanza.
func test_far_footstep_is_not_heard() -> void:
	EventBus.noise_emitted.emit(HIDDEN_SPOT, WALKING)
	assert_true(_tio.state == Tio.State.PATROL, "No debe oír un paso a 25 metros")


## Con la lámpara encendida lo ve desde lejos y lo caza.
func test_sees_lit_player_and_hunts() -> void:
	_player.global_position = SIDE_CORRIDOR_SPOT
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(_tio.state == Tio.State.HUNT, "Debe cazar al jugador iluminado a 6 metros")


## A oscuras y a la misma distancia no lo ve.
func test_does_not_see_dark_player() -> void:
	_lamp.set_lit(false)
	_player.global_position = SIDE_CORRIDOR_SPOT
	await wait_physics_frames(SENSE_FRAMES)
	assert_false(_tio.state == Tio.State.HUNT, "No debe ver al jugador a oscuras a 6 metros")


## Una ofrenda lo calma y en calma no oye.
func test_offering_calms_him() -> void:
	EventBus.offering_made.emit(Vector3.ZERO, ItemCatalog.Type.COCA)
	assert_true(_tio.state == Tio.State.CALM, "Debe calmarse con la ofrenda")
	EventBus.noise_emitted.emit(_tio.global_position, LOUD)
	assert_true(_tio.state == Tio.State.CALM, "En calma no debe reaccionar al ruido")


## Si deja de verlo el tiempo indicado, pasa a buscarlo.
func test_losing_sight_starts_search() -> void:
	_player.global_position = SIDE_CORRIDOR_SPOT
	await wait_physics_frames(SENSE_FRAMES)
	_player.global_position = HIDDEN_SPOT
	var frames := int(_tio.lose_sight_seconds * FRAMES_PER_SECOND) + EXTRA_FRAMES
	await wait_physics_frames(frames)
	assert_true(_tio.state == Tio.State.SEARCH, "Debe buscarlo tras perderlo de vista")


## Al alcanzarlo avisa la captura una sola vez.
func test_catches_close_player_once() -> void:
	_player.global_position = _tio.global_position + CLOSE_OFFSET
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(_caught_count == 1, "Debe atrapar al jugador una vez (fueron %d)" % _caught_count)


## Con más respeto oye a menos distancia.
func test_respect_reduces_hearing() -> void:
	var hearing: NoiseHearing = _tio.get_node("NoiseHearing")
	var reach_before := hearing.get_reach(LOUD)
	GameState.add_respect(GameState.MAX_RESPECT)
	assert_true(hearing.get_reach(LOUD) < reach_before, "Con respeto alto debe oír menos lejos")


## Patrulla por el túnel hacia el siguiente punto.
func test_patrols_between_points() -> void:
	for point in _tunnel.get_node("PatrolPoints").get_children():
		_tio.patrol_points.append(point)
	_tio.reset()
	var side_corridor: Vector3 = _tio.patrol_points[1].global_position
	var start_distance := _tio.global_position.distance_to(side_corridor)
	await wait_physics_frames(PATROL_SECONDS * FRAMES_PER_SECOND)
	var distance := _tio.global_position.distance_to(side_corridor)
	assert_true(
		distance < start_distance - MIN_PATROL_PROGRESS, "Debe acercarse al pasillo lateral"
	)
	assert_true(_tio.state == Tio.State.PATROL, "Debe seguir patrullando")


## Cuenta las capturas.
func _on_player_caught() -> void:
	_caught_count += 1


## Con el Tío cerca el presentimiento sube; lejos es cero.
func test_dread_rises_when_tio_is_near() -> void:
	var dread_sense: DreadSense = _player.get_node("DreadSense")
	assert_almost_eq(dread_sense.update_dread(), 0.0, "Lejos del Tío no debe haber presentimiento")
	_player.global_position = _tio.global_position + Vector3(-2.0, 0.0, 0.0)
	assert_true(dread_sense.update_dread() > 0.7, "A 2 metros el presentimiento debe ser fuerte")


## Al caminar, sus pasos suenan.
func test_steps_play_while_walking() -> void:
	var audio: AudioStreamPlayer3D = _tio.get_node("StrideAudio/Audio")
	var played := [false]
	audio.finished.connect(func() -> void: played[0] = true)
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.noise_emitted.emit(_tio.global_position + Vector3(-8.0, 0.0, 0.0), LOUD)
	var heard := false
	for i in PATROL_SECONDS * FRAMES_PER_SECOND:
		await tree.physics_frame
		heard = heard or audio.playing or played[0]
	assert_true(heard, "Los pasos del Tío deben sonar al caminar")


## Quieto respira, al cazar corre y al atrapar embiste.
func test_body_animation_follows_state() -> void:
	var animator: TioAnimator = _tio.get_node("Model")
	var animation_player: AnimationPlayer = (
		_tio.find_children("*", "AnimationPlayer", true, false)[0]
	)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(animation_player.current_animation == TioAnimator.IDLE, "Quieto debe respirar")
	animator.register_movement(_tio.hunt_speed)
	assert_true(animation_player.current_animation == TioAnimator.RUN, "Cazando debe correr")
	_player.global_position = _tio.global_position + CLOSE_OFFSET
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(animation_player.current_animation == TioAnimator.CATCH, "Al atrapar debe embestir")
