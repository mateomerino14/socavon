class_name ItemCatalog
extends RefCounted
## Catálogo de objetos: tipos, nombres visibles, topes en la bolsa y valor como ofrenda.

enum Type { NONE, CARBIDE, COCA, ALCOHOL, CIGARETTE, STONE }

const NAMES := {
	Type.CARBIDE: "carburo",
	Type.COCA: "hojas de coca",
	Type.ALCOHOL: "alcohol",
	Type.CIGARETTE: "cigarro",
	Type.STONE: "piedra",
}

const MAX_STACK := {
	Type.CARBIDE: 3,
	Type.COCA: 5,
	Type.ALCOHOL: 3,
	Type.CIGARETTE: 5,
	Type.STONE: 5,
}

## Respeto que gana el jugador al ofrendar cada objeto.
const OFFERING_RESPECT := {
	Type.COCA: 10.0,
	Type.CIGARETTE: 8.0,
	Type.ALCOHOL: 15.0,
}

## Orden en que el altar toma las ofrendas: primero la más común.
const OFFERING_ORDER: Array[Type] = [Type.COCA, Type.CIGARETTE, Type.ALCOHOL]


## Devuelve el nombre que ve el jugador.
static func display_name(type: Type) -> String:
	return NAMES.get(type, "")


## Devuelve cuántos objetos de ese tipo caben en la bolsa.
static func max_stack(type: Type) -> int:
	return MAX_STACK.get(type, 0)


## Dice si el objeto sirve como ofrenda al Tío.
static func is_offering(type: Type) -> bool:
	return OFFERING_RESPECT.has(type)
