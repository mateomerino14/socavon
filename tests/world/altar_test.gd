extends TestCase
## Pruebas del altar y de los objetos del túnel: ofrendar, guardar, recoger y el texto al frente.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const SETTLE_FRAMES := 10
const PROMPT_FRAMES := 5

var _tunnel: Node3D
var _player: Player
var _altar: Altar
var _last_prompt := ""


## Carga el túnel con una partida nueva.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_player = _tunnel.get_node("Player")
	_altar = _tunnel.get_node("Altars/EntryAltar")
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)


## Libera el túnel.
func after_each() -> void:
	EventBus.interaction_prompt_changed.disconnect(_on_prompt_changed)
	_tunnel.free()


## Ofrendar coca la quita de la bolsa, sube el respeto y guarda en el altar.
func test_offering_raises_respect_and_saves() -> void:
	_player.inventory.add(ItemCatalog.Type.COCA)
	var respect_before := GameState.respect
	_interactable_of(_altar).interact(_player)
	assert_true(_player.inventory.count(ItemCatalog.Type.COCA) == 0, "Debe gastar la coca")
	assert_almost_eq(
		GameState.respect,
		respect_before + ItemCatalog.OFFERING_RESPECT[ItemCatalog.Type.COCA],
		"Debe subir el respeto según la coca"
	)
	assert_true(
		GameState.checkpoint.origin.is_equal_approx(_altar.get_respawn_transform().origin),
		"Debe guardar el punto de reaparición del altar"
	)


## Sin ofrenda solo guarda la partida.
func test_asking_permission_only_saves() -> void:
	var respect_before := GameState.respect
	_interactable_of(_altar).interact(_player)
	assert_almost_eq(GameState.respect, respect_before, "No debe cambiar el respeto")
	assert_true(
		GameState.checkpoint.origin.is_equal_approx(_altar.get_respawn_transform().origin),
		"Debe guardar el punto de reaparición del altar"
	)


## Recoger un objeto lo pasa a la bolsa y lo quita del suelo.
func test_pickup_goes_to_inventory() -> void:
	var pickup: Pickup = _tunnel.get_node("Pickups/Carbide")
	_interactable_of(pickup).interact(_player)
	assert_true(_player.inventory.count(ItemCatalog.Type.CARBIDE) == 1, "Debe llevar un carburo")
	assert_true(pickup.is_queued_for_deletion(), "El carburo debe desaparecer del suelo")


## Mirando el altar desde su punto de reaparición, aparece el texto para pedir permiso.
func test_prompt_appears_when_looking_at_altar() -> void:
	_player.global_transform = _altar.get_respawn_transform()
	await wait_physics_frames(SETTLE_FRAMES)
	await wait_physics_frames(PROMPT_FRAMES)
	assert_true(
		_last_prompt == Altar.ASK_PERMISSION_PROMPT,
		"Debe pedir permiso al mirar el altar (texto: '%s')" % _last_prompt
	)


## Recargar la lámpara gasta un carburo y suma combustible.
func test_refill_lamp_uses_carbide() -> void:
	var lamp: CarbideLamp = _player.get_node("Head/Camera3D/CarbideLamp")
	lamp.consume_fuel(lamp.max_fuel)
	_player.inventory.add(ItemCatalog.Type.CARBIDE)
	_player.refill_lamp()
	assert_almost_eq(lamp.fuel, Player.CARBIDE_FUEL, "Debe recargar una carga de carburo")
	assert_true(lamp.is_lit, "Debe volver a encender la lámpara")
	assert_true(_player.inventory.count(ItemCatalog.Type.CARBIDE) == 0, "Debe gastar el carburo")


## Devuelve la zona interactuable de un altar u objeto.
func _interactable_of(node: Node) -> Interactable:
	return node.get_node("Interactable")


## Guarda el último texto de interacción publicado.
func _on_prompt_changed(prompt: String) -> void:
	_last_prompt = prompt
