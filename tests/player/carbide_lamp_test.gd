extends TestCase
## Pruebas de la lámpara: gasto por nivel, apagado sin carburo y límites de la llama.

const LAMP_SCENE := preload("res://src/player/components/carbide_lamp.tscn")
const SECOND := 1.0

var _lamp: CarbideLamp


## Crea una lámpara con 10 segundos de carburo.
func before_each() -> void:
	_lamp = LAMP_SCENE.instantiate()
	_lamp.max_fuel = 10.0
	_lamp.starting_fuel = 10.0
	add_to_tree(_lamp)
	_lamp.set_process(false)


## Libera la lámpara.
func after_each() -> void:
	_lamp.free()


## La llama alta gasta más que la media.
func test_fuel_rate_depends_on_level() -> void:
	_lamp.consume_fuel(SECOND)
	assert_almost_eq(_lamp.fuel, 9.0, "La llama media debe gastar 1 por segundo")
	_lamp.increase_level()
	_lamp.consume_fuel(SECOND)
	assert_almost_eq(_lamp.fuel, 7.2, "La llama alta debe gastar 1.8 por segundo")


## Sin carburo se apaga y no se puede volver a encender.
func test_turns_off_when_empty() -> void:
	_lamp.consume_fuel(20.0 * SECOND)
	assert_false(_lamp.is_lit, "Debe apagarse al quedarse sin carburo")
	_lamp.toggle()
	assert_false(_lamp.is_lit, "No debe encender sin carburo")
	_lamp.add_fuel(5.0)
	_lamp.toggle()
	assert_true(_lamp.is_lit, "Debe encender tras recargar")


## La llama no pasa de los niveles mínimo y máximo.
func test_level_is_clamped() -> void:
	for i in 5:
		_lamp.increase_level()
	assert_true(_lamp.level == CarbideLamp.MAX_LEVEL, "No debe pasar del nivel máximo")
	for i in 5:
		_lamp.decrease_level()
	assert_true(_lamp.level == CarbideLamp.MIN_LEVEL, "No debe bajar del nivel mínimo")


## Apagada no delata al jugador.
func test_light_intensity_is_zero_when_off() -> void:
	_lamp.toggle()
	assert_almost_eq(_lamp.get_light_intensity(), 0.0, "Apagada debe delatar 0")
	_lamp.toggle()
	assert_true(_lamp.get_light_intensity() > 0.0, "Encendida debe delatar algo")
