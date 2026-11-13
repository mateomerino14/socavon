extends TestCase
## Pruebas del HUD: la bolsa se escribe con mayúscula solo al inicio de cada nombre y en los sustos
## no queda a la vista lo que se puede usar.

const HUD_SCENE := preload("res://src/ui/hud/hud.tscn")
const LEAVE_PROMPT := "Salir del escondite"

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
