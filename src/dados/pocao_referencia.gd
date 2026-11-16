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
## Comandos executados quando a poção é usada (ex.: teleporte). Qualquer poção cuja matriz
## fique perto de A recebe este nome e, se houver, este efeito (com o aproveitamento mínimo
## abaixo). Vazio = só a matriz.
@export var efeito: Array[Comando] = []
## Tolerância própria: distância máxima (Frobenius) da matriz para ser esta poção.
## 0 = usa a do catálogo (catalogo_pocoes.tres). Menor = mais exigente (ex.: Retorno 0,02,
## para 2 ou 4 pós não passarem por 3).
@export_range(0.0, 1.0, 0.001) var distancia_max: float = 0.0
## Aproveitamento médio mínimo (0..1) para a poção receber o efeito (além da matriz perto).
## 0 = só a matriz decide. 0.95 = só concentrada.
@export_range(0.0, 1.0, 0.01) var aproveitamento_min_efeito: float = 0.0
