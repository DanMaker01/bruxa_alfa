# banco_dados.gd
# Lista central dos dados globais do jogo (res://dados/banco.tres).
# Os eventos NÃO ficam aqui: cada nó de evento no mapa aponta para o seu EventoData.
class_name BancoDados
extends Resource

@export var itens: Array[ItemData] = []
@export var personalidades: Array[PersonalidadeData] = []
@export var variaveis: Array[VariavelData] = []
