# popup_item.gd - VERSÃO COMPLETA
extends Control
class_name PopupItem

# ===== SINAIS =====
signal popup_closed()

# ===== REFERÊNCIAS UI =====
@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var quantity_label: Label = $Panel/MarginContainer/VBoxContainer/QuantityLabel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

# ===== CONSTANTES =====
const MAX_WIDTH: float = 500.0
const MIN_WIDTH: float = 300.0
const PADDING: float = 40.0  # Margem interna padrão (se o MarginContainer não existir)
const SCREEN_MARGIN: float = 10.0  # Distância mínima da borda da tela

var _show_token: int = 0  # evita que dois show_item seguidos se atropelem

# ===== BOTÃO DE AÇÃO (ex.: "Aplicar poção"), só quando alguém pede =====
var _botao_acao: Button
var _acao: Callable

# ===== MATRIZ (pentágono O-C-E-A-N + grade 5x5), criados por código =====
const TAM_PENTAGONO := Vector2(210, 190)
const TAM_GRADE := Vector2(130, 130)
var _linha_matriz: HBoxContainer
var _pentagono: PentagonoOcean
var _grade: GradeMatriz

func _ready():
    process_mode = PROCESS_MODE_ALWAYS
    add_to_group(UiModal.GRUPO)   # aberto: a lista do inventário embaixo não recebe o toque
    _setup_ui()
    
    if close_button:
        close_button.pressed.connect(_on_close_pressed)
    _criar_matriz()
    _criar_botao_acao()
    
    visible = false

func _criar_botao_acao():
    _botao_acao = Button.new()
    _botao_acao.visible = false
    _botao_acao.add_theme_font_size_override("font_size", 24)
    _botao_acao.pressed.connect(func():
        var acao := _acao
        hide_item()
        if acao.is_valid():
            acao.call())
    if close_button:
        vbox.add_child(_botao_acao)
        vbox.move_child(_botao_acao, close_button.get_index())

## Mostra um botão extra no popup aberto (chame logo depois de show_item).
func mostrar_acao(texto: String, acao: Callable):
    if not _botao_acao:
        return
    _botao_acao.text = texto
    _acao = acao
    _botao_acao.visible = true

func _setup_ui():
    """Configura a aparência do popup"""
    if panel:
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_color = Color(0.6, 0.6, 0.8, 0.8)
        style.corner_radius_top_left = 15
        style.corner_radius_top_right = 15
        style.corner_radius_bottom_left = 15
        style.corner_radius_bottom_right = 15
        panel.add_theme_stylebox_override("panel", style)

func show_item(item_name: String, item_data: Dictionary, quantity: int, anchor = null, area: Rect2 = Rect2()):
    """Mostra o popup com os dados do item.
    anchor: ponto (coordenadas da tela) onde o popup deve aparecer centralizado.
    area: retângulo onde o popup deve caber inteiro (padrão: tela toda)."""
    _show_token += 1
    var my_token = _show_token
    if _botao_acao:
        _botao_acao.visible = false   # só aparece se pedirem (mostrar_acao)
        _acao = Callable()

    # 🔥 ATUALIZA OS LABELS
    if title_label:
        title_label.text = item_name
    if description_label:
        description_label.text = item_data.get("descricao", "(Sem descrição disponível.)")
    if quantity_label:
        quantity_label.text = "QTD: " + str(quantity)
    # matriz do item (efeito na personalidade): pentágono + grade
    var A = item_data.get("A")
    if _linha_matriz:
        _linha_matriz.visible = A != null
        if A != null:
            _pentagono.mostrar(A)
            _grade.mostrar(A)

    # 🔥 1. LARGURA: mede o texto de verdade e limita entre MIN/MAX
    var pad = _get_padding()
    var content_w = _calculate_content_width(pad)
    if description_label:
        # autowrap quebra o texto nessa largura; a altura vem do layout
        description_label.custom_minimum_size.x = content_w
    _fit_margin_to_panel()

    # Fica invisível (alpha 0) enquanto o layout é calculado, para não piscar
    modulate.a = 0.0
    visible = true

    # 🔥 2. ALTURA: espera o layout dos containers (texto quebrado em várias linhas)
    await get_tree().process_frame
    await get_tree().process_frame
    if my_token != _show_token:
        return  # outro item foi aberto no meio do cálculo

    var needed = margin_container.get_combined_minimum_size()
    var popup_size = Vector2(max(needed.x, content_w + pad.x), needed.y)
    panel.size = popup_size
    panel.position = -popup_size / 2.0  # panel centralizado na origem do popup

    # 🔥 3. POSIÇÃO: centraliza no anchor e prende dentro da área visível
    if anchor != null:
        global_position = _clamp_center(anchor, popup_size, area)

    modulate.a = 1.0
    print("[PopupItem] Mostrando: ", item_name, " | tamanho: ", popup_size)

func hide_item():
    """Esconde o popup"""
    _show_token += 1  # cancela um show_item que ainda esteja calculando
    visible = false
    popup_closed.emit()
    print("[PopupItem] Fechado")

func _criar_matriz():
    """Linha com o pentágono e a grade, entre a descrição e a quantidade."""
    if not vbox:
        return
    _linha_matriz = HBoxContainer.new()
    _linha_matriz.name = "Matriz"
    _linha_matriz.alignment = BoxContainer.ALIGNMENT_CENTER
    _linha_matriz.add_theme_constant_override("separation", 16)
    _linha_matriz.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _linha_matriz.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _pentagono = PentagonoOcean.new()
    _pentagono.custom_minimum_size = TAM_PENTAGONO
    _pentagono.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _grade = GradeMatriz.new()
    _grade.custom_minimum_size = TAM_GRADE
    _grade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _linha_matriz.add_child(_pentagono)
    _linha_matriz.add_child(_grade)
    vbox.add_child(_linha_matriz)
    if quantity_label:
        vbox.move_child(_linha_matriz, quantity_label.get_index())
    _linha_matriz.visible = false

func _get_padding() -> Vector2:
    """Margens reais do MarginContainer (esq+dir, cima+baixo)."""
    if not margin_container:
        return Vector2(PADDING, PADDING)
    return Vector2(
        margin_container.get_theme_constant("margin_left") + margin_container.get_theme_constant("margin_right"),
        margin_container.get_theme_constant("margin_top") + margin_container.get_theme_constant("margin_bottom"))

func _calculate_content_width(pad: Vector2) -> float:
    """Largura do conteúdo: o maior entre título, botão e a descrição numa linha só,
    limitado a [MIN_WIDTH, MAX_WIDTH] (largura total do popup)."""
    var w = 0.0
    if title_label:
        w = max(w, _text_width(title_label))
    if quantity_label:
        w = max(w, _text_width(quantity_label))
    if close_button:
        w = max(w, close_button.get_combined_minimum_size().x)
    if description_label:
        w = max(w, _text_width(description_label))
    if _linha_matriz and _linha_matriz.visible:
        w = max(w, TAM_PENTAGONO.x + TAM_GRADE.x + 16.0)
    return clamp(w + pad.x, MIN_WIDTH, MAX_WIDTH) - pad.x

func _text_width(label: Label) -> float:
    var font = label.get_theme_font("font")
    var font_size = label.get_theme_font_size("font_size")
    if not font:
        return label.get_minimum_size().x
    return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _fit_margin_to_panel():
    """O MarginContainer ocupa o Panel inteiro (na cena ele estava centralizado com tamanho fixo)."""
    if margin_container:
        margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _clamp_center(center: Vector2, popup_size: Vector2, area: Rect2) -> Vector2:
    """Ajusta o centro para que o popup inteiro (+ margem) fique dentro de area."""
    if area.size == Vector2.ZERO:
        area = get_viewport_rect()
    var half = popup_size / 2.0 + Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
    var c = center
    # Se não couber, centraliza na área
    c.x = clamp(c.x, area.position.x + half.x, area.end.x - half.x) if area.size.x >= half.x * 2.0 else area.get_center().x
    c.y = clamp(c.y, area.position.y + half.y, area.end.y - half.y) if area.size.y >= half.y * 2.0 else area.get_center().y
    return c

func get_popup_size() -> Vector2:
    """Retorna o tamanho atual do popup"""
    return panel.size if panel else Vector2.ZERO

func _on_close_pressed():
    hide_item()

# ===== FECHAR COM ESC OU CLICANDO FORA =====

func _input(event: InputEvent):
    if not visible:
        return
    
    # Fecha com ESC
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        hide_item()
        return
    
    # Fecha ao clicar fora do panel
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos = get_global_mouse_position()
        var panel_rect = panel.get_global_rect()
        if not panel_rect.has_point(mouse_pos):
            hide_item()