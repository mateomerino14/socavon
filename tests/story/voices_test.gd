extends TestCase
## Pruebas de las voces: subtítulos, zonas que hablan una vez, la voz del Tío y el guion completo.

const LEVEL_SCENE := preload("res://src/world/level_01/level_01.tscn")
const VOICE_SCENE := preload("res://src/story/voice_player.tscn")
const VOICES_DIR := "res://src/story/voices/"
const SCRIPT_PATH := "res://docs/guion_voces.md"
const SETTLE_FRAMES := 10

var _subtitles: Array[String] = []


## Escucha los subtítulos.
func before_each() -> void:
	EventBus.subtitle_requested.connect(_on_subtitle)


## Deja de escuchar.
func after_each() -> void:
	EventBus.subtitle_requested.disconnect(_on_subtitle)


## Una línea sin grabación muestra su subtítulo con una duración estimada.
func test_line_without_audio_shows_subtitle() -> void:
	var voice: VoicePlayer = add_to_tree(VOICE_SCENE.instantiate())
	var line := VoiceLine.new()
	line.speaker = "Mateo"
	line.text = "Hola"
	var lines: Array[VoiceLine] = [line]
	voice.say(lines)
	assert_true(_subtitles == ["Mateo: Hola"], "Debe mostrar el subtítulo de la línea")
	assert_almost_eq(
		VoicePlayer.get_line_seconds(line),
		VoicePlayer.MIN_LINE_SECONDS,
		"Línea corta: duración mínima"
	)
	voice.free()


## La zona del cruce habla una sola vez al entrar el jugador.
func test_trigger_speaks_once() -> void:
	var level: Level = add_to_tree(LEVEL_SCENE.instantiate())
	var player: Player = level.get_node("Player")
	var trigger: VoiceTrigger = level.get_node("Voices/JunctionTrigger")
	await wait_physics_frames(SETTLE_FRAMES)
	player.global_position = trigger.global_position
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(trigger.is_used, "La zona debe activarse")
	assert_true(_subtitles.size() == 1, "Debe hablar una sola vez")
	level.free()


## El Tío dice una frase al empezar a cazar.
func test_tio_speaks_when_hunting() -> void:
	var level: Level = add_to_tree(LEVEL_SCENE.instantiate())
	var tio: Tio = level.get_node("Tio")
	tio.call("_enter_state", Tio.State.HUNT)
	assert_true(_subtitles.size() == 1, "El Tío debe decir algo al cazar")
	assert_true(_subtitles[0].begins_with("El Tío:"), "La frase debe ser del Tío")
	level.free()


## Cada línea está completa y aparece en el guion para grabarla.
func test_every_line_is_in_the_script() -> void:
	var script_text := FileAccess.get_file_as_string(SCRIPT_PATH)
	for file in DirAccess.get_files_at(VOICES_DIR):
		var line: VoiceLine = load(VOICES_DIR.path_join(file))
		assert_false(line.speaker.is_empty(), "%s debe tener personaje" % file)
		assert_false(line.text.is_empty(), "%s debe tener texto" % file)
		assert_true(script_text.contains("`%s`" % line.id), "%s debe estar en el guion" % line.id)


## Guarda cada subtítulo mostrado.
func _on_subtitle(speaker: String, text: String, _seconds: float) -> void:
	_subtitles.append("%s: %s" % [speaker, text])
