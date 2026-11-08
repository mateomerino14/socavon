extends SceneTree
## Ejecuta todas las pruebas de tests/ en modo headless y sale con código 1 si alguna falla.

const TESTS_DIR := "res://tests/"
const TEST_SUFFIX := "_test.gd"
const TEST_PREFIX := "test_"
const EXIT_OK := 0
const EXIT_FAILED := 1


## Arranca la ejecución de las pruebas cuando el árbol está listo.
func _initialize() -> void:
	_run_all.call_deferred()


## Corre cada archivo de prueba y muestra el resumen.
func _run_all() -> void:
	var passed := 0
	var failed := 0
	for path in _find_test_files(TESTS_DIR):
		var results := await _run_file(path)
		passed += results.x
		failed += results.y
	print("\n%d pruebas correctas, %d con fallos" % [passed, failed])
	if failed > 0:
		quit(EXIT_FAILED)
	else:
		quit(EXIT_OK)


## Devuelve las rutas de los archivos de prueba, buscando en subcarpetas.
func _find_test_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for sub_dir in DirAccess.get_directories_at(dir_path):
		files.append_array(_find_test_files(dir_path.path_join(sub_dir)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(TEST_SUFFIX):
			files.append(dir_path.path_join(file))
	return files


## Corre las pruebas de un archivo y devuelve (correctas, con fallos).
func _run_file(path: String) -> Vector2i:
	var results := Vector2i.ZERO
	var script: GDScript = load(path)
	print(path.get_file())
	for method in script.get_script_method_list():
		var name: String = method.name
		if not name.begins_with(TEST_PREFIX):
			continue
		var test_case: TestCase = script.new()
		test_case.tree = self
		test_case.before_each()
		await test_case.call(name)
		test_case.after_each()
		if test_case.failures.is_empty():
			results.x += 1
			print("  ok    ", name)
		else:
			results.y += 1
			print("  FALLA ", name)
			for failure in test_case.failures:
				print("        ", failure)
	return results
