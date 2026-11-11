class_name Altar
extends Node3D
## Altar del Tío: recibe ofrendas, sube el respeto y guarda el punto de reaparición.

const ASK_PERMISSION_PROMPT := "Pedir permiso al Tío"
const OFFER_PROMPT := "Ofrendar %s"
const SAVED_NOTICE := "Le pediste permiso al Tío y se guardó la partida"
const OFFERING_NOTICE := "El Tío recibe tu %s y se guardó la partida"
const CANDLE_FLICKER_SPEED := 5.0
const CANDLE_FLICKER_STRENGTH := 0.25

var _candle_noise := FastNoiseLite.new()
var _time := 0.0
var _candle_energy := 0.0

@onready var _interactable: Interactable = $Interactable
@onready var _respawn_point: Marker3D = $RespawnPoint
@onready var _candle_light: OmniLight3D = $CandleLight


## Conecta la interacción y prepara el parpadeo de las velas.
func _ready() -> void:
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	_candle_noise.seed = randi()
	_candle_energy = _candle_light.light_energy


## Hace temblar la luz de las velas.
func _process(delta: float) -> void:
	_time += delta
	var noise := _candle_noise.get_noise_1d(_time * CANDLE_FLICKER_SPEED)
	_candle_light.light_energy = _candle_energy * (1.0 + noise * CANDLE_FLICKER_STRENGTH)


## Devuelve dónde reaparece el jugador al morir tras usar este altar.
func get_respawn_transform() -> Transform3D:
	return _respawn_point.global_transform


## Arma el texto según si el jugador lleva una ofrenda.
func _build_prompt(player: Player) -> String:
	var offering := player.inventory.first_offering()
	if offering == ItemCatalog.Type.NONE:
		return ASK_PERMISSION_PROMPT
	return OFFER_PROMPT % ItemCatalog.display_name(offering)


## Toma una ofrenda si hay, sube el respeto y guarda la partida.
func _on_interacted(player: Player) -> void:
	var notice := SAVED_NOTICE
	var offering := player.inventory.first_offering()
	if offering != ItemCatalog.Type.NONE:
		player.inventory.remove(offering)
		GameState.add_respect(ItemCatalog.OFFERING_RESPECT[offering])
		EventBus.offering_made.emit(global_position, offering)
		notice = OFFERING_NOTICE % ItemCatalog.display_name(offering)
	GameState.save_checkpoint(get_respawn_transform())
	EventBus.notice_requested.emit(notice)
