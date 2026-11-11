# receita_data.gd
# Uma receita conhecida (base para o livro de receitas). Um .tres por receita em res://dados/receitas/.
class_name ReceitaData
extends Resource

## Nome da receita mostrado no livro.
@export var nome: String = ""
## Poção que ela produz (um .tres de res://dados/pocoes/).
@export var pocao: PocaoReferencia
@export_multiline var descricao: String = ""
@export var ingredientes: Array[ReceitaIngrediente] = []
## Passo a passo (um item por passo).
@export var passos: PackedStringArray = PackedStringArray()
## Duração aproximada (s), do primeiro ingrediente até terminar.
@export var duracao: float = 0.0
## Passos para o livro de receitas (ver LivroReceitas): {"tipo": "chama", "estado": "normal"}
## ou {"tipo": "ingrediente", "item": "erva", "qtd": 8, "seg": 40.0}. "Finalizar" fica implícito no fim.
@export var passos_livro: Array[Dictionary] = []
## A bruxa já conhece (aparece no livro).
@export var conhecida: bool = false
