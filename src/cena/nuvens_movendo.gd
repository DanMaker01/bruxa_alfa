# nuvens_movendo.gd
# Coloque num TextureRect com a textura em modo "Tile" (stretch_mode = Tile).
# Ele desliza sem parar e, a cada largura da textura, volta para o início
# (como a textura repete, o pulo não aparece). Ganha uma largura de textura
# a mais para nunca abrir buraco na ponta.
extends TextureRect

## px/s (negativo = vai para a esquerda).
@export var velocidade: float = -12.0

var _x_base: float = 0.0
var _deslocamento: float = 0.0
var _largura_tex: float = 0.0

func _ready() -> void:
	if texture == null:
		set_process(false)
		return
	_largura_tex = texture.get_width()
	_x_base = position.x - _largura_tex   # começa uma textura para a esquerda
	position.x = _x_base
	size.x += _largura_tex * 2.0          # sobra dos dois lados

func _process(delta: float) -> void:
	_deslocamento = fposmod(_deslocamento + velocidade * delta, _largura_tex)
	position.x = _x_base + _deslocamento
