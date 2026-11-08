class_name InventoryComponent
extends Node
## Bolsa del minero: cuántos objetos de cada tipo lleva, con un tope por tipo.

signal changed(type: ItemCatalog.Type, count: int)

var _counts := {}


## Agrega objetos hasta el tope; devuelve verdadero si entró al menos uno.
func add(type: ItemCatalog.Type, amount := 1) -> bool:
	var space := ItemCatalog.max_stack(type) - count(type)
	var added := mini(amount, space)
	if added <= 0:
		return false
	_counts[type] = count(type) + added
	changed.emit(type, count(type))
	return true


## Quita objetos si hay suficientes; devuelve verdadero si los quitó.
func remove(type: ItemCatalog.Type, amount := 1) -> bool:
	if count(type) < amount:
		return false
	_counts[type] = count(type) - amount
	changed.emit(type, count(type))
	return true


## Devuelve cuántos objetos de ese tipo lleva.
func count(type: ItemCatalog.Type) -> int:
	return _counts.get(type, 0)


## Dice si cabe al menos uno más de ese tipo.
func can_add(type: ItemCatalog.Type) -> bool:
	return count(type) < ItemCatalog.max_stack(type)


## Devuelve la primera ofrenda disponible según el orden del catálogo, o NONE.
func first_offering() -> ItemCatalog.Type:
	for type in ItemCatalog.OFFERING_ORDER:
		if count(type) > 0:
			return type
	return ItemCatalog.Type.NONE
