extends TestCase
## Pruebas del HUD: la bolsa se escribe con mayúscula solo al inicio de cada nombre, en los sustos
## no queda a la vista lo que se puede usar y se anuncian el nombre del nivel y el objetivo.

const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const LEAVE_PROMPT := "Salir del escondite"
const OBJECTIVE := "Busca la palanca de la compuerta"
const TITLE := "Nivel 2 · Los rieles"

var _hud: Hud


## Crea el HUD.
func before_each() -> void:
	_hud = HUD_SCENE.instantiate()
	add_to_tree(_hud)


## Libera el HUD.
func after_each() -> void:
	_hud.free()


## "Hojas de coca", no "Hojas De Coca".
func test_inventory_uses_sentence_case() -> void:
	EventBus.inventory_changed.emit(ItemCatalog.Type.COCA, 1)
	var label: Label = _hud.get_node("%InventoryLabel")
	assert_true(
		label.text == "Hojas de coca 1", "Debe decir 'Hojas de coca 1' (dice '%s')" % label.text
	)


## Al ocultar el HUD, como en el susto, también se oculta el aviso de lo que se puede usar.
func test_hidden_hud_hides_prompt() -> void:
	EventBus.interaction_prompt_changed.emit(LEAVE_PROMPT)
	EventBus.hud_visibility_requested.emit(false)
	var label: Label = _hud.get_node("%PromptLabel")
	assert_false(label.visible, "El aviso no debe verse sobre la cara del Tío")
	EventBus.hud_visibility_requested.emit(true)
	assert_true(label.visible, "Vuelve a verse al reaparecer")


## Un objetivo nuevo se muestra arriba a la izquierda con su sonido.
func test_objective_is_announced_with_sound() -> void:
	EventBus.objective_changed.emit(OBJECTIVE)
	var label: Label = _hud.get_node("%ObjectiveLabel")
	var sound: AudioStreamPlayer = _hud.get_node("%ObjectiveSound")
	assert_true(label.text == OBJECTIVE, "Muestra el objetivo")
	assert_true(sound.playing, "Suena el aviso")


## Si llega un objetivo con el HUD oculto, se anuncia cuando vuelve a mostrarse.
func test_objective_waits_for_hidden_hud() -> void:
	EventBus.hud_visibility_requested.emit(false)
	EventBus.objective_changed.emit(OBJECTIVE)
	var label: Label = _hud.get_node("%ObjectiveLabel")
	assert_false(label.text == OBJECTIVE, "No se anuncia durante una cinemática")
	EventBus.hud_visibility_requested.emit(true)
	assert_true(label.text == OBJECTIVE, "Se anuncia al volver el HUD")


## El nombre del nivel se muestra abajo a la izquierda.
func test_level_title_is_shown() -> void:
	EventBus.level_title_requested.emit(TITLE)
	var label: Label = _hud.get_node("%TitleLabel")
	assert_true(label.text == TITLE, "Muestra el nombre del nivel")
