import pygame
import numpy as np
import math
import random

# ===== PARÂMETROS DO SISTEMA =====
k =     1
hF =    0.01
C =     2
C_F =   2

# Const
T_amb = 20.0
F_eq =  800.0
T_eq =  100.0

h = k * ((F_eq - T_eq) / (T_eq - T_amb)) if (T_eq - T_amb) != 0 else 0
P_comb = k * (F_eq - T_eq) + hF * (F_eq - T_amb)

const_a = 70
const_b = 10

print(f"h = {h:.4f}")
print(f"P_comb = {P_comb:.4f}")

# ===== DERIVADAS =====
def derivadas(T, F):
    dTdt = (k * (F - T) - h * (T - T_amb)) / C
    dFdt = (-k * (F - T) - hF * (F - T_amb) + P_comb) / C_F
    return dTdt, dFdt

# ===== ESTADO INICIAL =====
T = T_amb
F = T_amb

# ===== PARÂMETROS DE TEMPO =====
DT = 0.01
SPEED = 1.0
T_MAX = 120.0
HISTORY_MAX = 20000

# Histórico
t_hist = [0.0]
T_hist = [T]
F_hist = [F]
t_sim = 0.0

# ===== INDICADORES =====
TOL_T = 0.5
TOL_F = TOL_T * 8

t_star_T = None
t_star_T_done = False
t_star_F = None
t_star_F_done = False

t_I0 = None
t_I_star = None

t_A0 = None
t_A_star = None

T_base_A = None
F_base_A = None
T_max_A = None
T_max_A_t = None
T_max_A_done = False
F_max_A = None
F_max_A_t = None
F_max_A_done = False

T_base_I = None
F_base_I = None
T_min_I = None
T_min_I_t = None
T_min_I_done = False
F_min_I = None
F_min_I_t = None
F_min_I_done = False

# ===== PYGAME =====
pygame.init()
WIDTH, HEIGHT = 1100, 640
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Simulação Térmica em Tempo Real")
clock = pygame.time.Clock()

BG = (15, 15, 25)
GRID = (40, 40, 60)
AXIS = (200, 200, 200)
COLOR_T = (255, 100, 100)
COLOR_F = (100, 180, 255)
TEXT_COLOR = (230, 230, 230)
COLOR_MARK_T = (255, 200, 80)
COLOR_MARK_F = (120, 255, 180)
COLOR_PEAK_T = (255, 160, 60)
COLOR_PEAK_F = (200, 100, 255)
COLOR_VALLEY_T = (100, 220, 255)
COLOR_VALLEY_F = (80, 255, 160)

font = pygame.font.SysFont("consolas", 18)
font_small = pygame.font.SysFont("consolas", 13)

# ----- layout do gráfico -----
MARGIN_LEFT = 70
MARGIN_RIGHT = 40
MARGIN_TOP = 60
MARGIN_BOTTOM = 60
PLOT_X = MARGIN_LEFT
PLOT_Y = MARGIN_TOP
PLOT_W = WIDTH - MARGIN_LEFT - MARGIN_RIGHT
PLOT_H = HEIGHT - MARGIN_TOP - MARGIN_BOTTOM

# ----- layout do caldeirão + fogo -----
CAULDRON_W = 100
CAULDRON_H = 90
CAULDRON_X = 190
CAULDRON_Y = 120

FIRE_CX = CAULDRON_X + CAULDRON_W // 2
FIRE_BASE_Y = CAULDRON_Y + CAULDRON_H + 25

y_min_val = 0.0
y_max_val = 2120.0

def to_screen_x(t_val, t_min_view, t_max_view):
    return PLOT_X + (t_val - t_min_view) / (t_max_view - t_min_view) * PLOT_W

def to_screen_y(y_val):
    return PLOT_Y + PLOT_H - (y_val - y_min_val) / (y_max_val - y_min_val) * PLOT_H

# ===== HELPERS =====
def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_color(c1, c2, t):
    t = clamp(t, 0, 1)
    return (int(lerp(c1[0], c2[0], t)),
            int(lerp(c1[1], c2[1], t)),
            int(lerp(c1[2], c2[2], t)))

def draw_fire(surface, cx, base_y, intensity, t):
    """intensity: 0..1 (0=apagado, 1=muito forte)"""
    if intensity < 0.05:
        pygame.draw.ellipse(surface, (40, 30, 25),
                            (cx - 25, base_y - 10, 50, 14))
        return

    if intensity < 0.35:
        layers = [
            (1.00, (120, 30, 5)),
            (0.80, (170, 50, 10)),
            (0.60, (220, 90, 20)),
            (0.40, (255, 150, 40)),
            (0.22, (255, 210, 90)),
        ]
    elif intensity < 0.7:
        layers = [
            (1.00, (180, 50, 10)),
            (0.82, (230, 90, 15)),
            (0.64, (255, 140, 30)),
            (0.46, (255, 200, 60)),
            (0.28, (255, 245, 140)),
        ]
    else:
        layers = [
            (1.00, (230, 70, 10)),
            (0.85, (255, 120, 20)),
            (0.68, (255, 180, 40)),
            (0.50, (255, 225, 90)),
            (0.32, (255, 255, 200)),
        ]

    base_w = 22 + intensity * 30
    base_h = 30 + intensity * 80
    n = 8 + int(intensity * 10)

    for frac, color in layers:
        bw = base_w * frac
        bh = base_h * frac
        pts = []
        for i in range(n):
            a = math.pi * i / (n - 1)
            x = cx - bw * math.cos(a) + math.sin(t * 3 + i * 0.7) * (2 + intensity * 4)
            y = base_y - bh * math.sin(a) * (0.9 + 0.2 * math.sin(t * 5 + i))
            pts.append((x, y))
        pts.append((cx + bw, base_y))
        pts.append((cx - bw, base_y))
        pygame.draw.polygon(surface, color, pts)

    for k in range(5):
        bx = cx + (k - 2) * 7
        pygame.draw.circle(surface, (255, 120, 30), (int(bx), int(base_y)), 3)


def draw_cauldron(surface, x, y, w, h, T_val):
    tn = clamp((T_val - 20) / (240 - 20), 0, 1)

    base_gray = (70, 70, 80)
    hot_red = (230, 60, 30)
    body_color = lerp_color(base_gray, hot_red, tn)

    inner_color = lerp_color((30, 25, 25), (255, 180, 60), tn)

    rect = pygame.Rect(x, y, w, h)
    pygame.draw.rect(surface, body_color, rect, border_radius=12)

    pygame.draw.ellipse(surface, inner_color,
                        (x + 6, y - 6, w - 12, 16))

    pygame.draw.ellipse(surface, (40, 40, 50),
                        (x - 4, y - 12, w + 8, 22), 4)

    pygame.draw.circle(surface, (30, 30, 40),
                       (int(x - 8), int(y + h * 0.35)), 7, 3)
    pygame.draw.circle(surface, (30, 30, 40),
                       (int(x + w + 8), int(y + h * 0.35)), 7, 3)

    label = font_small.render(f"{T_val:.0f}°C", True, (255, 255, 255))
    surface.blit(label, (x + w // 2 - label.get_width() // 2, y - 32))


# ===== SISTEMA DE PARTÍCULAS (BOLHAS) =====
bubbles = []          # cada bolha: [x, y, r, vy, life, alpha]

def spawn_bubble(cx, y_surface, T_val):
    if T_val < 40:
        return
    prob = clamp((T_val - 40) / 200, 0, 1) * 0.5
    if random.random() > prob:
        return
    x = cx + random.uniform(-25, 25)
    r = random.uniform(2, 4) + (T_val - 40) / 200 * 2
    vy = -random.uniform(0.4, 1.0) - (T_val - 40) / 200 * 0.8
    life = random.uniform(1.5, 2.5)
    bubbles.append([x, y_surface, r, vy, life, 1.0])

def update_bubbles():
    for b in bubbles:
        b[1] += b[3]
        b[4] -= 0.016
        b[5] = max(0.0, b[4] / 2.5)
    bubbles[:] = [b for b in bubbles if b[4] > 0 and b[1] > 0]

def draw_bubbles(surface):
    for b in bubbles:
        x, y, r, vy, life, alpha = b
        a = int(180 * alpha)
        if a <= 0:
            continue
        surf_b = pygame.Surface((int(r*2)+4, int(r*2)+4), pygame.SRCALPHA)
        pygame.draw.circle(surf_b, (220, 230, 255, a),
                           (int(r)+2, int(r)+2), int(r))
        pygame.draw.circle(surf_b, (255, 255, 255, min(255, a+40)),
                           (int(r*0.7)+2, int(r*0.7)+2), max(1, int(r*0.4)))
        surface.blit(surf_b, (x - r - 2, y - r - 2))


# ===== LOOP =====
running = True
paused = False
last_flash = {"A": 0, "SPACE": 0}

while running:
    dt_real = clock.tick(60) / 1000.0
    dt_real = min(dt_real, 0.05)
    t_anim = pygame.time.get_ticks() / 1000.0

    # ===== EVENTOS =====
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_a:
                T_base_A = T
                F_base_A = F
                F += const_a
                t_A0 = t_sim
                t_A_star = None
                T_max_A = T
                T_max_A_t = t_sim
                T_max_A_done = False
                F_max_A = F
                F_max_A_t = t_sim
                F_max_A_done = False
                last_flash["A"] = pygame.time.get_ticks()
            elif event.key == pygame.K_SPACE:
                T_base_I = T
                F_base_I = F
                T -= const_b
                t_I0 = t_sim
                t_I_star = None
                T_min_I = T
                T_min_I_t = t_sim
                T_min_I_done = False
                F_min_I = F
                F_min_I_t = t_sim
                F_min_I_done = False
                last_flash["SPACE"] = pygame.time.get_ticks()
            elif event.key == pygame.K_p:
                paused = not paused
            elif event.key == pygame.K_r:
                T = T_amb
                F = T_amb
                t_sim = 0.0
                t_hist = [0.0]
                T_hist = [T]
                F_hist = [F]
                t_star_T = None;  t_star_T_done = False
                t_star_F = None;  t_star_F_done = False
                t_I0 = t_I_star = None
                t_A0 = t_A_star = None
                T_base_A = F_base_A = None
                T_max_A = T_max_A_t = None
                F_max_A = F_max_A_t = None
                T_max_A_done = F_max_A_done = False
                T_base_I = F_base_I = None
                T_min_I = T_min_I_t = None
                F_min_I = F_min_I_t = None
                T_min_I_done = F_min_I_done = False
                bubbles.clear()

    # ===== INTEGRAÇÃO =====
    if not paused:
        sim_time = dt_real * SPEED
        n_steps = max(1, int(sim_time / DT))
        dt_step = sim_time / n_steps
        for _ in range(n_steps):
            dT, dF = derivadas(T, F)
            T += dT * dt_step
            F += dF * dt_step
            t_sim += dt_step
            t_hist.append(t_sim)
            T_hist.append(T)
            F_hist.append(F)

            if not t_star_T_done and abs(T - T_eq) < TOL_T:
                t_star_T = t_sim
                t_star_T_done = True

            if not t_star_F_done and abs(F - F_eq) < TOL_F:
                t_star_F = t_sim
                t_star_F_done = True

            if t_I0 is not None and t_I_star is None and t_sim > t_I0 + DT:
                if abs(T - T_eq) < TOL_T:
                    t_I_star = t_sim

            if t_A0 is not None and t_A_star is None and t_sim > t_A0 + DT:
                if abs(F - F_eq) < TOL_F:
                    t_A_star = t_sim

            if T_max_A is not None:
                if T > T_max_A:
                    T_max_A = T
                    T_max_A_t = t_sim
                if not T_max_A_done and abs(T - T_eq) < TOL_T and t_sim > t_A0 + 0.5:
                    T_max_A_done = True

            if F_max_A is not None:
                if F > F_max_A:
                    F_max_A = F
                    F_max_A_t = t_sim
                if not F_max_A_done and abs(F - F_eq) < TOL_F and t_sim > t_A0 + 0.5:
                    F_max_A_done = True

            if T_min_I is not None:
                if T < T_min_I:
                    T_min_I = T
                    T_min_I_t = t_sim
                if not T_min_I_done and abs(T - T_eq) < TOL_T and t_sim > t_I0 + 0.5:
                    T_min_I_done = True

            if F_min_I is not None:
                if F < F_min_I:
                    F_min_I = F
                    F_min_I_t = t_sim
                if not F_min_I_done and abs(F - F_eq) < TOL_F and t_sim > t_I0 + 0.5:
                    F_min_I_done = True

        if len(t_hist) > HISTORY_MAX:
            cut = len(t_hist) - HISTORY_MAX
            t_hist = t_hist[cut:]
            T_hist = T_hist[cut:]
            F_hist = F_hist[cut:]

    # ===== SPAWN E UPDATE DE BOLHAS =====
    spawn_bubble(CAULDRON_X + CAULDRON_W // 2, CAULDRON_Y + 2, T)
    update_bubbles()

    # ===== DESENHO =====
    screen.fill(BG)
    pygame.draw.rect(screen, (25, 25, 40), (PLOT_X, PLOT_Y, PLOT_W, PLOT_H))

    t_max_view = max(T_MAX, t_sim)
    t_min_view = t_max_view - T_MAX

    n_grid_x = 10
    for i in range(n_grid_x + 1):
        x = PLOT_X + i * PLOT_W / n_grid_x
        pygame.draw.line(screen, GRID, (x, PLOT_Y), (x, PLOT_Y + PLOT_H))
        t_label = t_min_view + i * (t_max_view - t_min_view) / n_grid_x
        label = font_small.render(f"{t_label:.0f}", True, TEXT_COLOR)
        screen.blit(label, (x - label.get_width() // 2, PLOT_Y + PLOT_H + 5))

    n_grid_y = 8
    for i in range(n_grid_y + 1):
        y = PLOT_Y + i * PLOT_H / n_grid_y
        pygame.draw.line(screen, GRID, (PLOT_X, y), (PLOT_X + PLOT_W, y))
        y_label = y_max_val - i * (y_max_val - y_min_val) / n_grid_y
        label = font_small.render(f"{y_label:.0f}", True, TEXT_COLOR)
        screen.blit(label, (PLOT_X - label.get_width() - 8, y - label.get_height() // 2))

    y_Teq = to_screen_y(T_eq)
    y_Feq = to_screen_y(F_eq)
    pygame.draw.line(screen, (120, 60, 60), (PLOT_X, y_Teq), (PLOT_X + PLOT_W, y_Teq), 1)
    pygame.draw.line(screen, (60, 90, 130), (PLOT_X, y_Feq), (PLOT_X + PLOT_W, y_Feq), 1)
    screen.blit(font_small.render(f"T*={T_eq}", True, (200, 130, 130)),
                (PLOT_X + 4, y_Teq - 16))
    screen.blit(font_small.render(f"F*={F_eq}", True, (130, 170, 220)),
                (PLOT_X + 4, y_Feq - 16))

    pygame.draw.line(screen, AXIS, (PLOT_X, PLOT_Y), (PLOT_X, PLOT_Y + PLOT_H), 2)
    pygame.draw.line(screen, AXIS, (PLOT_X, PLOT_Y + PLOT_H),
                     (PLOT_X + PLOT_W, PLOT_Y + PLOT_H), 2)

    pts_T = []
    pts_F = []
    for i in range(len(t_hist)):
        if t_hist[i] >= t_min_view - 1:
            x = to_screen_x(t_hist[i], t_min_view, t_max_view)
            pts_T.append((x, to_screen_y(T_hist[i])))
            pts_F.append((x, to_screen_y(F_hist[i])))

    if len(pts_T) > 1:
        pygame.draw.lines(screen, COLOR_T, False, pts_T, 2)
        pygame.draw.lines(screen, COLOR_F, False, pts_F, 2)

    if pts_T:
        pygame.draw.circle(screen, COLOR_T, pts_T[-1], 5)
        pygame.draw.circle(screen, COLOR_F, pts_F[-1], 5)

    def mark_time(t_val, label, color, y_offset=0, dashed=False):
        if t_val is None or t_val < t_min_view or t_val > t_max_view:
            return
        x = to_screen_x(t_val, t_min_view, t_max_view)
        if dashed:
            y = PLOT_Y
            while y < PLOT_Y + PLOT_H:
                y2 = min(y + 6, PLOT_Y + PLOT_H)
                pygame.draw.line(screen, color, (x, y), (x, y2), 2)
                y += 12
        else:
            pygame.draw.line(screen, color, (x, PLOT_Y), (x, PLOT_Y + PLOT_H), 2)
        surf = font_small.render(label, True, color)
        screen.blit(surf, (x + 3, PLOT_Y + 3 + y_offset))

    mark_time(t_star_T, f"t*T={t_star_T:.2f}" if t_star_T is not None else "",
              COLOR_MARK_T, 0, dashed=False)
    mark_time(t_star_F, f"t*F={t_star_F:.2f}" if t_star_F is not None else "",
              COLOR_MARK_F, 18, dashed=True)
    mark_time(t_I0, f"tI0={t_I0:.2f}" if t_I0 is not None else "",
              (255, 150, 150), 54)
    mark_time(t_I_star, f"tI*={t_I_star:.2f}" if t_I_star is not None else "",
              (255, 150, 150), 54)
    mark_time(t_A0, f"tA0={t_A0:.2f}" if t_A0 is not None else "",
              (150, 200, 255), 72)
    mark_time(t_A_star, f"tA*={t_A_star:.2f}" if t_A_star is not None else "",
              (150, 200, 255), 72)
    mark_time(T_max_A_t, f"tTpA={T_max_A_t:.2f}" if T_max_A_t is not None else "",
              COLOR_PEAK_T, 90)
    mark_time(F_max_A_t, f"tFpA={F_max_A_t:.2f}" if F_max_A_t is not None else "",
              COLOR_PEAK_F, 108)
    mark_time(T_min_I_t, f"tTvI={T_min_I_t:.2f}" if T_min_I_t is not None else "",
              COLOR_VALLEY_T, 126)
    mark_time(F_min_I_t, f"tFvI={F_min_I_t:.2f}" if F_min_I_t is not None else "",
              COLOR_VALLEY_F, 144)

    # ===== CALDEIRÃO + FOGO =====
    if F < T_amb + 50:
        fire_intensity = 0.0
    elif F < 800:
        fire_intensity = 0.35 * (F - (T_amb + 50)) / (800 - (T_amb + 50))
    elif F < 1000:
        fire_intensity = 0.35 + 0.55 * (F - 800) / 200
    else:
        fire_intensity = 0.9 + 0.1 * min(1.0, (F - 1000) / 500)

    draw_fire(screen, FIRE_CX, FIRE_BASE_Y, fire_intensity, t_anim)

    draw_cauldron(screen, CAULDRON_X, CAULDRON_Y,
                  CAULDRON_W, CAULDRON_H, T)

    draw_bubbles(screen)

    lbl_fire = font_small.render(f"F = {F:.0f} °C", True, (255, 200, 150))
    screen.blit(lbl_fire, (FIRE_CX - lbl_fire.get_width() // 2,
                           FIRE_BASE_Y + 12))

    # ===== TÍTULO =====
    title = font.render("Simulação Térmica em Tempo Real", True, TEXT_COLOR)
    screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 15))

    legend_y = 20
    pygame.draw.line(screen, COLOR_T, (WIDTH - 240, legend_y + 8),
                     (WIDTH - 210, legend_y + 8), 3)
    screen.blit(font.render("T(t)", True, COLOR_T), (WIDTH - 205, legend_y))
    pygame.draw.line(screen, COLOR_F, (WIDTH - 240, legend_y + 30),
                     (WIDTH - 210, legend_y + 30), 3)
    screen.blit(font.render("F(t)", True, COLOR_F), (WIDTH - 205, legend_y + 22))

    # ===== PAINEL =====
    def fmt_t(v):
        return f"{v:.2f} s" if v is not None else "—"
    def fmt_C(v):
        return f"{v:.2f}" if v is not None else "—"
    def fmt_d(base, ext):
        if base is None or ext is None:
            return "—"
        return f"{ext - base:+.2f}"

    delta_I = (t_I_star - t_I0) if (t_I0 is not None and t_I_star is not None) else None
    delta_A = (t_A_star - t_A0) if (t_A0 is not None and t_A_star is not None) else None

    info_lines = [
        ("t      = {:7.2f} s".format(t_sim), TEXT_COLOR),
        ("T      = {:7.2f} °C".format(T), TEXT_COLOR),
        ("F      = {:7.2f} °C".format(F), TEXT_COLOR),
        ("h      = {:.3f}".format(h), TEXT_COLOR),
        ("P_comb = {:.3f}".format(P_comb), TEXT_COLOR),
        ("--- t* ---", (200, 200, 200)),
        ("t*T    = " + fmt_t(t_star_T),  COLOR_MARK_T),
        ("t*F    = " + fmt_t(t_star_F),  COLOR_MARK_F),
        ("--- delta I (ESPAÇO) ---", (255, 150, 150)),
        ("dI     = " + fmt_t(delta_I), (255, 220, 220)),
        ("--- delta A (A) ---", (150, 200, 255)),
        ("dA     = " + fmt_t(delta_A), (220, 230, 255)),
        ("--- APÓS A (F +) ---", (200, 200, 200)),
        ("T_max  = " + fmt_C(T_max_A) + " °C", COLOR_PEAK_T),
        ("ΔT_max = " + fmt_d(T_base_A, T_max_A) + " °C", COLOR_PEAK_T),
        ("t_TpA  = " + fmt_t(T_max_A_t), COLOR_PEAK_T),
        ("F_max  = " + fmt_C(F_max_A) + " °C", COLOR_PEAK_F),
        ("ΔF_max = " + fmt_d(F_base_A, F_max_A) + " °C", COLOR_PEAK_F),
        ("t_FpA  = " + fmt_t(F_max_A_t), COLOR_PEAK_F),
        ("--- APÓS ESPAÇO (T −) ---", (200, 200, 200)),
        ("T_min  = " + fmt_C(T_min_I) + " °C", COLOR_VALLEY_T),
        ("ΔT_min = " + fmt_d(T_base_I, T_min_I) + " °C", COLOR_VALLEY_T),
        ("t_TvI  = " + fmt_t(T_min_I_t), COLOR_VALLEY_T),
        ("F_min  = " + fmt_C(F_min_I) + " °C", COLOR_VALLEY_F),
        ("ΔF_min = " + fmt_d(F_base_I, F_min_I) + " °C", COLOR_VALLEY_F),
        ("t_FvI  = " + fmt_t(F_min_I_t), COLOR_VALLEY_F),
    ]
    box_x = PLOT_X + PLOT_W - 260
    box_y = PLOT_Y + 10
    for i, (line, color) in enumerate(info_lines):
        surf = font_small.render(line, True, color)
        screen.blit(surf, (box_x, box_y + i * 15))

    now = pygame.time.get_ticks()
    if now - last_flash["A"] < 200:
        surf = font.render(f"+{const_a} em F", True, (255, 255, 100))
        screen.blit(surf, (PLOT_X + 20, PLOT_Y + 20))
    if now - last_flash["SPACE"] < 200:
        surf = font.render(f"-{const_b} em T", True, (255, 255, 100))
        screen.blit(surf, (PLOT_X + 20, PLOT_Y + 45))

    if paused:
        surf = font.render("PAUSADO", True, (255, 200, 100))
        screen.blit(surf, (WIDTH // 2 - surf.get_width() // 2, PLOT_Y + 10))

    footer = font_small.render(
        "A: +F (pico T e F)   ESPAÇO: -T (vale T e F)   P: pausar   R: reset   ESC: sair",
        True, (150, 150, 150)
    )
    screen.blit(footer, (WIDTH // 2 - footer.get_width() // 2, HEIGHT - 25))

    pygame.display.flip()

pygame.quit()