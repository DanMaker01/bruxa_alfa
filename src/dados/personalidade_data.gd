# personalidade_data.gd
# Personalidade inicial de um personagem (modelo OCEAN).
class_name PersonalidadeData
extends Resource

## Identificador usado nos comandos (ex.: "bruxa", "guarda").
@export var id: String = ""
@export_range(-10.0, 10.0, 0.1) var abertura: float = 0.0
@export_range(-10.0, 10.0, 0.1) var consciencia: float = 0.0
@export_range(-10.0, 10.0, 0.1) var extroversao: float = 0.0
@export_range(-10.0, 10.0, 0.1) var amabilidade: float = 0.0
@export_range(-10.0, 10.0, 0.1) var neuroticismo: float = 0.0


## Vetor na ordem O, C, E, A, N (formato usado pelo GameTemp).
func como_array() -> Array:
	return [abertura, consciencia, extroversao, amabilidade, neuroticismo]
