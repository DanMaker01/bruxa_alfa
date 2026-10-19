import pygame
import sys

# Inicialização
pygame.init()
pygame.font.init()

# Configurações da tela
WIDTH, HEIGHT = 1200, 700
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Controle do Fogo - Modelo Completo")
clock = pygame.time.Clock()

# Cores
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 50, 50)
BLUE = (50, 150, 255)
GREEN = (50, 255, 100)
GRAY = (200, 200, 200)
DARK_GRAY = (100, 100, 100)
LIGHT_BLUE = (200, 230, 255)
YELLOW = (255, 255, 0)
ORANGE = (255, 165, 0)
PURPLE = (200, 100, 255)
BROWN = (139, 69, 19)
LIGHT_GRAY = (220, 220, 220)
FIRE_ORANGE = (255, 140, 0)
FIRE_RED = (255, 50, 0)

# Classe para Slider
class Slider:
    def __init__(self, x, y, width, min_val, max_val, initial_val, label, color=BLUE, decimals=3):
        self.x = x
        self.y = y
        self.width = width
        self.min_val = min_val
        self.max_val = max_val
        self.value = initial_val
        self.label = label
        self.color = color
        self.decimals = decimals
        self.rect = pygame.Rect(x, y, width, 20)
        self.dragging = False
        self.font = pygame.font.Font(None, 22)
        
    def draw(self, screen):
        format_str = f"{{:.{self.decimals}f}}"
        label_text = self.font.render(f"{self.label}: {format_str.format(self.value)}", True, BLACK)
        screen.blit(label_text, (self.x, self.y - 25))
        
        pygame.draw.rect(screen, LIGHT_GRAY, self.rect)
        pygame.draw.rect(screen, BLACK, self.rect, 2)
        
        ratio = (self.value - self.min_val) / (self.max_val - self.min_val)
        fill_width = ratio * self.width
        pygame.draw.rect(screen, self.color, (self.x, self.y, fill_width, 20))
        
        handle_x = self.x + fill_width - 5
        handle_rect = pygame.Rect(handle_x, self.y - 5, 10, 30)
        pygame.draw.rect(screen, DARK_GRAY, handle_rect)
        pygame.draw.rect(screen, BLACK, handle_rect, 2)
        
        return handle_rect
    
    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                if self.rect.collidepoint(event.pos):
                    self.dragging = True
                    self.update_value(event.pos[0])
        elif event.type == pygame.MOUSEBUTTONUP:
            if event.button == 1:
                self.dragging = False
        elif event.type == pygame.MOUSEMOTION:
            if self.dragging:
                self.update_value(event.pos[0])
    
    def update_value(self, mouse_x):
        if mouse_x < self.x:
            mouse_x = self.x
        elif mouse_x > self.x + self.width:
            mouse_x = self.x + self.width
        
        ratio = (mouse_x - self.x) / self.width
        self.value = self.min_val + ratio * (self.max_val - self.min_val)
        self.value = max(self.min_val, min(self.max_val, self.value))

# Parâmetros do sistema
class SystemParams:
    def __init__(self):
        # Parâmetros do caldeirão
        self.T_amb = 20.0      # Temperatura ambiente do caldeirão
        self.k = 0.02          # Coeficiente de resfriamento do caldeirão
        self.a = 0.08          # Coeficiente de intensidade do fogo (usado quando ligado)
        
        # Parâmetros do fogo
        self.F_amb = 100.0     # Temperatura ambiente do fogo (agora 100°C)
        self.h = 0.1           # Coeficiente de esfriamento do fogo
        self.F_max = 240.0     # Temperatura máxima do fogo
        self.F_min = 20.0      # Temperatura mínima do fogo
        
        # Parâmetros de controle
        self.F_increment = 10.0  # Quanto F aumenta ao apertar Espaço
        self.dt = 0.1           # Passo de tempo
        
        # Estado do fogo
        self.fire_on = False
        
        # Variáveis
        self.T = 20.0  # Temperatura do caldeirão
        self.F = 100.0  # Temperatura do fogo (começa em 100°C)
        self.time = 0.0
        
        # Histórico
        self.history_T = [self.T]
        self.history_F = [self.F]
        self.history_time = [self.time]
        self.max_history = 10000

params = SystemParams()

# Sliders
sliders = [
    # Parâmetros do caldeirão
    Slider(50, 130, 280, 0.0, 50.0, params.T_amb, "T_amb (ambiente caldeirão)", BLUE, 1),
    Slider(50, 175, 280, 0.001, 0.5, params.k, "k (resfriamento caldeirão)", RED, 3),
    Slider(50, 220, 280, 0.001, 0.5, params.a, "a (intensidade fogo)", ORANGE, 3),
    
    # Parâmetros do fogo
    Slider(50, 265, 280, 0.0, 200.0, params.F_amb, "F_amb (ambiente fogo)", PURPLE, 1),
    Slider(50, 310, 280, 0.001, 1.0, params.h, "h (esfriamento fogo)", PURPLE, 3),
    Slider(50, 355, 280, 20.0, 300.0, params.F_max, "F_max (máximo)", FIRE_RED, 1),
    Slider(50, 400, 280, 20.0, 250.0, params.F_min, "F_min (mínimo)", FIRE_ORANGE, 1),
    
    # Parâmetros de controle
    Slider(50, 445, 280, 1.0, 50.0, params.F_increment, "Incremento F", GREEN, 1),
    Slider(50, 490, 280, 0.001, 1.0, params.dt, "dt (passo de tempo)", BLUE, 3),
]

# Estado do sistema
running = True
paused = False
space_held = False
space_hold_timer = 0

# Fonte
font = pygame.font.Font(None, 22)
title_font = pygame.font.Font(None, 28)
big_font = pygame.font.Font(None, 36)

def update_system():
    """Atualiza o sistema usando equações diferenciais"""
    if not paused:
        # Atualiza parâmetros dos sliders
        params.T_amb = sliders[0].value
        params.k = sliders[1].value
        params.a = sliders[2].value
        params.F_amb = sliders[3].value
        params.h = sliders[4].value
        params.F_max = sliders[5].value
        params.F_min = sliders[6].value
        params.F_increment = sliders[7].value
        params.dt = sliders[8].value
        
        # Garante que F_min não ultrapasse F_max
        if params.F_min >= params.F_max:
            params.F_min = params.F_max - 10.0
            sliders[6].value = params.F_min
        
        # 1. Fogo: dF/dt = -h*(F - F_amb)
        if params.fire_on:
            # Fogo ligado: F tende a F_amb com taxa h
            dF = -params.h * (params.F - params.F_amb)
            params.F = params.F + dF * params.dt
        else:
            # Fogo desligado: F mantém constante
            pass
        
        # Limites de F
        params.F = max(params.F_min, min(params.F_max, params.F))
        
        # 2. Caldeirão: dT/dt = -k*(T - T_amb) + a*(F - T)
        if params.fire_on:
            # Fogo ligado: usa a > 0 (valor do slider)
            dT = -params.k * (params.T - params.T_amb) + params.a * (params.F - params.T)
        else:
            # Fogo desligado: a = 0
            dT = -params.k * (params.T - params.T_amb)
        
        params.T = params.T + dT * params.dt
        params.T = max(0.0, min(500.0, params.T))
        
        # Atualiza tempo
        params.time += params.dt
        
        # Armazena histórico
        params.history_T.append(params.T)
        params.history_F.append(params.F)
        params.history_time.append(params.time)
        
        if len(params.history_T) > params.max_history:
            params.history_T.pop(0)
            params.history_F.pop(0)
            params.history_time.pop(0)

def draw_graphs():
    """Desenha os gráficos"""
    graph_x = 400
    graph_y = 80
    graph_width = 750
    graph_height = 300
    
    # Fundo
    pygame.draw.rect(screen, WHITE, (graph_x, graph_y, graph_width, graph_height))
    pygame.draw.rect(screen, BLACK, (graph_x, graph_y, graph_width, graph_height), 2)
    
    # Eixos
    pygame.draw.line(screen, BLACK, (graph_x, graph_y + graph_height), 
                    (graph_x + graph_width, graph_y + graph_height), 2)
    pygame.draw.line(screen, BLACK, (graph_x, graph_y), 
                    (graph_x, graph_y + graph_height), 2)
    
    # Escalas
    max_T = max(50, max(params.history_T) * 1.2)
    max_F = max(50, max(params.history_F) * 1.2)
    max_val = max(max_T, max_F)
    
    # Linhas de grade
    for i in range(0, 6):
        y_pos = graph_y + graph_height - (i / 5) * graph_height
        val = (i / 5) * max_val
        pygame.draw.line(screen, GRAY, (graph_x, y_pos), 
                        (graph_x + graph_width, y_pos), 1)
        label = font.render(f"{val:.0f}", True, BLACK)
        screen.blit(label, (graph_x - 45, y_pos - 10))
    
    # Plot
    if len(params.history_time) > 1:
        points_T = []
        points_F = []
        for i in range(len(params.history_time)):
            x = graph_x + (params.history_time[i] / params.history_time[-1]) * graph_width
            y_T = graph_y + graph_height - (params.history_T[i] / max_val) * graph_height
            y_F = graph_y + graph_height - (params.history_F[i] / max_val) * graph_height
            points_T.append((x, y_T))
            points_F.append((x, y_F))
        
        if len(points_T) > 1:
            pygame.draw.lines(screen, RED, False, points_T, 3)
            pygame.draw.lines(screen, FIRE_ORANGE, False, points_F, 3)
    
    # Legendas
    legend_x = graph_x + graph_width - 160
    legend_y = graph_y + 10
    
    pygame.draw.line(screen, RED, (legend_x, legend_y + 5), (legend_x + 20, legend_y + 5), 3)
    label = font.render("T(t) - Caldeirão", True, BLACK)
    screen.blit(label, (legend_x + 25, legend_y))
    
    pygame.draw.line(screen, FIRE_ORANGE, (legend_x, legend_y + 25), (legend_x + 20, legend_y + 25), 3)
    label = font.render("F(t) - Fogo", True, BLACK)
    screen.blit(label, (legend_x + 25, legend_y + 20))
    
    # Título
    title = title_font.render("Evolução Temporal", True, BLACK)
    screen.blit(title, (graph_x + graph_width//2 - 80, graph_y - 30))

def draw_interface():
    """Desenha toda a interface"""
    screen.fill(LIGHT_BLUE)
    
    # Título
    title = big_font.render("Controle do Fogo - Modelo Completo", True, BLACK)
    screen.blit(title, (WIDTH//2 - 250, 10))
    
    # Equações
    eq1 = font.render("dF/dt = -h·(F - F_amb)  (F_amb = 100°C)", True, DARK_GRAY)
    eq2 = font.render("dT/dt = -k·(T - T_amb) + a·(F - T)  (a=0 se desligado)", True, DARK_GRAY)
    screen.blit(eq1, (50, 55))
    screen.blit(eq2, (50, 80))
    
    # Painel de sliders
    panel_x = 20
    panel_y = 110
    panel_width = 340
    panel_height = 420
    
    pygame.draw.rect(screen, WHITE, (panel_x, panel_y, panel_width, panel_height))
    pygame.draw.rect(screen, BLACK, (panel_x, panel_y, panel_width, panel_height), 2)
    
    title = title_font.render("Parâmetros Ajustáveis", True, BLACK)
    screen.blit(title, (panel_x + 10, panel_y + 8))
    
    for slider in sliders:
        slider.draw(screen)
    
    # Painel de controle do fogo
    control_x = 20
    control_y = 545
    control_width = 340
    control_height = 130
    
    pygame.draw.rect(screen, WHITE, (control_x, control_y, control_width, control_height))
    pygame.draw.rect(screen, BLACK, (control_x, control_y, control_width, control_height), 2)
    
    title = title_font.render("Controle do Fogo", True, BLACK)
    screen.blit(title, (control_x + 10, control_y + 8))
    
    # Status do fogo
    status_text = "LIGADO" if params.fire_on else "DESLIGADO"
    status_color = GREEN if params.fire_on else RED
    status_label = title_font.render(f"Fogo: {status_text}", True, status_color)
    screen.blit(status_label, (control_x + 10, control_y + 40))
    
    # Mostra se a está ativo
    a_atual = params.a if params.fire_on else 0.0
    a_label = font.render(f"a (atual): {a_atual:.3f}", True, DARK_GRAY)
    screen.blit(a_label, (control_x + 10, control_y + 62))
    
    # Valor de F
    f_label = font.render(f"F = {params.F:.1f}°C (F_amb: {params.F_amb:.0f}°C)", True, FIRE_ORANGE)
    screen.blit(f_label, (control_x + 10, control_y + 85))
    
    # Barra de F
    bar_x = control_x + 10
    bar_y = control_y + 107
    bar_width = 200
    bar_height = 15
    
    # Calcula a razão de F
    F_range = params.F_max - params.F_min
    if F_range > 0:
        F_ratio = (params.F - params.F_min) / F_range
    else:
        F_ratio = 0
    F_ratio = max(0, min(1, F_ratio))
    
    # Fundo da barra
    pygame.draw.rect(screen, LIGHT_GRAY, (bar_x, bar_y, bar_width, bar_height))
    pygame.draw.rect(screen, BLACK, (bar_x, bar_y, bar_width, bar_height), 2)
    
    # Preenchimento da barra
    pygame.draw.rect(screen, FIRE_ORANGE, (bar_x + 2, bar_y + 2, 
                                           (bar_width - 4) * F_ratio, bar_height - 4))
    
    # Linha de F_amb na barra
    if params.F_amb >= params.F_min and params.F_amb <= params.F_max:
        amb_ratio = (params.F_amb - params.F_min) / F_range
        amb_x = bar_x + 2 + (bar_width - 4) * amb_ratio
        pygame.draw.line(screen, BLACK, (amb_x, bar_y), (amb_x, bar_y + bar_height), 2)
    
    # Texto na barra
    bar_label = font.render(f"{params.F:.0f}°C", True, BLACK)
    screen.blit(bar_label, (bar_x + bar_width//2 - 20, bar_y + 1))
    
    # Espaço para instruções
    space_btn_x = control_x + 230
    space_btn_y = control_y + 40
    space_btn_w = 90
    space_btn_h = 70
    
    # Cor do botão muda quando está sendo pressionado
    btn_color = YELLOW if space_held else GRAY
    pygame.draw.rect(screen, btn_color, (space_btn_x, space_btn_y, space_btn_w, space_btn_h))
    pygame.draw.rect(screen, BLACK, (space_btn_x, space_btn_y, space_btn_w, space_btn_h), 2)
    
    # Texto do botão Espaço
    if not params.fire_on:
        label = font.render("ESPAÇO", True, BLACK)
        screen.blit(label, (space_btn_x + 8, space_btn_y + 8))
        label = font.render("LIGA", True, BLACK)
        screen.blit(label, (space_btn_x + 18, space_btn_y + 30))
    else:
        label = font.render("ESPAÇO", True, BLACK)
        screen.blit(label, (space_btn_x + 8, space_btn_y + 8))
        label = font.render("AUMENTA", True, BLACK)
        screen.blit(label, (space_btn_x + 8, space_btn_y + 30))
        label = font.render("F", True, BLACK)
        screen.blit(label, (space_btn_x + 35, space_btn_y + 50))
    
    # Valores atuais do caldeirão
    info_x = 400
    info_y = 400
    info_width = 350
    info_height = 150
    
    pygame.draw.rect(screen, WHITE, (info_x, info_y, info_width, info_height))
    pygame.draw.rect(screen, BLACK, (info_x, info_y, info_width, info_height), 2)
    
    title = title_font.render("Estado Atual", True, BLACK)
    screen.blit(title, (info_x + 10, info_y + 8))
    
    # Calcula as derivadas para mostrar
    dF = -params.h * (params.F - params.F_amb) if params.fire_on else 0
    a_efetivo = params.a if params.fire_on else 0
    dT = -params.k * (params.T - params.T_amb) + a_efetivo * (params.F - params.T)
    
    info_text = [
        f"Caldeirão: {params.T:.1f}°C",
        f"Fogo: {params.F:.1f}°C",
        f"a (efetivo): {a_efetivo:.3f}",
        f"dF/dt: {dF:.3f} °C/s",
        f"dT/dt: {dT:.3f} °C/s",
        f"Tempo: {params.time:.1f}s"
    ]
    
    for i, text in enumerate(info_text):
        label = font.render(text, True, BLACK)
        screen.blit(label, (info_x + 10, info_y + 35 + i * 20))
    
    # Barra de temperatura do caldeirão
    temp_x = 400
    temp_y = 565
    temp_w = 350
    temp_h = 25
    
    pygame.draw.rect(screen, WHITE, (temp_x, temp_y, temp_w, temp_h))
    pygame.draw.rect(screen, BLACK, (temp_x, temp_y, temp_w, temp_h), 2)
    
    temp_ratio = (params.T - 0) / 300
    temp_ratio = max(0, min(1, temp_ratio))
    temp_color = (255, int(255 * (1 - temp_ratio)), int(255 * (1 - temp_ratio)))
    pygame.draw.rect(screen, temp_color, (temp_x + 2, temp_y + 2, 
                                          (temp_w - 4) * temp_ratio, temp_h - 4))
    
    temp_label = font.render(f"T = {params.T:.1f}°C", True, BLACK)
    screen.blit(temp_label, (temp_x + temp_w//2 - 40, temp_y + 5))
    
    # Botões de controle
    pause_x = 400
    pause_y = 600
    pause_w = 100
    pause_h = 40
    
    color = YELLOW if paused else GRAY
    pygame.draw.rect(screen, color, (pause_x, pause_y, pause_w, pause_h))
    pygame.draw.rect(screen, BLACK, (pause_x, pause_y, pause_w, pause_h), 2)
    label = title_font.render("Pausa" if not paused else "▶", True, BLACK)
    screen.blit(label, (pause_x + 20, pause_y + 8))
    
    reset_x = 520
    reset_y = 600
    reset_w = 100
    reset_h = 40
    
    pygame.draw.rect(screen, GRAY, (reset_x, reset_y, reset_w, reset_h))
    pygame.draw.rect(screen, BLACK, (reset_x, reset_y, reset_w, reset_h), 2)
    label = title_font.render("Reset", True, BLACK)
    screen.blit(label, (reset_x + 20, pause_y + 8))
    
    # Gráficos
    draw_graphs()
    
    # Instruções
    inst = font.render("ESPAÇO: Liga/Aumenta F | Segurar ESPAÇO desliga | P: Pausa | R: Reset", True, DARK_GRAY)
    screen.blit(inst, (400, 660))

def reset_simulation():
    """Reseta a simulação"""
    params.T = params.T_amb
    params.F = params.F_amb  # F começa em 100°C (F_amb)
    params.time = 0.0
    params.fire_on = False
    params.history_T = [params.T]
    params.history_F = [params.F]
    params.history_time = [params.time]

# Loop principal
while running:
    # Processa eventos
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        
        # Eventos dos sliders
        for slider in sliders:
            slider.handle_event(event)
        
        if event.type == pygame.MOUSEBUTTONDOWN:
            mouse_x, mouse_y = pygame.mouse.get_pos()
            
            # Botão Pausa
            if (400 <= mouse_x <= 500) and (600 <= mouse_y <= 640):
                paused = not paused
            
            # Botão Reset
            if (520 <= mouse_x <= 620) and (600 <= mouse_y <= 640):
                reset_simulation()
        
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # Apenas processa se não estiver segurando
                if not space_held:
                    space_held = True
                    space_hold_timer = 0
                    
                    if not params.fire_on:
                        # Fogo desligado: liga o fogo
                        params.fire_on = True
                        # Se F estiver abaixo do mínimo, coloca no mínimo
                        if params.F < params.F_min:
                            params.F = params.F_min
                        print("Fogo ligado! (a ativado)")
                    else:
                        # Fogo ligado: aumenta F (respeitando o limite máximo)
                        novo_F = params.F + params.F_increment
                        if novo_F > params.F_max:
                            novo_F = params.F_max
                            print(f"F atingiu o limite máximo de {params.F_max:.0f}°C!")
                        params.F = novo_F
                        print(f"F aumentado para: {params.F:.1f}°C")
            
            elif event.key == pygame.K_p:
                paused = not paused
            elif event.key == pygame.K_r:
                reset_simulation()
        
        elif event.type == pygame.KEYUP:
            if event.key == pygame.K_SPACE:
                # Reset quando solta a tecla
                space_held = False
                space_hold_timer = 0

    # Verifica se a tecla Espaço está sendo segurada por mais de 0.5 segundos
    if space_held:
        space_hold_timer += 1
        # Se segurar por mais de 30 frames (0.5 segundos a 60fps)
        if space_hold_timer > 30 and params.fire_on:
            params.fire_on = False
            space_held = False
            space_hold_timer = 0
            print("Fogo desligado! (a = 0)")
    
    # Atualiza sistema
    update_system()
    
    # Desenha interface
    draw_interface()
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
sys.exit()