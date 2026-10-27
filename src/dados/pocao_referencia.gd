# pocao_referencia.gd
# Uma poção com nome conhecido. Poções feitas no caldeirão que ficarem perto desta
# (matriz A parecida, ver CatalogoPocoes) recebem este nome.
class_name PocaoReferencia
extends Resource

@export var nome: String = ""
@export_multiline var descricao: String = ""
## Matriz 5x5 (linhas O, C, E, A, N) de referência.
# Mesmo hint do ItemData.A (passo 0.0001 no Inspector).
@export_custom(PROPERTY_HINT_TYPE_STRING, "32:3/1:-10,10,0.0001,or_less,or_greater")
var A: Array[PackedFloat32Array] = [
	PackedFloat32Array([1, 0, 0, 0, 0]),
	PackedFloat32Array([0, 1, 0, 0, 0]),
	PackedFloat32Array([0, 0, 1, 0, 0]),
	PackedFloat32Array([0, 0, 0, 1, 0]),
	PackedFloat32Array([0, 0, 0, 0, 1]),
]
## Comandos executados quando a poção é usada (ex.: teleporte). Poções feitas no caldeirão
## com este nome recebem este efeito. Vazio = só a matriz.
@export var efeito: Array[Comando] = []
