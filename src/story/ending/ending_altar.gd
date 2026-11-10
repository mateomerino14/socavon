class_name EndingAltar
extends Altar
## Altar de la bocamina: el Tío cobra coca, alcohol y cigarro juntos para dejar salir al jugador.

const PAYMENT: Array[ItemCatalog.Type] = [
	ItemCatalog.Type.COCA, ItemCatalog.Type.ALCOHOL, ItemCatalog.Type.CIGARETTE
]
const PAY_PROMPT := "Pagarle al Tío su parte"
const MISSING_PROMPT := "El Tío pide coca, alcohol y cigarro"
const PAID_PROMPT := "Ya le pagaste al Tío"
const PAID_NOTICE := "Pagaste lo que se debía. Partida guardada"
const MISSING_NOTICE := "Te falta: %s"
const LIST_SEPARATOR := ", "
## Respeto que da pagar completo: la deuda queda saldada.
const PAYMENT_RESPECT := 50.0
## El pago se anuncia como la ofrenda mayor, la que calma al Tío.
const MAIN_OFFERING := ItemCatalog.Type.ALCOHOL

## Quién habla cuando el Tío recibe el pago.
@export var voice: VoicePlayer
@export var thanks_lines: Array[VoiceLine] = []


## Dice qué pide el Tío, si ya se puede pagar o si ya se pagó.
func _build_prompt(player: Player) -> String:
	if GameState.has_paid:
		return PAID_PROMPT
	if _missing(player).is_empty():
		return PAY_PROMPT
	return MISSING_PROMPT


## Cobra los tres objetos de una vez, o avisa qué falta.
func _on_interacted(player: Player) -> void:
	if GameState.has_paid:
		return
	var missing := _missing(player)
	if not missing.is_empty():
		EventBus.notice_requested.emit(MISSING_NOTICE % LIST_SEPARATOR.join(missing))
		return
	for item in PAYMENT:
		player.inventory.remove(item)
	GameState.has_paid = true
	GameState.add_respect(PAYMENT_RESPECT)
	GameState.save_checkpoint(get_respawn_transform())
	EventBus.offering_made.emit(global_position, MAIN_OFFERING)
	EventBus.notice_requested.emit(PAID_NOTICE)
	if voice:
		voice.say(thanks_lines)


## Devuelve los nombres de lo que le falta al jugador para pagar.
func _missing(player: Player) -> PackedStringArray:
	var missing := PackedStringArray()
	for item in PAYMENT:
		if player.inventory.count(item) == 0:
			missing.append(ItemCatalog.display_name(item))
	return missing
