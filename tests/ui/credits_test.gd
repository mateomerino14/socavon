extends TestCase
## Pruebas de los créditos: nombran al autor, explican la historia y mandan a las licencias, que
## viajan junto al juego.

const MENU_SCENE := preload("res://src/ui/main_menu/main_menu.tscn")
const AUTHOR := "Mateo Alejandro Merino Vidal"
const LICENSES_PATH := "res://docs/LICENCIAS.txt"
const RELEASE_WORKFLOW := "res://.github/workflows/release.yml"


## El texto de créditos nombra al autor, agradece y apunta al archivo de licencias.
func test_credits_text() -> void:
	var menu := MENU_SCENE.instantiate()
	var text: String = menu.get_node("Ui/Column/CreditsPanel/CreditsScroll/CreditsText").text
	assert_true(text.begins_with("Creado por " + AUTHOR), "Empieza con el autor")
	for part: String in ["Gracias por jugar", "¿Pasó de verdad?", "¿Qué es el Tío?"]:
		assert_true(text.contains(part), "Los créditos dicen: %s" % part)
	assert_true(text.contains("LICENCIAS.txt"), "Mandan a las licencias")
	menu.free()


## Las licencias nombran la voz con Apache 2.0 y se empaquetan con el juego.
func test_licenses_ship_with_game() -> void:
	var licenses := FileAccess.get_file_as_string(LICENSES_PATH)
	assert_true(licenses.contains("Apache 2.0"), "La voz claude lleva su licencia")
	var workflow := FileAccess.get_file_as_string(RELEASE_WORKFLOW)
	assert_true(workflow.contains("docs/LICENCIAS.txt"), "La publicación copia las licencias")
