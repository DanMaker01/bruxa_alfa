# variavel_data.gd
# Declaração de uma variável do jogo e seu valor inicial.
class_name VariavelData
extends Resource

# Toda variável é número (float). Para sim/não use 0 e 1.

@export var nome: String = ""
@export var valor_numero: float = 0.0


func valor_inicial() -> float:
	return valor_numero
