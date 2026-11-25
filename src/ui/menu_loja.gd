# menu_loja.gd
# Menu de troca com um mercador (CmdLoja). Dois inventários (bruxa e mercador) e uma mesa:
# tocar num item leva 1 para a mesa; tocar nele na mesa devolve. O ouro é um campo separado
# (− / +): positivo = a bruxa paga, negativo = o mercador paga.
# Valor para o mercador: valor(item, qtd que ele tem) (ver CmdLoja).
# A mesa é uma balança: os pratos pendem para o lado que vale mais (valor real, sem números).
# Pechincha: Propor; se ele não aceitar (quer receber >= (1 + margem) · o que dá), pede mais
# ouro (Aceitar / Ajustar). Depois de RODADAS_MAX recusas ele desiste por hoje.
class_name MenuLoja
extends Control

signal fechou(trocas: int)

const Z_MENU: int = 200
const RODADAS_MAX: int = 3
## Fundo: preto com um pouco de alfa (o mundo some, como num fade).
const COR_FUNDO := Color(0, 0, 0, 0.88)

# ---- dados (o CmdLoja lê estoque e ouro_mercador no fim) ----
var estoque: Dictionary = {}
var ouro_mercador: int = 0
var _gt
var _db
var _personagem: Personagem
var _margem: float = 0.2
var _var_ouro: String = "ouro"
var _mesa_bruxa: Dictionary = {}   # id -> qtd que a bruxa dá
var _mesa_merc: Dictionary = {}    # id -> qtd que o mercador dá
var _ouro_mesa: int = 0
var _trocas: int = 0
var _rodadas: int = 0
var _pede_ouro: int = 0            # pechincha: ouro a mais que ele pediu (0 = nenhuma contraproposta)
var _desistiu: bool = false
var _fala_merc: String = ""
var _fala_bruxa: String = ""
var _hud_antes: bool = true
var _fechando: bool = false

# ---- nós da tela atual ----
var _raiz: Control
var _lbl_merc: Label
var _lbl_bruxa: Label
var _lbl_ouro: Label
var _btn_propor: Button
var _btn_aceitar: Button
var _btn_ajustar: Button
var _balanca: Balanca


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = Z_MENU
	mouse_filter = Control.MOUSE_FILTER_STOP
	# o resto do jogo para enquanto a loja está aberta (o menu continua rodando)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(UiModal.GRUPO)

func abrir(p: Dictionary) -> void:
	if not is_node_ready():
		await ready
	_gt = p["gt"]
	_db = p["db"]
	_personagem = p.get("personagem")
	estoque = p.get("estoque", {})
	ouro_mercador = int(p.get("ouro_mercador", 0))
	_margem = float(p.get("margem", 0.2))
	_var_ouro = str(p.get("var_ouro", "ouro"))
	_fala_merc = "Pode olhar. Tenho de tudo um pouco."
	_fala_bruxa = ""
	Balanca.ang_atual = 0.0
	_pausar(true)
	_montar()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)

func _sair() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	_fechando = true
	_pausar(false)
	fechou.emit(_trocas)
	queue_free()

## Como o caldeirão: pausa o jogo (limpando o input) e esconde o HUD; ao fechar, volta.
func _pausar(sim: bool) -> void:
	var gm = get_node_or_null("/root/Main/GameManager")
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if sim:
		if hud and hud.has_method("set_ativo"):
			_hud_antes = hud.carta_inventario.ativa
			hud.set_ativo(false)
		if gm and gm.has_method("_pause_game_with_reset"):
			gm._pause_game_with_reset()
		else:
			get_tree().paused = true
	else:
		if gm and gm.has_method("_unpause_game_with_reset"):
			gm._unpause_game_with_reset()
		else:
			get_tree().paused = false
		if hud and hud.has_method("set_ativo"):
			hud.set_ativo(_hud_antes)

## Algo de fora (ex.: fechar o menu de debug) pode tirar a pausa: a loja segura.
func _process(_delta: float) -> void:
	if not _fechando and not get_tree().paused:
		get_tree().paused = true

# =============================================================================
# VALOR
# =============================================================================
## Valor (ouro) de 1 item para um mercador que tem q_merc dele.
static func valor(item: ItemData, q_merc: int) -> float:
	if item == null:
		return 0.0
	var qb := maxf(item.qtd_base, 0.01)
	return item.valor_base * qb / (qb + maxf(q_merc, 0))

func _item(id: String) -> ItemData:
	return _db.get_item(id) if _db else null

func _valor(id: String) -> float:
	return valor(_item(id), int(estoque.get(id, 0)))

func _ouro_bruxa() -> int:
	var v = _gt.get_var(_var_ouro) if _gt.has_var(_var_ouro) else 0
	return int(v) if v != null else 0

## O mesmo item dos dois lados se cancela: só conta a diferença (trocar 20 ervas por 20
## ervas não vale nada, então não há margem sobre isso).
func _liquido(id: String) -> int:
	return int(_mesa_bruxa.get(id, 0)) - int(_mesa_merc.get(id, 0))

func _ids_mesa() -> Array:
	var ids := _mesa_bruxa.keys()
	for id in _mesa_merc:
		if not ids.has(id):
			ids.append(id)
	return ids

func _recebe() -> float:
	var t := 0.0
	for id in _ids_mesa():
		t += _valor(id) * maxi(_liquido(id), 0)
	return t + maxi(_ouro_mesa, 0)

func _da() -> float:
	var t := 0.0
	for id in _ids_mesa():
		t += _valor(id) * maxi(-_liquido(id), 0)
	return t + maxi(-_ouro_mesa, 0)

## Os mesmos itens e quantidades dos dois lados, sem ouro: não há troca.
func _troca_igual() -> bool:
	return not _mesa_vazia() and _ouro_mesa == 0 and _recebe() <= 0.0 and _da() <= 0.0

func _mesa_vazia() -> bool:
	return _mesa_bruxa.is_empty() and _mesa_merc.is_empty() and _ouro_mesa == 0

## Quanto ele está satisfeito: >= 1 aceita.
func _razao() -> float:
	var precisa := (1.0 + _margem) * _da()
	if precisa <= 0.0:
		return 99.0 if _recebe() > 0.0 else 0.0   # ele não dá nada e recebe algo: aceita
	return _recebe() / precisa

func _aceitavel() -> bool:
	return not _mesa_vazia() and _razao() >= 1.0

## Ouro que falta para ele aceitar.
func _falta_ouro() -> int:
	return maxi(ceili((1.0 + _margem) * _da() - _recebe()), 0)

# =============================================================================
# AÇÕES
# =============================================================================
func _mover(id: String, de_bruxa: bool, para_mesa: bool) -> void:
	var mesa: Dictionary = _mesa_bruxa if de_bruxa else _mesa_merc
	if para_mesa:
		var tem: int = _gt.get_item_quantity(id) if de_bruxa else int(estoque.get(id, 0))
		if int(mesa.get(id, 0)) >= tem:
			return
		mesa[id] = int(mesa.get(id, 0)) + 1
	else:
		mesa[id] = int(mesa.get(id, 0)) - 1
		if mesa[id] <= 0:
			mesa.erase(id)
	_mudou()

func _mudar_ouro(d: int) -> void:
	_ouro_mesa = clampi(_ouro_mesa + d, -ouro_mercador, _ouro_bruxa())
	_mudou()

func _mudou() -> void:
	_pede_ouro = 0
	_montar()

func _propor() -> void:
	if _mesa_vazia() or _desistiu:
		return
	if _troca_igual():
		_fala_merc = "Mas isso é a mesma coisa, senhora."
		_fala_bruxa = ""
		_montar()
		return
	if _aceitavel():
		_fechar_troca()
		return
	_rodadas += 1
	if _rodadas >= RODADAS_MAX:
		_desistiu = true
		_fala_merc = "Chega. Hoje não negocio mais com a senhora."
		_fala_bruxa = "Mão de vaca."
	else:
		_pede_ouro = _falta_ouro()
		_fala_merc = "Por mais %d de ouro, fechamos." % _pede_ouro
		_fala_bruxa = "Hmm..." if _pede_ouro <= _ouro_bruxa() - maxi(_ouro_mesa, 0) else "Não tenho tudo isso."
	_montar()

func _aceitar_contraproposta() -> void:
	if _pede_ouro <= 0:
		return
	var novo := _ouro_mesa + _pede_ouro
	if novo > _ouro_bruxa():
		_fala_bruxa = "Não tenho tudo isso."
		_montar()
		return
	_ouro_mesa = novo
	_pede_ouro = 0
	if _aceitavel():
		_fechar_troca()
	else:
		_montar()

func _ajustar() -> void:
	_pede_ouro = 0
	_fala_bruxa = "Deixe-me pensar."
	_montar()

func _fechar_troca() -> void:
	var pocao_dada := false
	for id in _mesa_bruxa:
		var q: int = _mesa_bruxa[id]
		_gt.remove_item(id, q)
		estoque[id] = int(estoque.get(id, 0)) + q
		var it := _item(id)
		if it and it.id.begins_with("pocao"):
			pocao_dada = true
	for id in _mesa_merc:
		var q: int = _mesa_merc[id]
		_gt.add_item(id, q)
		estoque[id] = int(estoque.get(id, 0)) - q
		if estoque[id] <= 0:
			estoque.erase(id)
	if _ouro_mesa != 0:
		_gt.set_var(_var_ouro, float(_ouro_bruxa() - _ouro_mesa))
		ouro_mercador += _ouro_mesa
	var r := _razao()
	_mesa_bruxa.clear()
	_mesa_merc.clear()
	_ouro_mesa = 0
	_pede_ouro = 0
	_rodadas = 0
	_trocas += 1
	_fala_merc = "Negócio fechado! Volte sempre." if r >= 1.3 else "Está bem. Negócio fechado."
	_fala_bruxa = "Essa poção me deu trabalho..." if pocao_dada else ("Bom negócio." if r < 1.3 else "Acho que paguei caro.")
	Vibrar.media()
	_montar()

# =============================================================================
# TELA (refeita a cada mudança; é pequena)
# =============================================================================
func _montar() -> void:
	if _raiz:
		_raiz.queue_free()
	_balanca = null
	_raiz = Control.new()
	position = Vector2.ZERO
	size = _tamanho()
	_raiz.position = Vector2.ZERO
	_raiz.size = _tamanho()
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.position = Vector2.ZERO
	fundo.size = _tamanho()
	_raiz.add_child(fundo)
	_montar_balanca()
	_atualizar_textos()

func _tamanho() -> Vector2:
	return get_viewport_rect().size

## Balança: inventários nas laterais e a mesa vira os pratos de uma balança (sem números).
func _montar_balanca() -> void:
	var s := _tamanho()
	_cabecalho(Rect2(16, 16, s.x - 32, 130))
	var lado := 150.0
	_painel(Rect2(8, 156, lado, 520), "Bruxa", _inv_bruxa(), true, true)
	_painel(Rect2(s.x - lado - 8, 156, lado, 520), _nome_merc(), _inv_merc(), false, true)
	_balanca = Balanca.new()
	_balanca.position = Vector2(lado + 16, 156)
	_balanca.size = Vector2(s.x - 2 * lado - 32, 520)
	_raiz.add_child(_balanca)
	var pw := _balanca.size.x / 2.0 - 8.0
	_balanca.prato_esq = _painel(Rect2(0, 0, pw, 200), "Você dá", _mesa_bruxa, true, false, _balanca)
	_balanca.prato_dir = _painel(Rect2(0, 0, pw, 200), "Você recebe", _mesa_merc, false, false, _balanca)
	# valor real dos dois lados, sem a margem (a margem é negociação): troca justa = reta;
	# pende para o lado que vale mais
	var rec := _recebe()
	var da := _da()
	_balanca.alvo = clampf((rec - da) / maxf(rec + da, 1.0), -1.0, 1.0)
	_rodape(688.0)

func _nome_merc() -> String:
	return _personagem.nome.capitalize() if _personagem and _personagem.nome != "" else "Mercador"

## O que ainda está no inventário (sem o que já foi para a mesa).
func _inv_bruxa() -> Dictionary:
	var d := {}
	for id in _gt.get_inventory():
		var q: int = _gt.get_item_quantity(id) - int(_mesa_bruxa.get(id, 0))
		if q > 0:
			d[id] = q
	return d

func _inv_merc() -> Dictionary:
	var d := {}
	for id in estoque:
		var q: int = int(estoque[id]) - int(_mesa_merc.get(id, 0))
		if q > 0:
			d[id] = q
	return d

# ---- peças ----
func _caixa(r: Rect2, cor: Color, pai: Control = null) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Estilo.caixa(cor, Estilo.BORDA_CINZA, 1, Estilo.RAIO))
	(pai if pai else _raiz).add_child(p)
	return p

func _rotulo(txt: String, tam: int, cor: Color, pai: Control, quebra: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l

## Face + nome + fala do mercador e a fala da bruxa.
func _cabecalho(r: Rect2) -> void:
	var c := _caixa(r, Estilo.FUNDO_MENU)
	var lado := r.size.y - 16.0
	var face := TextureRect.new()
	face.position = Vector2(8, 8)
	face.size = Vector2(lado * 0.7, lado)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture = _personagem.foto() if _personagem else null
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(face)
	if face.texture == null:
		var ph := ColorRect.new()
		ph.color = Color(0.3, 0.25, 0.2)
		ph.position = face.position
		ph.size = face.size
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(ph)
	var x := face.size.x + 20.0
	var nome := _rotulo(_nome_merc(), Estilo.FONTE_NOME, Estilo.DESTAQUE, c)
	nome.position = Vector2(x, 8)
	var balao := Panel.new()
	balao.position = Vector2(x, 40)
	balao.size = Vector2(r.size.x - x - 8, r.size.y * 0.45)
	balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balao.add_theme_stylebox_override("panel", Estilo.caixa_balao(Estilo.FUNDO_BALAO_CLARO))
	c.add_child(balao)
	_lbl_merc = _rotulo("", Estilo.FONTE_PEQUENA, Estilo.TEXTO_ESCURO, balao, true)
	_lbl_merc.position = Vector2(10, 6)
	_lbl_merc.size = balao.size - Vector2(20, 12)
	_lbl_bruxa = _rotulo("", Estilo.FONTE_PEQUENA, Estilo.TEXTO, c, true)
	_lbl_bruxa.position = Vector2(x, 44 + balao.size.y)
	_lbl_bruxa.size = Vector2(balao.size.x, 30)

## Painel com título e uma grade de itens (tocar = mover 1).
## inventario = true: tocar leva para a mesa; false (é a mesa): tocar devolve.
func _painel(r: Rect2, titulo: String, itens: Dictionary, da_bruxa: bool, inventario: bool,
		pai: Control = null) -> Panel:
	const colunas := 2
	var p := _caixa(r, Color(0.1, 0.09, 0.13), pai)
	var t := _rotulo(titulo, Estilo.FONTE_PEQUENA, Estilo.TEXTO_QUENTE, p)
	t.position = Vector2(10, 4)
	var sc := ScrollContainer.new()
	sc.position = Vector2(6, 34)
	sc.size = r.size - Vector2(12, 40)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var g := GridContainer.new()
	g.columns = colunas
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	sc.add_child(g)
	var lado := floorf((sc.size.x - 6.0 * (colunas - 1)) / colunas) - 2.0
	for id in itens:
		g.add_child(_ladrilho(id, itens[id], da_bruxa, inventario, lado))
	return p

## Um item: ícone e quantidade (sem valor: quem mostra é a balança).
func _ladrilho(id: String, q: int, da_bruxa: bool, inventario: bool, lado: float) -> Button:
	var it := _item(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(lado, lado)
	b.tooltip_text = it.get_nome() if it else id
	var fundo := Color(0.16, 0.15, 0.2)
	for estado in ["normal", "hover", "pressed"]:
		var cor := fundo if estado == "normal" else fundo.lightened(0.12 if estado == "hover" else 0.25)
		b.add_theme_stylebox_override(estado, Estilo.caixa(cor, Estilo.BORDA_CINZA, 1, 8))
	b.pressed.connect(_mover.bind(id, da_bruxa, inventario))
	var ic := TextureRect.new()
	ic.texture = it.icone if it else null
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(lado * 0.15, lado * 0.08)
	ic.size = Vector2(lado * 0.7, lado * 0.7)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var lq := _rotulo("×%d" % q, 16, Estilo.TEXTO, b)
	lq.position = Vector2(4, lado * 0.72)
	return b

## Ouro e botões.
func _rodape(y: float) -> void:
	var s := _tamanho()
	var linha := HBoxContainer.new()
	linha.position = Vector2(16, y)
	linha.size = Vector2(s.x - 32, 48)
	linha.add_theme_constant_override("separation", 6)
	_raiz.add_child(linha)
	for d in [-10, -1]:
		linha.add_child(_botao(str(d), _mudar_ouro.bind(d), 56))
	_lbl_ouro = Label.new()
	_lbl_ouro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_ouro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_ouro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_ouro.add_theme_font_size_override("font_size", 16)
	_lbl_ouro.add_theme_color_override("font_color", Estilo.DESTAQUE)
	linha.add_child(_lbl_ouro)
	for d in [1, 10]:
		linha.add_child(_botao("+" + str(d), _mudar_ouro.bind(d), 56))
	var botoes := HBoxContainer.new()
	botoes.position = Vector2(16, y + 58)
	botoes.size = Vector2(s.x - 32, 56)
	botoes.add_theme_constant_override("separation", 8)
	_raiz.add_child(botoes)
	_btn_propor = _botao("Propor", _propor)
	_btn_propor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botoes.add_child(_btn_propor)
	_btn_aceitar = _botao("Aceitar", _aceitar_contraproposta)
	_btn_ajustar = _botao("Ajustar", _ajustar)
	for b in [_btn_aceitar, _btn_ajustar]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botoes.add_child(b)
	var sair := _botao("Sair", _sair)
	sair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botoes.add_child(sair)

func _botao(txt: String, f: Callable, larg: float = 0.0) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", Estilo.FONTE_PEQUENA)
	Estilo.botao_preto(b, 6)
	if larg > 0.0:
		b.custom_minimum_size.x = larg
	b.pressed.connect(f)
	return b

func _atualizar_textos() -> void:
	if _lbl_merc:
		_lbl_merc.text = _fala_merc
	if _lbl_bruxa:
		_lbl_bruxa.text = ("Bruxa: " + _fala_bruxa) if _fala_bruxa != "" else ""
	if _lbl_ouro:
		var txt := "sem ouro na mesa"
		if _ouro_mesa > 0:
			txt = "você paga %d" % _ouro_mesa
		elif _ouro_mesa < 0:
			txt = "ele paga %d" % -_ouro_mesa
		_lbl_ouro.text = "%s\nseu ouro %d · dele %d" % [txt, _ouro_bruxa(), ouro_mercador]
	var contra := _pede_ouro > 0
	if _btn_propor:
		_btn_propor.visible = not contra
		_btn_propor.disabled = _mesa_vazia() or _desistiu
	if _btn_aceitar:
		_btn_aceitar.visible = contra
		_btn_ajustar.visible = contra


# =============================================================================
## A mesa: uma haste que pende para o lado que leva vantagem;
## os pratos (painéis da mesa) ficam pendurados nas pontas. Sem números.
class Balanca extends Control:
	const T_PENDER: float = 4.0
	const ANG_MAX: float = 0.28
	var alvo: float = 0.0       # −1..1: > 0 = o lado da bruxa (o que ele recebe) vale mais
	## Ângulo atual, guardado fora da balança: a tela é refeita a cada item e a balança
	## continua de onde estava até o novo resultado.
	static var ang_atual: float = 0.0
	var prato_esq: Control
	var prato_dir: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		# alvo > 0 = o prato da bruxa vale mais: esquerda desce
		ang_atual = lerpf(ang_atual, -alvo * ANG_MAX, clampf(delta * T_PENDER, 0.0, 1.0))
		var ang := ang_atual
		var c := Vector2(size.x / 2.0, 70.0)
		var meia := size.x / 2.0 - 10.0
		var pe := c + Vector2(-meia, 0).rotated(ang)
		var pd := c + Vector2(meia, 0).rotated(ang)
		if prato_esq:
			prato_esq.position = Vector2(clampf(pe.x - prato_esq.size.x / 2.0, 0.0, size.x - prato_esq.size.x), pe.y + 60.0)
		if prato_dir:
			prato_dir.position = Vector2(clampf(pd.x - prato_dir.size.x / 2.0, 0.0, size.x - prato_dir.size.x), pd.y + 60.0)
		queue_redraw()

	func _draw() -> void:
		var ang := ang_atual
		var c := Vector2(size.x / 2.0, 70.0)
		var meia := size.x / 2.0 - 10.0
		var cor := Color(0.85, 0.7, 0.35)
		draw_line(Vector2(c.x, c.y), Vector2(c.x, size.y - 20.0), cor, 4.0)
		draw_line(Vector2(c.x - 50, size.y - 20.0), Vector2(c.x + 50, size.y - 20.0), cor, 4.0)
		var pe := c + Vector2(-meia, 0).rotated(ang)
		var pd := c + Vector2(meia, 0).rotated(ang)
		draw_line(pe, pd, cor, 5.0)
		draw_circle(c, 7.0, cor)
		for p in [pe, pd]:
			draw_line(p, p + Vector2(0, 60), cor.darkened(0.2), 2.0)
