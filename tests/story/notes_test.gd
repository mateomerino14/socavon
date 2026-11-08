extends TestCase
## Pruebas de las notas: se leen en pantalla con el juego en pausa y quedan registradas.

const LEVEL_SCENE := preload("res://src/world/level_01/level_01.tscn")
const NOTES_DIR := "res://src/story/notes/"

var _level: Level
var _player: Player
var _viewer: NoteViewer


## Carga el nivel 1.
func before_each() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	_player = _level.get_node("Player")
	_viewer = _level.get_node("NoteViewer")


## Quita la pausa y libera el nivel.
func after_each() -> void:
	tree.paused = false
	_level.free()


## Leer una nota la muestra, pausa el juego y la recuerda; cerrarla reanuda.
func test_reading_a_note_pauses_and_remembers_it() -> void:
	var note: ReadableNote = _level.get_node("Notes/FaustinoShift")
	note.get_node("Interactable").interact(_player)
	assert_true(_viewer.is_open, "El visor debe abrirse")
	assert_true(tree.paused, "Leer debe pausar el juego")
	assert_true(GameState.has_read_note(note.note.id), "La nota debe quedar leída")
	var title: Label = _viewer.get_node("%Title")
	assert_true(title.text == note.note.title, "Debe mostrar el título de la nota")
	_viewer.close()
	assert_false(tree.paused, "Cerrar debe reanudar el juego")


## Después de leerla, el texto de interacción cambia a volver a leer.
func test_prompt_changes_after_reading() -> void:
	var note: ReadableNote = _level.get_node("Notes/Letter1974")
	var interactable: Interactable = note.get_node("Interactable")
	assert_true(interactable.get_prompt(_player).begins_with("Leer"), "Antes dice Leer")
	interactable.interact(_player)
	_viewer.close()
	assert_true(
		interactable.get_prompt(_player).begins_with("Volver"), "Después dice Volver a leer"
	)


## La inscripción pinta su texto en la roca.
func test_inscription_paints_its_text() -> void:
	var inscription: ReadableNote = _level.get_node("Notes/SevenInscription")
	var text: Label3D = inscription.get_node("Text")
	assert_true(text.text == inscription.note.body, "El texto de la roca debe ser el de la nota")


## Cada nota tiene identificador, título y texto, y los identificadores no se repiten.
func test_every_note_is_complete() -> void:
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at(NOTES_DIR):
		var note: NoteData = load(NOTES_DIR.path_join(file))
		assert_false(note.id.is_empty(), "%s debe tener identificador" % file)
		assert_false(note.title.is_empty(), "%s debe tener título" % file)
		assert_false(note.body.is_empty(), "%s debe tener texto" % file)
		assert_false(ids.has(note.id), "%s repite el identificador %s" % [file, note.id])
		ids.append(note.id)
