extends TestCase
## Pruebas de la música: cada estado del Tío tiene su ánimo y, con dos Tíos, suena el más fuerte.

const LEVEL_SCENE := preload("res://src/world/level_04/level_04.tscn")

var _level: Node3D
var _director: MusicDirector


## Carga el nivel de los dos Tíos.
func before_each() -> void:
	GameState.reset()
	_level = add_to_tree(LEVEL_SCENE.instantiate())
	_director = _level.get_node("MusicDirector")


## Libera el nivel.
func after_each() -> void:
	_level.free()
	GameState.reset()


## Patrulla y calma suenan tranquilas, sospecha y búsqueda en tensión, la caza con el bombo.
func test_mood_for_each_state() -> void:
	assert_true(MusicDirector.mood_for(Tio.State.PATROL) == MusicDirector.Mood.CALM, "Patrulla")
	assert_true(MusicDirector.mood_for(Tio.State.CALM) == MusicDirector.Mood.CALM, "Calmado")
	assert_true(
		MusicDirector.mood_for(Tio.State.SUSPICION) == MusicDirector.Mood.TENSION, "Sospecha"
	)
	assert_true(MusicDirector.mood_for(Tio.State.SEARCH) == MusicDirector.Mood.TENSION, "Busca")
	assert_true(MusicDirector.mood_for(Tio.State.HUNT) == MusicDirector.Mood.CHASE, "Caza")


## Si un Tío caza y el otro patrulla, suena la persecución; cuando los dos se calman, la calma.
func test_strongest_tio_wins() -> void:
	var hunter: Tio = _level.get_node("Tio")
	var other: Tio = _level.get_node("TioShadow")
	hunter.state = Tio.State.HUNT
	hunter.state_changed.emit(hunter.state)
	other.state = Tio.State.PATROL
	other.state_changed.emit(other.state)
	assert_true(_director.mood == MusicDirector.Mood.CHASE, "Manda el que caza")
	hunter.state = Tio.State.PATROL
	hunter.state_changed.emit(hunter.state)
	assert_true(_director.mood == MusicDirector.Mood.CALM, "Los dos tranquilos, calma")
