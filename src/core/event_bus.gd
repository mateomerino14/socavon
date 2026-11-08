extends Node
## Bus de eventos global (autoload "EventBus").
##
## Conecta sistemas que no deben conocerse entre sí: el jugador emite
## ruido y luz, y la IA del Tío, el HUD y el audio escuchan sin tener
## referencias directas al jugador.
##
## Regla: solo eventos que cruzan sistemas. La comunicación dentro de
## una misma escena usa señales locales.

## Un sonido que el Tío puede oír. [param loudness] va de 0.0 a 1.0.
signal noise_emitted(origin: Vector3, loudness: float)

## La luz que delata al jugador cambió. [param intensity] va de 0.0 a 1.0.
signal player_light_changed(intensity: float)

## La estamina del jugador cambió.
signal stamina_changed(current: float, maximum: float)

## El combustible de la lámpara cambió.
signal lamp_fuel_changed(current: float, maximum: float)

## La lámpara se encendió, apagó o cambió de nivel de llama.
signal lamp_state_changed(is_lit: bool, level: int)

## Cambió lo que el jugador puede usar al frente; texto vacío si no hay nada.
signal interaction_prompt_changed(prompt: String)

## Cambió la cantidad de un objeto en la bolsa del jugador.
signal inventory_changed(type: ItemCatalog.Type, count: int)

## Se dejó una ofrenda en un altar.
signal offering_made(origin: Vector3, type: ItemCatalog.Type)

## Un aviso breve para el jugador, como "Partida guardada".
signal notice_requested(text: String)

## El Tío cambió de estado (patrulla, sospecha, caza, búsqueda o calma).
signal tio_state_changed(state: Tio.State)

## El Tío alcanzó al jugador.
signal player_caught
