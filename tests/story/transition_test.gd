extends TestCase
## Pruebas del tránsito entre niveles: Mateo camina, habla, se ve el nombre del nivel siguiente y se
## puede saltar. También que cada salida tenga su tránsito hacia el nivel que corresponde.

const TRANSITION_SCENE := preload("res://src/story/transition/transition.tscn")
const LINE := preload("res://src/story/voices/mateo_transito_veta.tres")
const FAST_SECONDS := 0.05
const FAST_WALK_SECONDS := 0.3
const FAST_LINE_DELAY := 0.1
const FINISH_FRAMES := 120
const SKIP_FRAMES := 10
const TITLE := "Nivel 3 · La veta"
const LEVELS_WITH_EXIT: Array[int] = [1, 2, 3, 4]
const LEVEL_PATH := "res://src/world/level_%02d/level_%02d.tscn"
const SPEAKER := "Mateo"

var _transition: Transition
var _finished := false
var _subtitle_speaker := ""


## Arma un tránsito acelerado, con el Tío y los rieles, sin nivel siguiente.
func before_each() -> void:
	_transition = TRANSITION_SCENE.instantiate()
	_transition.enabled = false
	var data := TransitionData.new()
	data.title = TITLE
	data.line = LINE
	data.has_rails = true
	data.shows_tio = true
	_transition.data = data
	for property: String in ["fade_seconds", "title_seconds"]:
		_transition.set(property, FAST_SECONDS)
	_transition.walk_seconds = FAST_WALK_SECONDS
	_transition.line_delay_seconds = FAST_LINE_DELAY
	_transition.finished.connect(_on_finished)
	EventBus.subtitle_requested.connect(_on_subtitle)
	add_to_tree(_transition)


## Libera el tránsito.
func after_each() -> void:
	EventBus.subtitle_requested.disconnect(_on_subtitle)
	_transition.free()


## Visto entero: Mateo avanza hacia la cámara, habla y aparece el nombre del nivel.
func test_plays_whole_transition() -> void:
	var mateo: Node3D = _transition.get_node("Mateo")
	var start := mateo.position
	_transition.play()
	await wait_physics_frames(FINISH_FRAMES)
	assert_true(_finished, "El tránsito debe terminar")
	assert_false(_transition.is_playing, "Al terminar ya no se reproduce")
	var walked := mateo.position.z - start.z
	assert_almost_eq(
		walked, _transition.walk_distance, "Mateo camina hacia la cámara", FAST_SECONDS
	)
	assert_true(_subtitle_speaker == SPEAKER, "Mateo dice su línea con subtítulo")
	assert_true(
		(_transition.get_node("%Title") as Label).text == TITLE, "Muestra el nivel siguiente"
	)


## Lo que pide el tránsito se ve: rieles y el Tío detrás de Mateo.
func test_shows_rails_and_tio() -> void:
	assert_true((_transition.get_node("Rails") as Node3D).visible, "Debe mostrar los rieles")
	assert_true((_transition.get_node("Tio") as Node3D).visible, "Debe mostrar al Tío")


## Saltarlo lo termina enseguida.
func test_skip_ends_quickly() -> void:
	_transition.walk_seconds = FINISH_FRAMES
	_transition.play()
	await wait_physics_frames(SKIP_FRAMES)
	_transition.skip()
	await wait_physics_frames(SKIP_FRAMES)
	assert_true(_finished, "Saltado, el tránsito debe terminar")


## Cada salida de los niveles 1 a 4 lleva su tránsito, con voz y el nombre del nivel siguiente.
func test_every_exit_has_its_transition() -> void:
	for number in LEVELS_WITH_EXIT:
		var transition := _exit_property(number, &"transition") as TransitionData
		assert_true(transition != null, "La salida del nivel %d debe tener tránsito" % number)
		if transition == null:
			continue
		assert_true(transition.line != null, "El tránsito del nivel %d debe tener voz" % number)
		var next_title := _root_property(number + 1, &"title") as String
		assert_true(transition.title == next_title, "Debe anunciar %s" % next_title)


## Lee una propiedad de la salida de un nivel sin instanciarlo.
func _exit_property(number: int, property: StringName) -> Variant:
	var state := _level_state(number)
	for node in state.get_node_count():
		if state.get_node_name(node) == &"LevelExit":
			return _node_property(state, node, property)
	return null


## Lee una propiedad de la raíz de un nivel sin instanciarlo.
func _root_property(number: int, property: StringName) -> Variant:
	return _node_property(_level_state(number), 0, property)


## Devuelve la escena guardada de un nivel.
func _level_state(number: int) -> SceneState:
	var scene: PackedScene = load(LEVEL_PATH % [number, number])
	return scene.get_state()


## Busca una propiedad entre las que guarda la escena para un nodo.
func _node_property(state: SceneState, node: int, property: StringName) -> Variant:
	for index in state.get_node_property_count(node):
		if state.get_node_property_name(node, index) == property:
			return state.get_node_property_value(node, index)
	return null


## Anota que el tránsito terminó.
func _on_finished() -> void:
	_finished = true


## Anota quién habló.
func _on_subtitle(speaker: String, _text: String, _seconds: float) -> void:
	_subtitle_speaker = speaker
