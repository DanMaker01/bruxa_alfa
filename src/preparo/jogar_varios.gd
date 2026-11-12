# jogar_varios.gd
# Jeitos de jogar ingredientes no caldeirão (um botão no preparo alterna; fica em JogarVarios.modo):
#   TOQUE       cada toque joga 1 (como antes)
#   ACELERA     toque joga 1; segurando joga um atrás do outro (a cada INTERVALO_INI s)
#               e a bruxa vai contando quantos entraram no caldeirão
#   QUANTIDADE  toque joga 1; segurando um contador sobe (×2, ×3...) e ao soltar joga todos
# Segurar só começa depois de ESPERA s e é cancelado se o dedo arrastar (a lista rola).
class_name JogarVarios
extends Node

enum Modo { TOQUE, ACELERA, QUANTIDADE }
const NOMES := ["Jogar: toque", "Jogar: segurar acelera", "Jogar: segurar conta"]
const ESPERA: float = 0.35             # s segurando até começar
const INTERVALO_INI: float = 0.32      # segurando: um item a cada 0,32 s (velocidade constante)
const INTERVALO_MIN: float = 0.32
const ACELERACAO: float = 1.0          # 1 = sem aceleração
const INTERVALO_LOTE: float = 0.12     # QUANTIDADE: espaço entre os itens jogados
const LIMIAR_ARRASTE: float = 12.0

static var modo: int = Modo.ACELERA   # escolhido: segurar acelera

var cena = null
var _id: String = ""
var _btn: Control = null
var _origem := Vector2.ZERO
var _inicio := Vector2.ZERO
var _t: float = 0.0
var _prox: float = 0.0
var _intervalo: float = INTERVALO_INI
var _segurando: bool = false
var _usou_segurar: bool = false   # o "pressed" do botão não joga mais 1
var _conta: int = 0
var _contador: Label
# contagem da bruxa (segurando): itens jogados que ainda vão cair e quantos já entraram
var _contar_id: String = ""
var _em_voo: int = 0
var _contados: int = 0
var _usou_antes: bool = false


func _ready() -> void:
	if cena.get("lancador"):
		cena.lancador.caiu.connect(_caiu)
	_contador = Label.new()
	_contador.add_theme_font_size_override("font_size", 34)
	_contador.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_contador.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_contador.add_theme_constant_override("outline_size", 8)
	_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contador.z_index = 50
	_contador.visible = false
	cena.add_child.call_deferred(_contador)

static func proximo_modo() -> void:
	modo = (modo + 1) % NOMES.size()

static func nome_modo() -> String:
	return NOMES[modo]

## Liga um botão de ingrediente (substitui o pressed direto).
func ligar(btn: BaseButton, id: String) -> void:
	btn.button_down.connect(_down.bind(btn, id))
	btn.pressed.connect(_pressed.bind(btn, id))

func _down(btn: Control, id: String) -> void:
	_id = id
	_btn = btn
	_origem = btn.global_position + btn.size * 0.5
	_inicio = btn.get_global_mouse_position()
	_t = 0.0
	_intervalo = INTERVALO_INI
	_prox = ESPERA
	_conta = 0
	_usou_segurar = false
	_usou_antes = false   # segurar de novo: a contagem recomeça
	_segurando = modo != Modo.TOQUE

func _pressed(btn: Control, id: String) -> void:
	if _usou_segurar:
		_usou_segurar = false
		if modo == Modo.QUANTIDADE and _segurando:
			_soltar_lote()
		return
	_segurando = false
	cena._on_item_selecionado(id, btn)

func _process(delta: float) -> void:
	if not _segurando:
		return
	var ainda := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not ainda:
		# soltou (talvez fora do botão: o pressed não vem)
		if modo == Modo.QUANTIDADE and _conta > 0:
			_soltar_lote()
		_segurando = false
		return
	var pos: Vector2 = cena.get_global_mouse_position()
	if not _usou_segurar and pos.distance_to(_inicio) > LIMIAR_ARRASTE:
		_segurando = false   # arrastou: é rolagem da lista
		return
	_t += delta
	if _t < _prox:
		return
	_usou_segurar = true
	_prox = _t + _intervalo
	_intervalo = maxf(INTERVALO_MIN, _intervalo * ACELERACAO)
	match modo:
		Modo.ACELERA:
			if _tem():
				if _contar_id != _id or _em_voo == 0 and not _usou_antes:
					_contar_id = _id
					_contados = 0
					_em_voo = 0
				_usou_antes = true
				_em_voo += 1
				cena._on_item_selecionado(_id, null, _origem)
		Modo.QUANTIDADE:
			var max_q: int = _quantidade()
			if _conta < max_q:
				_conta += 1
				_mostrar_contador()

## Um item caiu no caldeirão: se foi jogado segurando, a bruxa conta em voz alta.
func _caiu(id: String) -> void:
	if id != _contar_id or _em_voo <= 0:
		return
	_em_voo -= 1
	_contados += 1
	if cena.get("reacao") and cena.reacao.has_method("contar"):
		cena.reacao.contar(_contados)

func _tem() -> bool:
	return cena.game_temp != null and cena.game_temp.has_item(_id)

func _quantidade() -> int:
	if cena.game_temp == null:
		return 0
	return int(cena.game_temp.get_inventory().get(_id, 0))

func _mostrar_contador() -> void:
	_contador.text = "×%d" % _conta
	_contador.size = Vector2(120, 48)
	_contador.global_position = _origem - Vector2(60, 110)
	_contador.visible = true
	_contador.pivot_offset = _contador.size * 0.5
	_contador.scale = Vector2(1.3, 1.3)
	_contador.create_tween().tween_property(_contador, "scale", Vector2.ONE, 0.15)

func _soltar_lote() -> void:
	var n := _conta
	var id := _id
	var origem := _origem
	_conta = 0
	_segurando = false
	_contador.visible = false
	for k in n:
		if not is_instance_valid(cena) or cena.game_temp == null or not cena.game_temp.has_item(id):
			break
		cena._on_item_selecionado(id, null, origem)
		await get_tree().create_timer(INTERVALO_LOTE).timeout
