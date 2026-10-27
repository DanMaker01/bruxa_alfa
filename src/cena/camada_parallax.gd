# camada_parallax.gd
# Uma camada de parallax "estilo RPG Maker", em cima do Parallax2D do Godot 4:
#   textura      imagem da camada (vira um Sprite2D filho; deixe vazio para usar filhos próprios)
#   fator        quanto acompanha a câmera: 0 = parada no céu, 1 = anda com o mapa,
#                >1 = mais perto que o mapa (primeiro plano)
#   loop_x       repete na horizontal sem fim (nunca aparece a borda da imagem)
#   pan          velocidade própria em px/s (nuvens, névoa); negativo = para a esquerda
#   deslocamento posição da imagem dentro da camada
#   Na borda do mapa ela continua andando sozinha (mapa_base.gd, seção PARALLAX NA BORDA).
@tool
class_name CamadaParallax
extends Parallax2D

@export var textura: Texture2D:
	set(v):
		textura = v
		_montar()
@export var fator: float = 1.0:
	set(v):
		fator = v
		_montar()
@export var loop_x: bool = true:
	set(v):
		loop_x = v
		_montar()
@export var pan: float = 0.0:
	set(v):
		pan = v
		_montar()
@export var deslocamento: Vector2 = Vector2.ZERO:
	set(v):
		deslocamento = v
		_montar()

var _sprite: Sprite2D

func _ready() -> void:
	_montar()

func _montar() -> void:
	if not is_inside_tree():
		return
	scroll_scale = Vector2(fator, 0.0)
	autoscroll = Vector2(pan, 0.0)
	if textura:
		if _sprite == null or not is_instance_valid(_sprite):
			_sprite = Sprite2D.new()
			_sprite.name = "Imagem"
			_sprite.centered = false
			add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
		_sprite.texture = textura
		_sprite.position = deslocamento
	if loop_x and textura:
		repeat_size = Vector2(textura.get_width(), 0.0)
		repeat_times = 3   # cópias suficientes para cobrir a tela em qualquer posição
	else:
		repeat_size = Vector2.ZERO
