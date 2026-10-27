# variavel_data.gd
# Declaração de uma variável do jogo e seu valor inicial.
class_name VariavelData
extends Resource

# Toda variável é número (float). Para sim/não use 0 e 1.

## Nome usado nas condições e no "mudar variável" (de preferência igual ao nome do arquivo).
@export var nome: String = ""
@export var valor_numero: float = 0.0
## Para que serve (só para você lembrar).
@export_multiline var descricao: String = ""


func valor_inicial() -> float:
	return valor_numero
