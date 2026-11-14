class_name InventoryScreen
extends CanvasLayer
## Inventario: con Tab detiene el juego y muestra la bolsa con el dibujo de cada objeto, qué es y
## para qué sirve, el objetivo actual y cómo está el Tío con el jugador.

const SLOT_SCENE := preload("res://src/ui/inventory_screen/inventory_slot.tscn")
const OBJECTIVE_FORMAT := "Objetivo: %s"
const NO_OBJECTIVE := "Objetivo: explora la mina"
## Cómo está el Tío según el respeto, de menos a más: el primer umbral que no supera el respeto.
const RESPECT_MOODS: Array[Array] = [
	[25.0, "El Tío está furioso contigo"],
	[45.0, "El Tío desconfía de ti"],
	[65.0, "El Tío te tolera"],
	[85.0, "El Tío te respeta"],
	[100.0, "El Tío te deja andar en su casa"],
]

var is_open := false

var _slots: Array[InventorySlot] = []
var _selected := 0
var _is_hud_visible := true

@onready var _slot_row: HBoxContainer = %SlotRow
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _respect_label: Label = %RespectLabel
@onready var _detail_name: Label = %DetailName
@onready var _detail_description: Label = %DetailDescription
@onready var _detail_use: Label = %DetailUse


## Arma una casilla por objeto y arranca cerrado.
func _ready() -> void:
	for type: ItemCatalog.Type in ItemCatalog.DISPLAY_ORDER:
		var slot: InventorySlot = SLOT_SCENE.instantiate()
		_slot_row.add_child(slot)
		slot.hovered.connect(_select.bind(_slots.size()))
		_slots.append(slot)
	EventBus.hud_visibility_requested.connect(_on_hud_visibility_requested)
	visible = false


## Tab abre o cierra; abierto, Escape cierra y las flechas o A y D eligen objeto.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		elif _can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_select(wrapi(_selected - 1, 0, _slots.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_select(wrapi(_selected + 1, 0, _slots.size()))
		get_viewport().set_input_as_handled()


## Detiene el juego y muestra la bolsa del jugador tal como está.
func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


## Cierra y sigue el juego.
func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Solo se abre jugando: no en cinemáticas, sustos, pausa ni con una nota abierta.
func _can_open() -> bool:
	return _is_hud_visible and not get_tree().paused and _player() != null


## Pone lo que lleva el jugador, el objetivo y el ánimo del Tío; elige el primer objeto que tenga.
func _refresh() -> void:
	var inventory := _player().inventory
	var first_owned := -1
	for index in _slots.size():
		var type := ItemCatalog.DISPLAY_ORDER[index]
		_slots[index].show_item(type, inventory.count(type))
		if first_owned < 0 and inventory.count(type) > 0:
			first_owned = index
	_objective_label.text = NO_OBJECTIVE
	if not GameState.objective.is_empty():
		_objective_label.text = OBJECTIVE_FORMAT % GameState.objective
	_respect_label.text = mood_for(GameState.respect)
	_select(maxi(first_owned, 0))


## Marca un objeto y cuenta qué es y para qué sirve.
func _select(index: int) -> void:
	_selected = index
	for slot_index in _slots.size():
		_slots[slot_index].set_selected(slot_index == index)
	var type := ItemCatalog.DISPLAY_ORDER[index]
	var item_name := ItemCatalog.display_name(type)
	_detail_name.text = item_name.left(1).to_upper() + item_name.substr(1)
	_detail_description.text = ItemCatalog.description(type)
	_detail_use.text = ItemCatalog.use(type)


## Cómo está el Tío con el jugador según su respeto.
static func mood_for(respect: float) -> String:
	for mood: Array in RESPECT_MOODS:
		if respect <= mood[0]:
			return mood[1]
	return RESPECT_MOODS.back()[1]


## Recuerda si el HUD está a la vista; si no, hay una cinemática o un susto.
func _on_hud_visibility_requested(is_visible: bool) -> void:
	_is_hud_visible = is_visible


## El jugador del nivel, si hay uno.
func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player
