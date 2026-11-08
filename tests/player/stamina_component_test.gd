extends TestCase
## Pruebas del aliento: gasto al correr, agotamiento y recuperación.

const SECOND := 1.0

var _stamina: StaminaComponent


## Crea un componente nuevo con valores fáciles de calcular.
func before_each() -> void:
	_stamina = StaminaComponent.new()
	_stamina.max_stamina = 100.0
	_stamina.drain_per_second = 20.0
	_stamina.regen_per_second = 10.0
	_stamina.regen_delay = 1.0
	_stamina.recover_threshold = 30.0
	add_to_tree(_stamina)
	_stamina.set_physics_process(false)


## Libera el componente.
func after_each() -> void:
	_stamina.free()


## Correr un segundo gasta lo indicado.
func test_sprinting_drains_stamina() -> void:
	_stamina.set_draining(true)
	_stamina.tick(SECOND)
	assert_almost_eq(_stamina.current, 80.0, "Debe gastar 20 de aliento en un segundo")


## Al agotarse no deja correr hasta recuperar el umbral.
func test_exhaustion_blocks_sprint_until_threshold() -> void:
	_drain_completely()
	assert_true(_stamina.is_exhausted, "Debe quedar agotado al llegar a cero")
	assert_false(_stamina.can_sprint(), "No debe dejar correr agotado")
	_stamina.set_draining(false)
	_stamina.tick(SECOND)
	_stamina.tick(2.0 * SECOND)
	assert_false(_stamina.can_sprint(), "Con 20 de aliento aún no debe dejar correr")
	_stamina.tick(SECOND)
	assert_true(_stamina.can_sprint(), "Con 30 de aliento debe volver a dejar correr")


## La recuperación espera la pausa después de correr.
func test_regeneration_waits_for_delay() -> void:
	_stamina.set_draining(true)
	_stamina.tick(SECOND)
	_stamina.set_draining(false)
	_stamina.tick(0.5 * SECOND)
	assert_almost_eq(_stamina.current, 80.0, "No debe recuperar durante la pausa")
	_stamina.tick(0.5 * SECOND)
	_stamina.tick(SECOND)
	assert_almost_eq(_stamina.current, 90.0, "Tras la pausa debe recuperar 10 por segundo")


## Gasta todo el aliento en pasos de un segundo.
func _drain_completely() -> void:
	for i in 5:
		_stamina.set_draining(true)
		_stamina.tick(SECOND)
