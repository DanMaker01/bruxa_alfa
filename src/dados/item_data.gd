# item_data.gd
# Um item do jogo (ingrediente, poção...). Um arquivo .tres por item em res://dados/itens/.
class_name ItemData
extends Resource

## Folga padrão dos limites: a queda do aproveitamento vai de x0 até (1 ± h)·x0.
const H_PADRAO: float = 0.25

## Identificador usado no inventário e nos comandos (ex.: "cogumelo_brilhante").
@export var id: String = ""
## Nome mostrado ao jogador.
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var icone: Texture2D

@export_group("Poção")
## Matriz 5x5 (linhas O, C, E, A, N) que o ingrediente aplica na personalidade.
# Passo de 0.0001 no Inspector (o padrão do Godot arredonda para 0.001).
# Hint: "32:3/1:..." = TYPE_PACKED_FLOAT32_ARRAY(32) de TYPE_FLOAT(3) com PROPERTY_HINT_RANGE(1).
# (precisa ser string literal: a anotação não aceita "%" nem concatenação)
@export_custom(PROPERTY_HINT_TYPE_STRING, "32:3/1:-10,10,0.0001,or_less,or_greater")
var A: Array[PackedFloat32Array] = [
	PackedFloat32Array([1, 0, 0, 0, 0]),
	PackedFloat32Array([0, 1, 0, 0, 0]),
	PackedFloat32Array([0, 0, 1, 0, 0]),
	PackedFloat32Array([0, 0, 0, 1, 0]),
	PackedFloat32Array([0, 0, 0, 0, 1]),
]

@export_subgroup("Cozimento (Q = ∫T dt)")
## a_Q = exp(−½·((Q − m)/s)²), com s_menos antes do pico e s_mais depois.
## Q ideal (pico da curva, aproveitamento 1). 0 = sem exigência de cozimento.
@export var m: float = 0.0
## Largura da curva ANTES do pico (cozimento de menos / cru).
@export var s_menos: float = 1000.0
## Largura da curva DEPOIS do pico (cozimento de mais / passou do ponto).
@export var s_mais: float = 1000.0

@export_subgroup("Temperatura (°C)")
## Temperatura mínima. 0 = sem limite.
@export var T_min: float = 0.0
## kmin: folga da queda abaixo de T_min: 0.99 em T_min, 0.01 em (1−k)·T_min (0 = corte duro).
@export var k_min: float = H_PADRAO
## Temperatura máxima. 0 = sem limite.
@export var T_max: float = 0.0
## kmax: folga da queda acima de T_max: 0.99 em T_max, 0.01 em (1+k)·T_max (0 = corte duro).
@export var k_max: float = H_PADRAO

@export_subgroup("Tempo no caldeirão (s)")
## Tempo mínimo. 0 = sem limite.
@export var t_min: float = 0.0
## hmin: folga da queda abaixo de t_min: 0.99 em t_min, 0.01 em (1−h)·t_min (0 = corte duro).
@export var h_min: float = H_PADRAO
## Tempo máximo. 0 = sem limite.
@export var t_max: float = 0.0
## hmax: folga da queda acima de t_max: 0.99 em t_max, 0.01 em (1+h)·t_max (0 = corte duro).
@export var h_max: float = H_PADRAO


func get_nome() -> String:
	return nome if nome != "" else id
