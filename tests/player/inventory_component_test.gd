extends TestCase
## Pruebas de la bolsa: topes por tipo, quitar objetos y orden de las ofrendas.

var _inventory: InventoryComponent


## Crea una bolsa vacía.
func before_each() -> void:
	_inventory = InventoryComponent.new()


## Libera la bolsa.
func after_each() -> void:
	_inventory.free()


## No deja pasar del tope del tipo.
func test_add_respects_max_stack() -> void:
	var max_carbide := ItemCatalog.max_stack(ItemCatalog.Type.CARBIDE)
	assert_true(
		_inventory.add(ItemCatalog.Type.CARBIDE, max_carbide + 2), "Debe agregar hasta el tope"
	)
	assert_true(
		_inventory.count(ItemCatalog.Type.CARBIDE) == max_carbide, "Debe quedar justo en el tope"
	)
	assert_false(_inventory.add(ItemCatalog.Type.CARBIDE), "No debe agregar con la bolsa llena")
	assert_false(_inventory.can_add(ItemCatalog.Type.CARBIDE), "No debe decir que cabe más")


## Quitar más de lo que hay no cambia nada.
func test_remove_fails_without_enough_items() -> void:
	_inventory.add(ItemCatalog.Type.STONE, 2)
	assert_false(_inventory.remove(ItemCatalog.Type.STONE, 3), "No debe quitar 3 si hay 2")
	assert_true(_inventory.count(ItemCatalog.Type.STONE) == 2, "Debe seguir con 2 piedras")
	assert_true(_inventory.remove(ItemCatalog.Type.STONE, 2), "Debe quitar las 2 piedras")
	assert_true(_inventory.count(ItemCatalog.Type.STONE) == 0, "Debe quedar sin piedras")


## La primera ofrenda sigue el orden del catálogo y no incluye objetos que no son ofrenda.
func test_first_offering_follows_catalog_order() -> void:
	_inventory.add(ItemCatalog.Type.STONE)
	assert_true(
		_inventory.first_offering() == ItemCatalog.Type.NONE, "Una piedra no es una ofrenda"
	)
	_inventory.add(ItemCatalog.Type.ALCOHOL)
	_inventory.add(ItemCatalog.Type.COCA)
	assert_true(
		_inventory.first_offering() == ItemCatalog.Type.COCA, "La coca va antes que el alcohol"
	)
