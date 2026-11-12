# painel_menu.gd
# Peças dos menus (principal e pausa): painel com título, lista de saves e opções de som.
#   PainelMenu.saves(ao_escolher, pode_apagar)  lista os saves (mais novo primeiro)
#   PainelMenu.opcoes()                          volumes (geral, música, efeitos)
# As opções ficam em user://opcoes.cfg e são aplicadas ao abrir o jogo (aplicar_opcoes).
class_name PainelMenu
extends PanelContainer

signal fechou

const ARQ_OPCOES := "user://opcoes.cfg"
const COR_FUNDO := Color(0.08, 0.07, 0.11, 0.97)
const COR_BORDA := Color(0.85, 0.7, 0.35)
const COR_TEXTO := Color(0.95, 0.92, 0.85)
const COR_SUAVE := Color(0.7, 0.66, 0.6)
const ALTURA_BOTAO: float = 64.0

var _col: VBoxContainer


static func estilo_painel() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = COR_FUNDO
	st.border_color = COR_BORDA
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(22)
	return st

static func botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	b.add_theme_font_size_override("font_size", 26)
	estilo_carta(b)
	if acao.is_valid():
		b.pressed.connect(acao)
	return b

## Botão com o sprite de carta do HUD (Carta.SPRITE_CARTA) em 9 fatias: os cantos não deformam.
const MARGEM_CARTA: float = 26.0
static func estilo_carta(b: Button) -> void:
	var tex: Texture2D = load(Carta.SPRITE_CARTA) if ResourceLoader.exists(Carta.SPRITE_CARTA) else null
	if tex == null:
		return
	for estado in [["normal", Color.WHITE], ["hover", Color(1.15, 1.15, 1.15)], ["pressed", Color(0.8, 0.8, 0.85)],
			["disabled", Color(0.55, 0.55, 0.55)]]:
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.set_texture_margin_all(MARGEM_CARTA)
		st.set_content_margin_all(12)
		st.modulate_color = estado[1]
		b.add_theme_stylebox_override(estado[0], st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.58, 0.55))

static func rotulo(texto: String, tam: int, cor: Color = COR_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l


func _init(titulo: String) -> void:
	add_theme_stylebox_override("panel", estilo_painel())
	position = Vector2(60, 140)
	size = Vector2(520, 680)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	add_child(_col)
	_col.add_child(rotulo(titulo, 32, COR_BORDA))


## Lista de saves. ao_escolher(nome) é chamado ao tocar num save.
static func saves(ao_escolher: Callable, pode_apagar: bool = true) -> PainelMenu:
	var p := PainelMenu.new("Carregar")
	p._montar_saves(ao_escolher, pode_apagar)
	return p

func _montar_saves(ao_escolher: Callable, pode_apagar: bool) -> void:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 8)
	sc.add_child(lista)
	_col.add_child(sc)
	var todos := SaveJogo.listar()
	if todos.is_empty():
		lista.add_child(rotulo("Nenhum jogo salvo ainda.", 22, COR_SUAVE))
	for s in todos:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var quando: String = str(s["quando"]).replace("T", "  ")
		var b := botao("%s\n%s" % [quando.left(17), s["mapa"]], ao_escolher.bind(s["nome"]))
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size.y = 78
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		if pode_apagar:
			var x := botao("Apagar", Callable())
			x.add_theme_font_size_override("font_size", 18)
			x.custom_minimum_size = Vector2(110, 78)
			x.pressed.connect(_apagar.bind(s["nome"], x))
			h.add_child(x)
		lista.add_child(h)
	_col.add_child(botao("Voltar", _fechar))

## Apagar pede confirmação (segundo toque).
func _apagar(nome: String, b: Button) -> void:
	if b.text != "Certeza?":
		b.text = "Certeza?"
		return
	SaveJogo.apagar(nome)
	var linha := b.get_parent()
	if linha:
		linha.queue_free()


## Opções de som.
static func opcoes(gm) -> PainelMenu:
	var p := PainelMenu.new("Opções")
	p._montar_opcoes(gm)
	return p

func _montar_opcoes(gm) -> void:
	var cfg := ler_opcoes()
	for par in [["Volume geral", "geral"], ["Música", "musica"], ["Efeitos", "efeitos"]]:
		_col.add_child(rotulo(par[0], 22, COR_SUAVE))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(cfg.get(par[1], 1.0))
		s.custom_minimum_size = Vector2(0, 48)
		s.value_changed.connect(_mudou.bind(gm, par[1]))
		_col.add_child(s)
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(esp)
	_col.add_child(botao("Voltar", _fechar))

func _mudou(v: float, gm, chave: String) -> void:
	var cfg := ler_opcoes()
	cfg[chave] = v
	gravar_opcoes(cfg)
	aplicar_opcoes(gm)

static func ler_opcoes() -> Dictionary:
	var c := ConfigFile.new()
	var out := {"geral": 1.0, "musica": 1.0, "efeitos": 1.0}
	if c.load(ARQ_OPCOES) == OK:
		for k in out:
			out[k] = float(c.get_value("som", k, out[k]))
	return out

static func gravar_opcoes(o: Dictionary) -> void:
	var c := ConfigFile.new()
	for k in o:
		c.set_value("som", k, o[k])
	c.save(ARQ_OPCOES)

static func aplicar_opcoes(gm) -> void:
	var audio = gm.get_node_or_null("AudioManager") if gm else null
	if audio == null:
		return
	var o := ler_opcoes()
	audio.set_master_volume(o["geral"])
	audio.set_bgm_volume(o["musica"])
	audio.set_bgs_volume(o["musica"])
	audio.set_se_volume(o["efeitos"])


func _fechar() -> void:
	fechou.emit()
	queue_free()
