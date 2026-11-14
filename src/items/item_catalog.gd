class_name ItemCatalog
extends RefCounted
## Catálogo de objetos: tipos, nombres visibles, topes en la bolsa, valor como ofrenda y lo que el
## inventario cuenta de cada uno.

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

## Orden en que el inventario muestra los objetos.
const DISPLAY_ORDER: Array[Type] = [
	Type.CARBIDE, Type.COCA, Type.ALCOHOL, Type.CIGARETTE, Type.STONE
]

## Qué es cada objeto, como lo contaría un minero.
const DESCRIPTIONS := {
	Type.CARBIDE: "Piedras de carburo. Con un poco de agua sueltan el gas que arde en la lámpara.",
	Type.COCA:
	"Hojas de coca. Los mineros las pijchan para aguantar la jornada y se las ofrecen al Tío.",
	Type.ALCOHOL: "Alcohol puro de caña, el de la ch'alla. Es lo que más le gusta al Tío.",
	Type.CIGARETTE: "Cigarros sin filtro. En los altares el Tío siempre tiene uno encendido.",
	Type.STONE: "Una piedra suelta del socavón.",
}

## Para qué sirve cada objeto.
const USES := {
	Type.CARBIDE: "[R] Recarga la lámpara.",
	Type.COCA: "Ofrécela en un altar: el Tío te respeta un poco más.",
	Type.ALCOHOL: "Ofrécelo en un altar: es la ofrenda que más respeto te da.",
	Type.CIGARETTE: "Ofrécelo en un altar: el Tío te respeta un poco más.",
	Type.STONE: "[Clic izquierdo] Lánzala: el golpe hace ruido y el Tío va a buscarlo.",
}

## Dibujo de cada objeto para el inventario.
const ICONS := {
	Type.CARBIDE: preload("res://assets/ui/items/carbide.png"),
	Type.COCA: preload("res://assets/ui/items/coca.png"),
	Type.ALCOHOL: preload("res://assets/ui/items/alcohol.png"),
	Type.CIGARETTE: preload("res://assets/ui/items/cigarette.png"),
	Type.STONE: preload("res://assets/ui/items/stone.png"),
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


## Devuelve qué es el objeto.
static func description(type: Type) -> String:
	return DESCRIPTIONS.get(type, "")


## Devuelve para qué sirve el objeto.
static func use(type: Type) -> String:
	return USES.get(type, "")


## Devuelve el dibujo del objeto.
static func icon(type: Type) -> Texture2D:
	return ICONS.get(type)
