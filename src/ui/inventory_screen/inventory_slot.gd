class_name InventorySlot
extends PanelContainer
## Casilla de un objeto en el inventario: su dibujo, su nombre y cuántos lleva de cuántos caben.

## El ratón pasó por encima: el inventario la elige.
signal hovered

const COUNT_FORMAT := "%d / %d"
const OWNED_ALPHA := 1.0
const EMPTY_ALPHA := 0.35

var type := ItemCatalog.Type.NONE

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _normal_style: StyleBox = get_theme_stylebox("panel")
@onready var _selected_style: StyleBox = preload("res://src/ui/inventory_screen/slot_selected.tres")


## Avisa cuando el ratón entra.
func _ready() -> void:
	mouse_entered.connect(hovered.emit)


## Muestra el objeto y cuántos lleva; apagado si no lleva ninguno.
func show_item(item_type: ItemCatalog.Type, count: int) -> void:
	type = item_type
	_icon.texture = ItemCatalog.icon(item_type)
	var item_name := ItemCatalog.display_name(item_type)
	_name_label.text = item_name.left(1).to_upper() + item_name.substr(1)
	_count_label.text = COUNT_FORMAT % [count, ItemCatalog.max_stack(item_type)]
	_icon.modulate.a = EMPTY_ALPHA
	if count > 0:
		_icon.modulate.a = OWNED_ALPHA


## Marca o desmarca la casilla elegida.
func set_selected(is_selected: bool) -> void:
	remove_theme_stylebox_override("panel")
	if is_selected:
		add_theme_stylebox_override("panel", _selected_style)
	else:
		add_theme_stylebox_override("panel", _normal_style)
