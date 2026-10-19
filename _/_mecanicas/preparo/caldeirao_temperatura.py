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
        # Parâmetros
        self.T_amb = 20.0
        self.k = 0.02
        self.a = 0.08
        self.dt = 0.1
        
        # Estado do fogo
        self.fire_on = False
        self.c = 0.0  # Controle do fogo [0, 1]
        
        # Variáveis
        self.T = 20.0
        self.F = 100.0  # F = 100 + c*100
        self.time = 0.0
        
        # Histórico
        self.history_T = [self.T]
        self.history_F = [self.F]
        self.history_time = [self.time]
        self.max_history = 10000

params = SystemParams()

# Sliders
sliders = [
    Slider(50, 130, 280, 0.001, 0.5, params.k, "k (resfriamento)", RED),
    Slider(50, 175, 280, 0.001, 0.1, params.a, "a (intensidade)", ORANGE),
    Slider(50, 220, 280, 0.01, 0.5, params.dt, "dt (passo)", BLUE, 3),
]

# Estado do sistema
running = True
paused = False
mouse_on_fire_btn = False
mouse_on_plus_btn = False
mouse_on_minus_btn = False

# Fonte
font = pygame.font.Font(None, 22)
title_font = pygame.font.Font(None, 28)
big_font = pygame.font.Font(None, 36)

def update_system():
    """Atualiza o sistema"""
    if not paused:
        # Atualiza parâmetros
        params.k = sliders[0].value
        params.a = sliders[1].value
        params.dt = sliders[2].value
        
        # 1. Fogo: F = 100 + c*100
        params.F = 120 + params.c * 126
        
        # 2. Caldeirão
        if params.fire_on:
            # Fogo ligado: a > 0
            dT = -params.k * (params.T - params.T_amb) + params.a * (params.F - params.T)
        else:
            # Fogo desligado: a = 0
            dT = -params.k * (params.T - params.T_amb)
        
        params.T = params.T + dT * params.dt
        params.T = max(params.T_amb, min(300, params.T))
        
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
    max_F = max(120, max(params.history_F) * 1.2)
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
    eq1 = font.render("F = 100 + c·100  (c ∈ [0, 1])", True, DARK_GRAY)
    eq2 = font.render("T_n+1 = T_n + [ -k·(T_n - T_amb) + a·(F - T_n) ]·dt", True, DARK_GRAY)
    screen.blit(eq1, (50, 55))
    screen.blit(eq2, (50, 80))
    
    # Painel de sliders
    panel_x = 20
    panel_y = 110
    panel_width = 340
    panel_height = 170
    
    pygame.draw.rect(screen, WHITE, (panel_x, panel_y, panel_width, panel_height))
    pygame.draw.rect(screen, BLACK, (panel_x, panel_y, panel_width, panel_height), 2)
    
    title = title_font.render("Parâmetros", True, BLACK)
    screen.blit(title, (panel_x + 10, panel_y + 8))
    
    for slider in sliders:
        slider.draw(screen)
    
    # Painel de controle do fogo
    control_x = 20
    control_y = 300
    control_width = 340
    control_height = 200
    
    pygame.draw.rect(screen, WHITE, (control_x, control_y, control_width, control_height))
    pygame.draw.rect(screen, BLACK, (control_x, control_y, control_width, control_height), 2)
    
    title = title_font.render("Controle do Fogo", True, BLACK)
    screen.blit(title, (control_x + 10, control_y + 8))
    
    # Status do fogo
    status_text = "LIGADO" if params.fire_on else "DESLIGADO"
    status_color = GREEN if params.fire_on else RED
    status_label = title_font.render(f"Fogo: {status_text}", True, status_color)
    screen.blit(status_label, (control_x + 10, control_y + 40))
    
    # Valor de c
    c_label = font.render(f"c = {params.c:.2f}", True, BLACK)
    screen.blit(c_label, (control_x + 10, control_y + 75))
    
    # Valor de F
    f_label = font.render(f"F = {params.F:.1f}°C", True, FIRE_ORANGE)
    screen.blit(f_label, (control_x + 10, control_y + 100))
    
    # Barra de c
    bar_x = control_x + 10
    bar_y = control_y + 125
    bar_width = 200
    bar_height = 20
    
    pygame.draw.rect(screen, LIGHT_GRAY, (bar_x, bar_y, bar_width, bar_height))
    pygame.draw.rect(screen, BLACK, (bar_x, bar_y, bar_width, bar_height), 2)
    pygame.draw.rect(screen, FIRE_ORANGE, (bar_x + 2, bar_y + 2, 
                                           (bar_width - 4) * params.c, bar_height - 4))
    
    # Botões
    # Botão Liga/Desliga
    fire_btn_x = control_x + 230
    fire_btn_y = control_y + 40
    fire_btn_w = 90
    fire_btn_h = 35
    
    color = GREEN if params.fire_on else GRAY
    if mouse_on_fire_btn:
        color = (min(255, color[0]+50), min(255, color[1]+50), min(255, color[2]+50))
    
    pygame.draw.rect(screen, color, (fire_btn_x, fire_btn_y, fire_btn_w, fire_btn_h))
    pygame.draw.rect(screen, BLACK, (fire_btn_x, fire_btn_y, fire_btn_w, fire_btn_h), 2)
    label = font.render("Ligar" if not params.fire_on else "Desligar", True, BLACK)
    screen.blit(label, (fire_btn_x + 10, fire_btn_y + 8))
    
    # Botão + (aumentar c)
    plus_x = control_x + 230
    plus_y = control_y + 85
    plus_w = 40
    plus_h = 40
    
    color = YELLOW if mouse_on_plus_btn else GRAY
    pygame.draw.rect(screen, color, (plus_x, plus_y, plus_w, plus_h))
    pygame.draw.rect(screen, BLACK, (plus_x, plus_y, plus_w, plus_h), 2)
    label = big_font.render("+", True, BLACK)
    screen.blit(label, (plus_x + 10, plus_y + 5))
    
    # Botão - (diminuir c)
    minus_x = control_x + 280
    minus_y = control_y + 85
    minus_w = 40
    minus_h = 40
    
    color = YELLOW if mouse_on_minus_btn else GRAY
    pygame.draw.rect(screen, color, (minus_x, minus_y, minus_w, minus_h))
    pygame.draw.rect(screen, BLACK, (minus_x, minus_y, minus_w, minus_h), 2)
    label = big_font.render("-", True, BLACK)
    screen.blit(label, (minus_x + 12, minus_y + 5))
    
    # Valores atuais do caldeirão
    info_x = 400
    info_y = 400
    info_width = 350
    info_height = 120
    
    pygame.draw.rect(screen, WHITE, (info_x, info_y, info_width, info_height))
    pygame.draw.rect(screen, BLACK, (info_x, info_y, info_width, info_height), 2)
    
    title = title_font.render("Estado Atual", True, BLACK)
    screen.blit(title, (info_x + 10, info_y + 8))
    
    info_text = [
        f"Caldeirão: {params.T:.1f}°C",
        f"Fogo: {params.F:.1f}°C",
        f"c: {params.c:.2f}",
        f"T_amb: {params.T_amb:.1f}°C",
        f"Tempo: {params.time:.1f}s",
        f"dT/dt: {-params.k * (params.T - params.T_amb) + (params.a * (params.F - params.T) if params.fire_on else 0):.3f}°C/s"
    ]
    
    for i, text in enumerate(info_text):
        label = font.render(text, True, BLACK)
        screen.blit(label, (info_x + 10, info_y + 35 + i * 22))
    
    # Barra de temperatura do caldeirão
    temp_x = 400
    temp_y = 535
    temp_w = 350
    temp_h = 25
    
    pygame.draw.rect(screen, WHITE, (temp_x, temp_y, temp_w, temp_h))
    pygame.draw.rect(screen, BLACK, (temp_x, temp_y, temp_w, temp_h), 2)
    
    temp_ratio = (params.T - 20) / 180
    temp_ratio = max(0, min(1, temp_ratio))
    temp_color = (255, int(255 * (1 - temp_ratio)), int(255 * (1 - temp_ratio)))
    pygame.draw.rect(screen, temp_color, (temp_x + 2, temp_y + 2, 
                                          (temp_w - 4) * temp_ratio, temp_h - 4))
    
    temp_label = font.render(f"T = {params.T:.1f}°C", True, BLACK)
    screen.blit(temp_label, (temp_x + temp_w//2 - 40, temp_y + 5))
    
    # Botões de controle
    pause_x = 400
    pause_y = 575
    pause_w = 100
    pause_h = 40
    
    color = YELLOW if paused else GRAY
    pygame.draw.rect(screen, color, (pause_x, pause_y, pause_w, pause_h))
    pygame.draw.rect(screen, BLACK, (pause_x, pause_y, pause_w, pause_h), 2)
    label = title_font.render("Pausa" if not paused else "▶", True, BLACK)
    screen.blit(label, (pause_x + 20, pause_y + 8))
    
    reset_x = 520
    reset_y = 575
    reset_w = 100
    reset_h = 40
    
    pygame.draw.rect(screen, GRAY, (reset_x, reset_y, reset_w, reset_h))
    pygame.draw.rect(screen, BLACK, (reset_x, reset_y, reset_w, reset_h), 2)
    label = title_font.render("Reset", True, BLACK)
    screen.blit(label, (reset_x + 20, reset_y + 8))
    
    # Gráficos
    draw_graphs()
    
    # Instruções
    inst = font.render("Clique + e - para controlar o fogo | Liga/Desliga para ativar | Espaço: Pausa", True, DARK_GRAY)
    screen.blit(inst, (400, 640))

def reset_simulation():
    """Reseta a simulação"""
    params.T = 20.0
    params.c = 0.0
    params.F = 100.0
    params.time = 0.0
    params.fire_on = False
    params.history_T = [params.T]
    params.history_F = [params.F]
    params.history_time = [params.time]

# Loop principal
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        
        # Eventos dos sliders
        for slider in sliders:
            slider.handle_event(event)
        
        if event.type == pygame.MOUSEBUTTONDOWN:
            mouse_x, mouse_y = pygame.mouse.get_pos()
            
            # Botão Liga/Desliga
            if (250 <= mouse_x <= 340) and (340 <= mouse_y <= 375):
                params.fire_on = not params.fire_on
                if not params.fire_on:
                    params.c = 0.0
            
            # Botão +
            if (250 <= mouse_x <= 290) and (385 <= mouse_y <= 425):
                if params.fire_on:
                    params.c = min(1.0, params.c + 0.1)
            
            # Botão -
            if (300 <= mouse_x <= 340) and (385 <= mouse_y <= 425):
                if params.fire_on:
                    params.c = max(0.0, params.c - 0.1)
            
            # Botão Pausa
            if (400 <= mouse_x <= 500) and (575 <= mouse_y <= 615):
                paused = not paused
            
            # Botão Reset
            if (520 <= mouse_x <= 620) and (575 <= mouse_y <= 615):
                reset_simulation()
        
        elif event.type == pygame.MOUSEMOTION:
            mouse_x, mouse_y = pygame.mouse.get_pos()
            mouse_on_fire_btn = (250 <= mouse_x <= 340) and (340 <= mouse_y <= 375)
            mouse_on_plus_btn = (250 <= mouse_x <= 290) and (385 <= mouse_y <= 425)
            mouse_on_minus_btn = (300 <= mouse_x <= 340) and (385 <= mouse_y <= 425)
        
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                paused = not paused
            elif event.key == pygame.K_r:
                reset_simulation()
            elif event.key == pygame.K_f:
                params.fire_on = not params.fire_on
                if not params.fire_on:
                    params.c = 0.0
            elif event.key == pygame.K_UP:
                if params.fire_on:
                    params.c = min(1.0, params.c + 0.05)
            elif event.key == pygame.K_DOWN:
                if params.fire_on:
                    params.c = max(0.0, params.c - 0.05)
    
    # Atualiza sistema
    update_system()
    
    # Desenha interface
    draw_interface()
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
sys.exit()