# estilo.gd
# Estilo visual do jogo num lugar só: tamanhos de fonte, cores e caixas (StyleBox).
# As telas usam estas constantes/funções em vez de repetir números. Mudou aqui, muda em todas.
#   Fontes:  FONTE_TEXTO (diálogo, inventário, balão), FONTE_NOME, FONTE_MENU, FONTE_LEGENDA...
#   Cores:   TEXTO (branco), TEXTO_QUENTE (menus/legendas), DESTAQUE (dourado: nome, apertado)...
#   Caixas:  caixa(...)        StyleBoxFlat genérico
#            caixa_preta()     fundo do diálogo (preto, borda cinza)
#            caixa_menu()      painel dos menus (escuro, borda dourada)
#            caixa_popup()     popup do item
#            caixa_nome()      etiqueta do nome de quem fala
#            caixa_balao(...)  balõezinhos (nome do traço, fala da bruxinha)
#            botao_preto(btn)  botões das opções / Desistir
# (Menus de debug ficam de fora: são ferramenta, não jogo.)
class_name Estilo
extends RefCounted

# ----------------------------------------------------------------- fontes
const FONTE_TEXTO: int = 28        # diálogo, opções, inventário, balão da bruxinha, menu principal
const FONTE_NOME: int = 24         # nome de quem fala, botão de ação do popup
const FONTE_MENU: int = 26         # botões dos painéis de menu
const FONTE_LEGENDA: int = 30      # narração (intro)
const FONTE_PEQUENA: int = 20      # balão do Status, rótulos menores
const FONTE_TITULO: int = 64       # título do menu principal

# ----------------------------------------------------------------- cores
const TEXTO := Color.WHITE
const TEXTO_QUENTE := Color(0.95, 0.92, 0.85)    # menus, legendas, dicas
const TEXTO_SUAVE := Color(0.7, 0.66, 0.6)
const TEXTO_ESCURO := Color(0.1, 0.1, 0.1)       # texto sobre fundo claro (balão da bruxinha)
const DESTAQUE := Color(1.0, 0.85, 0.45)         # dourado: nome do falante, botão apertado
const DESTAQUE_CLARO := Color(1.0, 0.9, 0.6)     # botão com o mouse em cima
const SOMBRA := Color(0, 0, 0, 0.8)

const FUNDO_PRETO := Color(0, 0, 0)
const FUNDO_MENU := Color(0.08, 0.07, 0.11, 0.97)
const FUNDO_NOME := Color(0.16, 0.16, 0.22, 1.0)
const FUNDO_BALAO_CLARO := Color(0.95, 0.95, 0.92, 0.95)
const FUNDO_BALAO_ESCURO := Color(0, 0, 0, 0.85)

const BORDA_CINZA := Color(0.4, 0.4, 0.4, 0.8)
const BORDA_OURO := Color(0.85, 0.7, 0.35)
const BORDA_AZULADA := Color(0.6, 0.6, 0.8, 0.9)
const FUNDO_POPUP := Color(0.1, 0.1, 0.15, 1.0)
const BORDA_POPUP := Color(0.6, 0.6, 0.8, 0.8)

# ----------------------------------------------------------------- medidas
const RAIO: int = 12               # cantos das caixas e botões
const BORDA: int = 2

# ----------------------------------------------------------------- caixas
## StyleBoxFlat com o que for pedido. margem < 0 = não mexe na margem do conteúdo.
static func caixa(fundo: Color, borda: Color = Color(0, 0, 0, 0), larg_borda: int = 0,
		raio: int = RAIO, margem: float = -1.0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fundo
	if larg_borda > 0:
		st.border_color = borda
		st.set_border_width_all(larg_borda)
	st.set_corner_radius_all(raio)
	if margem >= 0.0:
		st.set_content_margin_all(margem)
	return st

## Fundo do diálogo: preto com borda cinza (igual aos botões das opções).
static func caixa_preta(margem: float = -1.0) -> StyleBoxFlat:
	return caixa(FUNDO_PRETO, BORDA_CINZA, BORDA, RAIO, margem)

## Painel dos menus (pausa, opções): escuro com borda dourada.
static func caixa_menu() -> StyleBoxFlat:
	return caixa(FUNDO_MENU, BORDA_OURO, BORDA, 14, 22)

## Popup do item (e o painel de fundo da OptionBox, que no HUD fica transparente).
static func caixa_popup() -> StyleBoxFlat:
	return caixa(FUNDO_POPUP, BORDA_POPUP, BORDA, 15)

## Etiqueta do nome de quem fala.
static func caixa_nome() -> StyleBoxFlat:
	var st := caixa(FUNDO_NOME, BORDA_AZULADA, BORDA, 10)
	_margens(st, 14, 4)
	return st

## Balõezinhos (sem borda): margem 10 nos lados, 4 em cima/embaixo.
static func caixa_balao(fundo: Color, raio: int = RAIO) -> StyleBoxFlat:
	var st := caixa(fundo, Color(0, 0, 0, 0), 0, raio)
	_margens(st, 10, 4)
	return st

static func _margens(st: StyleBoxFlat, lados: float, cima_baixo: float) -> void:
	st.content_margin_left = lados
	st.content_margin_right = lados
	st.content_margin_top = cima_baixo
	st.content_margin_bottom = cima_baixo

## Botão preto (opções, Desistir): borda cinza, texto branco; dourado ao passar/apertar.
## margem_texto < 0 = não mexe na margem do conteúdo.
static func botao_preto(btn: Button, margem_texto: float = -1.0) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", TEXTO)
	btn.add_theme_color_override("font_hover_color", DESTAQUE_CLARO)
	btn.add_theme_color_override("font_pressed_color", DESTAQUE)
	var cores := {"normal": FUNDO_PRETO, "hover": Color(0.12, 0.12, 0.12), "pressed": Color(0.22, 0.22, 0.22)}
	for estado in cores:
		btn.add_theme_stylebox_override(estado, caixa(cores[estado], BORDA_CINZA, BORDA, RAIO, margem_texto))
