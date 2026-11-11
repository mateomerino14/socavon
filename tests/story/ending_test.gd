extends TestCase
## Pruebas del final: el pago al Tío, la persecución al huir sin pagar y el final que toca.

const LEVEL_SCENE := preload("res://src/world/level_05/level_05.tscn")
const SETTLE_FRAMES := 20
const SENSE_FRAMES := 5
const FAST_SECONDS := 0.05
const SCREEN_FRAMES := 30
const AMBUSH_REACH := 2.5
## Coseno del ángulo máximo entre la mirada de Mateo y el Tío.
const FACING_DOT := 0.7

var _level: Level
var _player: Player
var _altar: EndingAltar
var _tio: Tio


## Carga la bocamina.
func before_each() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	_player = _level.get_node("Player")
	_altar = _level.get_node("Altars/PaymentAltar")
	_tio = _level.get_node("Tio")
	await wait_physics_frames(SETTLE_FRAMES)


## Libera el nivel.
func after_each() -> void:
	_level.free()


## Sin las tres ofrendas no se puede pagar.
func test_cannot_pay_without_all_offerings() -> void:
	_player.inventory.add(ItemCatalog.Type.COCA)
	_altar.get_node("Interactable").interact(_player)
	assert_false(GameState.has_paid, "No debe aceptar el pago incompleto")
	assert_true(_player.inventory.count(ItemCatalog.Type.COCA) == 1, "No debe quitar la coca")


## Con coca, alcohol y cigarro el pago se cobra entero y el Tío se calma.
func test_paying_takes_offerings_and_calms_tio() -> void:
	for item in EndingAltar.PAYMENT:
		_player.inventory.add(item)
	_altar.get_node("Interactable").interact(_player)
	assert_true(GameState.has_paid, "Debe quedar pagado")
	for item in EndingAltar.PAYMENT:
		assert_true(_player.inventory.count(item) == 0, "Debe cobrar %s" % item)
	assert_true(_tio.state == Tio.State.CALM, "El Tío debe calmarse al recibir el pago")


## Huir sin pagar suelta al Tío para siempre; con el pago hecho, no.
func test_fleeing_without_paying_starts_chase() -> void:
	var chase: ChaseTrigger = _level.get_node("ChaseTrigger")
	_player.global_position = chase.global_position
	await wait_physics_frames(SENSE_FRAMES)
	assert_true(_tio.is_relentless, "El Tío debe salir tras el jugador sin rendirse")
	assert_true(_tio.state == Tio.State.HUNT, "Debe cazar")


## Con el pago hecho, la zona de persecución no hace nada.
func test_paid_player_is_not_chased() -> void:
	GameState.has_paid = true
	var chase: ChaseTrigger = _level.get_node("ChaseTrigger")
	_player.global_position = chase.global_position
	await wait_physics_frames(SENSE_FRAMES)
	assert_false(_tio.is_relentless, "No debe perseguir a quien pagó")


## La bocamina muestra el final que corresponde y detiene al jugador.
func test_exit_shows_matching_ending() -> void:
	var exit: EndingExit = _level.get_node("EndingExit")
	var screen: EndingScreen = _level.get_node("EndingScreen")
	_speed_up(exit, screen)
	GameState.has_paid = true
	_tio.global_position = _player.global_position + Vector3.FORWARD * 30.0
	_player.global_position = exit.global_position
	await wait_physics_frames(SCREEN_FRAMES)
	assert_true(exit.is_used, "La bocamina debe activarse")
	assert_true(screen.is_showing, "Debe mostrarse el final")
	assert_true(screen.get_node("%Title").text == exit.paid_title, "Debe ser el final con permiso")


## Si huye sin pagar, el Tío aparece a su espalda, Mateo se da la vuelta y se ve el otro final.
func test_unpaid_exit_stages_ambush() -> void:
	var exit: EndingExit = _level.get_node("EndingExit")
	var screen: EndingScreen = _level.get_node("EndingScreen")
	_speed_up(exit, screen)
	_player.global_position = exit.global_position
	await wait_physics_frames(SCREEN_FRAMES)
	var to_tio := _tio.global_position - _player.global_position
	var looking := -_player.global_basis.z
	assert_true(to_tio.length() < AMBUSH_REACH, "El Tío debe aparecer pegado a Mateo")
	assert_true(looking.dot(to_tio.normalized()) > FACING_DOT, "Mateo debe darse la vuelta y verlo")
	assert_true(
		screen.get_node("%Title").text == exit.unpaid_title, "Debe ser el final sin permiso"
	)


## Acorta la escena final para que la prueba no espere.
func _speed_up(exit: EndingExit, screen: EndingScreen) -> void:
	exit.restart_scene_path = ""
	exit.walk_seconds = FAST_SECONDS
	exit.whiteout_seconds = FAST_SECONDS
	exit.ambush_after_seconds = FAST_SECONDS
	exit.turn_seconds = FAST_SECONDS
	exit.ambush_hold_seconds = FAST_SECONDS
	screen.fade_seconds = FAST_SECONDS
	screen.hold_seconds = FAST_SECONDS
