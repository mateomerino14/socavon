class_name Hud
extends CanvasLayer
## HUD mínimo: barras de carburo y aliento, acción al frente, avisos, bolsa y subtítulos.

const FULL_RATIO := 0.995
const SHOWN_ALPHA := 1.0
const HIDDEN_ALPHA := 0.0
const FADE_SPEED := 3.0
const NOTICE_SECONDS := 3.0
const INVENTORY_SECONDS := 4.0
const PROMPT_FORMAT := "[E]  %s"
const INVENTORY_SEPARATOR := "   ·   "
const INVENTORY_ENTRY := "%s %d"
const SUBTITLE_FORMAT := "%s: %s"

var _target_alpha := {}
var _inventory_counts := {}

@onready var _fuel_bar: ProgressBar = %FuelBar
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _prompt_label: Label = %PromptLabel
@onready var _notice_label: Label = %NoticeLabel
@onready var _inventory_label: Label = %InventoryLabel
@onready var _notice_timer: Timer = %NoticeTimer
@onready var _inventory_timer: Timer = %InventoryTimer
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _subtitle_timer: Timer = %SubtitleTimer
@onready var _bars: Control = $Bars
@onready var _crosshair: Control = $Crosshair


## Escucha al bus y arranca con todo oculto.
func _ready() -> void:
	for control: Control in [
		_fuel_bar, _stamina_bar, _notice_label, _inventory_label, _subtitle_label
	]:
		control.modulate.a = HIDDEN_ALPHA
		_target_alpha[control] = HIDDEN_ALPHA
	_prompt_label.text = ""
	_notice_timer.timeout.connect(_hide.bind(_notice_label))
	_inventory_timer.timeout.connect(_hide.bind(_inventory_label))
	_subtitle_timer.timeout.connect(_hide.bind(_subtitle_label))
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.lamp_fuel_changed.connect(_on_lamp_fuel_changed)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	EventBus.notice_requested.connect(_on_notice_requested)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.subtitle_requested.connect(_on_subtitle_requested)
	EventBus.hud_visibility_requested.connect(_on_hud_visibility_requested)


## Acerca la transparencia de cada elemento a la que le toca.
func _process(delta: float) -> void:
	for control: Control in _target_alpha:
		control.modulate.a = move_toward(
			control.modulate.a, _target_alpha[control], FADE_SPEED * delta
		)


## Actualiza la barra de aliento.
func _on_stamina_changed(current: float, maximum: float) -> void:
	_update_bar(_stamina_bar, current, maximum)


## Actualiza la barra de carburo.
func _on_lamp_fuel_changed(current: float, maximum: float) -> void:
	_update_bar(_fuel_bar, current, maximum)


## Muestra qué se puede hacer con lo que está al frente.
func _on_interaction_prompt_changed(prompt: String) -> void:
	_prompt_label.text = ""
	if not prompt.is_empty():
		_prompt_label.text = PROMPT_FORMAT % prompt


## Muestra un aviso breve que se desvanece solo.
func _on_notice_requested(text: String) -> void:
	_notice_label.text = text
	_show_for(_notice_label, _notice_timer, NOTICE_SECONDS)


## Oculta o muestra las barras, la mira y lo que se puede usar; los subtítulos siguen visibles.
func _on_hud_visibility_requested(is_visible: bool) -> void:
	_bars.visible = is_visible
	_crosshair.visible = is_visible
	_prompt_label.visible = is_visible


## Muestra quién habla y qué dice durante el tiempo de la línea.
func _on_subtitle_requested(speaker: String, text: String, seconds: float) -> void:
	_subtitle_label.text = SUBTITLE_FORMAT % [speaker, text]
	_show_for(_subtitle_label, _subtitle_timer, seconds)


## Muestra un momento lo que hay en la bolsa.
func _on_inventory_changed(type: ItemCatalog.Type, count: int) -> void:
	_inventory_counts[type] = count
	var entries := PackedStringArray()
	for item_type: ItemCatalog.Type in _inventory_counts:
		if _inventory_counts[item_type] > 0:
			var item_name := _sentence_case(ItemCatalog.display_name(item_type))
			entries.append(INVENTORY_ENTRY % [item_name, _inventory_counts[item_type]])
	_inventory_label.text = INVENTORY_SEPARATOR.join(entries)
	_show_for(_inventory_label, _inventory_timer, INVENTORY_SECONDS)


## Pone en mayúscula solo la primera letra, como se escribe en español.
func _sentence_case(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


## Pone el valor de la barra y la muestra solo si no está llena.
func _update_bar(bar: ProgressBar, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	_target_alpha[bar] = HIDDEN_ALPHA
	if current / maximum < FULL_RATIO:
		_target_alpha[bar] = SHOWN_ALPHA


## Muestra un elemento y lo oculta cuando termina su temporizador.
func _show_for(control: Control, timer: Timer, seconds: float) -> void:
	_target_alpha[control] = SHOWN_ALPHA
	timer.start(seconds)


## Desvanece un elemento.
func _hide(control: Control) -> void:
	_target_alpha[control] = HIDDEN_ALPHA
