class_name HintCatalog
extends RefCounted
## Textos de los consejos de controles, con las acciones entre llaves para InputDevice.

const TEXTS: Dictionary[String, String] = {
	"caminar":
	(
		"{move_forward|move_left|move_back|move_right} para caminar  ·  "
		+ "{look_left|look_right|look_up|look_down} para mirar"
	),
	"lampara": "{lamp_toggle} enciende o apaga la lámpara. A oscuras el Tío casi no te ve",
	"llama":
	(
		"{lamp_increase|lamp_decrease} sube o baja la llama: con más luz ves más lejos, "
		+ "pero el Tío también te ve de más lejos"
	),
	"correr":
	"{sprint} para correr, aunque gasta aliento  ·  {crouch} para agacharte y pisar sin ruido",
	"usar": "{interact} para recoger, leer, ofrendar o esconderte",
	"inventario": "{inventory} abre el inventario",
	"carburo": "{lamp_refill} recarga la lámpara con carburo",
	"piedra": "{throw} lanza una piedra: el ruido aleja al Tío",
	"mapa": "{map} abre el mapa que Mateo dibuja mientras explora",
	"escuchar": "Mantén {listen} sin moverte para escuchar mejor lo que se mueve en la mina",
	"asomarse": "{lean_left} y {lean_right} para asomarte por las esquinas sin salir",
	"altar": "En los altares le pides permiso al Tío: se guarda la partida y sube su respeto",
	"escondite":
	"Si el Tío te caza, escóndete en un nicho o un carro con la lámpara apagada: a oscuras no te ve",
	"caza": "¡Te vio! Corre con {sprint} hasta perderlo de vista, o escóndete",
	"gatear": "Agachado con {crouch} pasas por el gateadero; el Tío no cabe",
}


## Texto de un consejo con las teclas o botones del aparato actual; vacío si no existe.
static func text(id: String) -> String:
	if not TEXTS.has(id):
		return ""
	return InputDevice.fill(TEXTS[id])
