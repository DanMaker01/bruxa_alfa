# receita_ingrediente.gd
# Uma linha de receita: qual item, quantos e uma nota curta (quando/como entra).
class_name ReceitaIngrediente
extends Resource

@export var item: ItemData
@export var quantidade: int = 1
## Ex.: "infusão 75–95 °C", "por último".
@export var nota: String = ""
