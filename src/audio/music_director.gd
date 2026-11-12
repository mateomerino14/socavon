class_name MusicDirector
extends Node
## Música que sigue al Tío: calma mientras patrulla, tensión cuando sospecha de un ruido o te busca,
## y el bombo cuando te caza. Con dos Tíos manda el que esté más cerca de atraparte.

enum Mood { CALM, TENSION, CHASE }

## Volumen de una capa apagada.
const SILENT_DB := -60.0
## Grupo de los Tíos del nivel.
const ENEMIES_GROUP := &"enemies"

## Lo que tarda en pasar de una capa a otra.
@export var fade_seconds := 3.0
## La persecución entra casi de golpe.
@export var chase_fade_seconds := 0.5

var mood := Mood.CALM

var _base_volumes: Dictionary[Mood, float] = {}
var _tios: Array[Tio] = []
var _fade: Tween

@onready var _layers: Dictionary[Mood, AudioStreamPlayer] = {
	Mood.CALM: $Calm,
	Mood.TENSION: $Tension,
	Mood.CHASE: $Chase,
}


## Arranca todas las capas juntas, con solo la calma audible, y escucha a los Tíos del nivel.
func _ready() -> void:
	for layer_mood: Mood in _layers:
		var layer := _layers[layer_mood]
		_base_volumes[layer_mood] = layer.volume_db
		if layer_mood != Mood.CALM:
			layer.volume_db = SILENT_DB
		layer.play()
	for node in get_tree().get_nodes_in_group(ENEMIES_GROUP):
		if node is Tio:
			_tios.append(node)
			(node as Tio).state_changed.connect(_on_tio_state_changed.unbind(1))


## Pasa a [param new_mood]: sube su capa y baja las demás.
func set_mood(new_mood: Mood) -> void:
	if new_mood == mood:
		return
	mood = new_mood
	var seconds := fade_seconds
	if new_mood == Mood.CHASE:
		seconds = chase_fade_seconds
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel()
	for layer_mood: Mood in _layers:
		var target := SILENT_DB
		if layer_mood == new_mood:
			target = _base_volumes[layer_mood]
		_fade.tween_property(_layers[layer_mood], "volume_db", target, seconds)


## Devuelve el ánimo de la música para un estado del Tío.
static func mood_for(state: Tio.State) -> Mood:
	match state:
		Tio.State.HUNT:
			return Mood.CHASE
		Tio.State.SUSPICION, Tio.State.SEARCH:
			return Mood.TENSION
		_:
			return Mood.CALM


## Suena el ánimo más fuerte entre todos los Tíos.
func _on_tio_state_changed() -> void:
	var strongest := Mood.CALM
	for tio in _tios:
		strongest = maxi(strongest, mood_for(tio.state)) as Mood
	set_mood(strongest)
