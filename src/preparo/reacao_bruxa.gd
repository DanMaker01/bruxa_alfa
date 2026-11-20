# reacao_bruxa.gd
# Retratinho da Bruxa no canto da cena de preparo, reagindo ao caldeirão:
#   concentrada (normal)  → respira devagar
#   satisfeita (no ponto) → pulinho
#   preocupada (perto de um limite) → inclina e olha de lado
#   assustada (perdendo aproveitamento agora) → treme
# E um balãozinho com uma fala curta quando o humor muda ("Tá queimando!", "Isso!"...).
# Falas em balões soltos: cada uma sobe devagar e some; várias ao mesmo tempo, sem sobrepor.
# (Contagem de itens e instruções do tutorial usam o balão principal, parado.)
# Não decide nada do jogo: a cena chama atualizar() com os estados dos ingredientes.
class_name ReacaoBruxa
extends Node2D

# ---- ajuste aqui ----
const FOTO_PATH := "res://assets/game_caldeirao/bruxa_chibi.png"
## Posição do retrato (mesmas coordenadas do caldeirão, em $Animações).
const POSICAO := Vector2(80, 470)
const ALTURA_FOTO: float = 240.0
const BALAO_OFFSET := Vector2(0, -330)   # canto superior esquerdo do balão de 1 linha, relativo ao retrato
## z dos balões, relativo à bruxinha (z 6): fica 7, acima da receita memorizada (6) e abaixo
## da janela de resultado (8). Relativo de propósito: a CenaPreparo tem z 200 no main.tscn;
## um z absoluto (7) ficava atrás do fundo da cena e o balão sumia.
const Z_BALAO: int = 1
const BALAO_DURACAO: float = 2.2          # s na tela
const INTERVALO_MIN_FALA: float = 2.5     # s entre falas
const SUAVIZACAO: float = 6.0
## Pulos quando todos os itens estão perto do ideal: começam em PULO_INICIO de aproveitamento
## (o pior item) e crescem até 100%: altura de PULO_ALT_MIN a PULO_ALT_MAX (px) e
## frequência de PULO_FREQ_MIN a PULO_FREQ_MAX (pulos/s).
const PULO_INICIO: float = 0.97
const PULO_ALT_MIN: float = 6.0
const PULO_ALT_MAX: float = 34.0
const PULO_FREQ_MIN: float = 1.2
const PULO_FREQ_MAX: float = 2.8
var _pulo_alvo: float = 0.0   # 0..1 conforme o aproveitamento vai de PULO_INICIO a 100%
var _pulo: float = 0.0        # suavizado
var _fase_pulo: float = 0.0

enum Humor { CONCENTRADA, SATISFEITA, PREOCUPADA, ASSUSTADA }

const FALAS := {
	"quente": ["Tá queimando!", "Fogo demais!", "Quente, quente!"],
	"frio": ["Esfriou...", "Mais fogo!", "Brrr, tá frio."],
	"tempo": ["Tempo demais!", "Já devia ter tirado..."],
	"ponto": ["Passou muito do ponto!", "Cozinhou demais..."],
	"perto": ["Cuidado...", "Hmm, quase...", "Atenção!"],
	"perfeito": ["Isso!", "Perfeito!", "No ponto!"],
	"novo": ["Vamos ver...", "Mais um.", "Hmm."],
	"apagando": ["O fogo tá morrendo!", "Vai apagar...", "Cuidado com o fogo!"],
	"esfriando": ["Está esfriando...", "Esfriando...", "O caldo está esfriando."],
}

var _foto: Sprite2D
var _balao: PanelContainer
var _balao_label: Label
var _humor: int = Humor.CONCENTRADA
var _motivo: String = ""
var _t: float = 0.0
var _ultima_fala: float = -100.0
var _balao_ate: float = 0.0
var _fixa: bool = false
const FALA_MIN: float = 1.8       # s mínimos de cada balão
## Pulo de comemoração e o comentário quando todos os itens passam disto.
const A_COMEMORA: float = 0.985
const FALA_COMEMORA := "Ótimo! Só mais um segundo e já pode finalizar."
## Com receita memorizada quem avisa a hora de finalizar é a guia ("Pronto! Pode finalizar."):
## aqui a bruxinha só pula, sem falar (um aviso só).
var com_receita: bool = false
var _comemorou: bool = false   # dizer(..., fixa): o balão fica até calar() e as reações não falam por cima
const LARG_MAX_BALAO: float = 330.0
const FONTE_FALA: int = 28
const FONTE_DIZER: int = 24
## Espaço (px) entre dois balões soltos.
const GAP_PILHA: float = 6.0
const SOBE_SOLTO: float = 40.0     # px/s que o balão solto sobe (os de cima abrem espaço)
var _extras: Array = []            # balões da pilha / soltos: {"no", "ate", "texto"}
# pose suavizada
var _rot: float = 0.0
var _sobe: float = 0.0
var _treme: float = 0.0


func _ready() -> void:
	position = POSICAO
	_foto = Sprite2D.new()
	if ResourceLoader.exists(FOTO_PATH):
		_foto.texture = load(FOTO_PATH)
		_foto.scale = Vector2.ONE * (ALTURA_FOTO / maxf(_foto.texture.get_height(), 1.0))
	_foto.offset = Vector2(0, -(_foto.texture.get_height() * 0.5) if _foto.texture else 0.0)   # pivô no pé
	add_child(_foto)
	_criar_balao()

func _criar_balao() -> void:
	_balao = _painel_balao()
	_balao_label = _balao.get_child(0)
	_balao.position = BALAO_OFFSET
	add_child(_balao)

## Painel de balão vazio (invisível), acima da receita.
func _painel_balao() -> PanelContainer:
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", Estilo.caixa_balao(Estilo.FUNDO_BALAO_CLARO))
	var l := Label.new()
	l.add_theme_font_size_override("font_size", Estilo.FONTE_TEXTO)
	l.add_theme_color_override("font_color", Estilo.TEXTO_ESCURO)
	b.add_child(l)
	b.modulate.a = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.z_index = Z_BALAO
	return b

func resetar() -> void:
	_fixa = false
	_comemorou = false
	_pulo_alvo = 0.0
	_humor = Humor.CONCENTRADA
	_motivo = ""
	_balao_ate = 0.0
	_balao.modulate.a = 0.0
	_limpar_extras()

## Um ingrediente entrou no caldeirão.
## Fala avulsa (ex.: "apagando").
func avisar(motivo: String) -> void:
	_ultima_fala = -100.0   # aviso importante: fala mesmo que tenha falado agora há pouco
	_falar(motivo)

## Segurando um item: a bruxa conta quantos já entraram ("1...", "2...") e, quando
## o último cai depois de soltar o botão, fala o total ("8!!").
func contar(n: int, final: bool = false, nome_item: String = "") -> void:
	if _fixa:
		return
	if final:
		_balao_label.text = ("%d %s!!" % [n, nome_item.to_lower()]) if nome_item != "" else "%d!!" % n
	else:
		_balao_label.text = "%d..." % n
	_ajustar_balao(FONTE_FALA)
	_balao.size = _balao.get_combined_minimum_size()
	_ultima_fala = _t
	_balao_ate = _t + (2.0 if final else 1.2)
	_balao.modulate.a = 1.0
	_balao.pivot_offset = _balao.size * 0.5
	_balao.scale = Vector2(1.2, 1.2)
	_balao.create_tween().tween_property(_balao, "scale", Vector2.ONE, 0.15)

func novo_ingrediente() -> void:
	_falar("novo")

## estados: CalculadoraPocao.estado_ao_vivo() de cada ingrediente.
func atualizar(estados: Array) -> void:
	var motivo := ""
	var humor := Humor.CONCENTRADA
	var todos_no_ponto := not estados.is_empty()
	var perto := false
	var a_min := 1.0 if not estados.is_empty() else 0.0
	for est in estados:
		if est.is_empty():
			todos_no_ponto = false
			a_min = 0.0
			continue
		a_min = minf(a_min, float(est.get("a", 0.0)))
		var niveis: Dictionary = est.get("niveis", {})
		for k in ["quente", "frio", "tempo", "ponto"]:
			if niveis.get(k, 0) == 2 and motivo == "":
				motivo = k
			elif niveis.get(k, 0) == 1:
				perto = true
		if float(est.get("a", 0.0)) < PULO_INICIO:   # começa a pular com 97% (no ponto = 95% é cedo)
			todos_no_ponto = false
	if motivo != "":
		humor = Humor.ASSUSTADA
	elif perto:
		humor = Humor.PREOCUPADA
		motivo = "perto"
	elif todos_no_ponto:
		humor = Humor.SATISFEITA
		motivo = "perfeito"
	_pulo_alvo = clampf((a_min - PULO_INICIO) / (1.0 - PULO_INICIO), 0.0, 1.0) if humor == Humor.SATISFEITA else 0.0
	# comentário de comemoração: uma vez por preparo, com todos a 98,5%
	if humor == Humor.SATISFEITA and a_min >= A_COMEMORA and not _comemorou:
		_comemorou = true
		if not com_receita:
			dizer(FALA_COMEMORA, 3.0)
	if humor != _humor or motivo != _motivo:
		_humor = humor
		_motivo = motivo
		if motivo != "" and motivo != "perfeito":
			_falar(motivo)

## Fala um texto qualquer (tutorial, próximo passo da receita). segundos <= 0 ou fixa:
## fica até calar(). Fixa: as reações automáticas não falam por cima.
func dizer(texto: String, segundos: float = 2.5, fixa: bool = false) -> void:
	if not fixa:
		if not _fixa:
			_soltar(texto, FONTE_DIZER, segundos if segundos > 0.0 else BALAO_DURACAO)
		return
	# instrução fixa (tutorial): balão principal, parado, até calar()
	_limpar_extras()
	_fixa = true
	_balao_label.text = texto
	_ajustar_balao(FONTE_DIZER)
	_ultima_fala = _t
	_balao_ate = 0.0
	_balao.pivot_offset = _balao.size * 0.5
	_balao.scale = Vector2(0.7, 0.7)
	var tw := _balao.create_tween().set_parallel(true)
	tw.tween_property(_balao, "modulate:a", 1.0, 0.15)
	tw.tween_property(_balao, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Avisos que mudam rápido (não falam por cima do tutorial).
func dizer_se_livre(texto: String, segundos: float = 1.8) -> void:
	if not _fixa:
		_soltar(texto, FONTE_DIZER, segundos)

## Tira o balão (e solta o modo fixo).
func calar() -> void:
	_fixa = false
	_balao_ate = 0.0
	_balao.create_tween().tween_property(_balao, "modulate:a", 0.0, 0.2)
	_limpar_extras()

## Texto longo quebra linha (até LARG_MAX_BALAO) e o balão cresce para cima.
func _ajustar_balao(fonte: int) -> void:
	_ajustar(_balao, _balao_label, fonte)
	_balao.position = BALAO_OFFSET - Vector2(0, maxf(0.0, _balao.size.y - _uma_linha(fonte)))

## Quebra o texto (até LARG_MAX_BALAO) e acerta o tamanho do painel.
func _ajustar(b: PanelContainer, l: Label, fonte: int) -> void:
	l.add_theme_font_size_override("font_size", fonte)
	var f: Font = l.get_theme_font("font")
	var larg: float = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fonte).x
	if larg > LARG_MAX_BALAO:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var alt: float = f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, LARG_MAX_BALAO, fonte).y
		l.custom_minimum_size = Vector2(LARG_MAX_BALAO, alt)
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2.ZERO
	b.size = Vector2.ZERO
	b.size = b.get_combined_minimum_size()

func _uma_linha(fonte: int) -> float:
	return _balao_label.get_theme_font("font").get_height(fonte) + 8.0

## Embaixo de onde os balões extras se apoiam: o pé do balão de 1 linha, ou o topo do
## balão principal se ele estiver na tela (contagem, tutorial).
func _base_extras() -> float:
	if _balao.modulate.a > 0.05:
		return _balao.position.y - GAP_PILHA
	return BALAO_OFFSET.y + _uma_linha(FONTE_DIZER)

# ---------------------------------------------------------------- balões soltos
func _soltar(texto: String, fonte: int, segundos: float) -> void:
	for e in _extras:
		if e["texto"] == texto and _t < e["ate"]:
			return   # a mesma fala já está na tela
	var b := _painel_balao()
	var l: Label = b.get_child(0)
	l.text = texto
	add_child(b)
	_ajustar(b, l, fonte)
	var dur: float = maxf(segundos, FALA_MIN)
	_extras.append({"no": b, "ate": _t + dur, "texto": texto})
	_ultima_fala = _t
	b.pivot_offset = Vector2(0, b.size.y)
	b.scale = Vector2(0.7, 0.7)
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "modulate:a", 1.0, 0.15)
	tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.position = Vector2(BALAO_OFFSET.x + randf_range(-8.0, 16.0), _base_extras() - b.size.y)

## Soltos: todos sobem devagar; um balão novo embaixo empurra os de cima (sem sobrepor).
func _mover_soltos(delta: float) -> void:
	var limite := INF
	for k in range(_extras.size() - 1, -1, -1):
		var b: Control = _extras[k]["no"]
		if not is_instance_valid(b):
			continue
		var y: float = b.position.y - SOBE_SOLTO * delta
		var max_y: float = limite - GAP_PILHA - b.size.y
		if y > max_y:
			y = lerpf(b.position.y, max_y, clampf(delta * 14.0, 0.0, 1.0))
		b.position.y = y
		limite = b.position.y

func _tirar_extra(k: int) -> void:
	var b: Control = _extras[k]["no"]
	_extras.remove_at(k)
	if is_instance_valid(b):
		var tw := b.create_tween()
		tw.tween_property(b, "modulate:a", 0.0, 0.3)
		tw.tween_callback(b.queue_free)

func _limpar_extras() -> void:
	while not _extras.is_empty():
		_tirar_extra(0)

func _falar(motivo: String) -> void:
	if _fixa:
		return
	if _t - _ultima_fala < INTERVALO_MIN_FALA or not FALAS.has(motivo):
		return
	var opcoes: Array = FALAS[motivo]
	_soltar(opcoes[randi() % opcoes.size()], FONTE_FALA, BALAO_DURACAO)

func _process(delta: float) -> void:
	_t += delta
	# balões soltos: cada um some no seu tempo; os outros sobem
	for k in range(_extras.size() - 1, -1, -1):
		if _t >= _extras[k]["ate"]:
			_tirar_extra(k)
	_mover_soltos(delta)
	# pose alvo por humor
	var rot_alvo := 0.0
	var sobe_alvo := sin(_t * 1.6) * 2.0          # respirando
	var treme_alvo := 0.0
	match _humor:
		Humor.SATISFEITA:
			sobe_alvo = 0.0   # os pulos vêm de _pulo (abaixo)
		Humor.PREOCUPADA:
			rot_alvo = -0.08 + 0.03 * sin(_t * 2.0)    # inclina e olha de lado
		Humor.ASSUSTADA:
			treme_alvo = 1.0
			rot_alvo = 0.05 * sin(_t * 9.0)
	var k := clampf(delta * SUAVIZACAO, 0.0, 1.0)
	_rot = lerpf(_rot, rot_alvo, k)
	_sobe = lerpf(_sobe, sobe_alvo, k)
	_treme = lerpf(_treme, treme_alvo, k)
	var tremor := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * _treme
	# pulos: mais altos e mais rápidos quanto mais perto de 100%
	_pulo = lerpf(_pulo, _pulo_alvo, clampf(delta * 3.0, 0.0, 1.0))
	_fase_pulo += delta * lerpf(PULO_FREQ_MIN, PULO_FREQ_MAX, _pulo) * PI
	var pulo: float = 0.0
	if _pulo > 0.01:
		pulo = -absf(sin(_fase_pulo)) * lerpf(PULO_ALT_MIN, PULO_ALT_MAX, _pulo) * minf(_pulo * 4.0, 1.0)
	_foto.position = Vector2(0, _sobe + pulo) + tremor
	_foto.rotation = _rot
	# balão some sozinho
	if _balao_ate > 0.0 and _t > _balao_ate:
		_balao_ate = 0.0
		_balao.create_tween().tween_property(_balao, "modulate:a", 0.0, 0.3)
