
# Catálogo de Itens — Cozinha da Bruxa

## Ordem dos traços

`[O, C, E, A, N]`

- **O** = Abertura (curiosidade, mente aberta)
- **C** = Conscienciosidade (ordem, disciplina)
- **E** = Extroversão (sociabilidade, energia)
- **A** = Amabilidade (cooperação, gentileza)
- **N** = Neuroticismo (ansiedade, medo)

## Convenções

- Diagonal: 0.85–1.15
- Fora da diagonal: -0.02–0.02
- Um item tem no máximo 2 traços com efeito não-trivial (exceto exceções marcadas)
- `m = 0`, `s_menos = 0`, `s_mais = 0` → não cozinha
- `T_min = 0`, `T_max = 999` → sem limite de temperatura
- `t_min = 0`, `t_max = 999` → sem limite de tempo

---

## Itens existentes

| Item               | Matriz                              | Efeito                       | Lógica                 |
| ------------------ | ----------------------------------- | ---------------------------- | ----------------------- |
| **Arroz**    | identidade                          | nenhum                       | base neutra             |
| **Erva**     | C × 0.9283, E × 0.9283            | desorganizar leve            | amarga, relaxa          |
| **Cogumelo** | C × 1.077, E × 1.077, N × 0.9283 | enrijecer + agitar + acalmar | energia, foco, calma    |
| **Sal**      | O × 0.95, C × 1.05, C += 0.01·O  | conservar + realçar         | conserva, fecha, ordena |
| **Água**    | C × 0.98                           | desorganizar leve            | dissolve, evapora       |
| **Maçã**   | A × 1.05                           | adoçar                      | doçura, gentileza      |

---

## Efeitos psicológicos disponíveis

### Simples (diagonal)

| Efeito         | Matriz   | Traço |
| -------------- | -------- | ------ |
| Acalmar        | N × 0.9 | N↓    |
| Enrijecer      | C × 1.1 | C↑    |
| Fechar a mente | O × 0.9 | O↓    |
| Abrir a mente  | O × 1.1 | O↑    |
| Adoçar        | A × 1.1 | A↑    |
| Endurecer      | A × 0.9 | A↓    |
| Agitar         | E × 1.1 | E↑    |
| Silenciar      | E × 0.9 | E↓    |
| Desorganizar   | C × 0.9 | C↓    |
| Instabilizar   | N × 1.1 | N↑    |

### Duplos

| Efeito          | Matriz               |
| --------------- | -------------------- |
| Conservar       | C × 1.05, O × 0.95 |
| Amolecer        | A × 1.05, C × 0.95 |
| Encorajar       | E × 1.05, N × 0.95 |
| Focar           | C × 1.05, E × 0.95 |
| Serenar         | N × 0.95, E × 0.95 |
| Inspirar        | O × 1.05, E × 1.05 |
| Proteger        | C × 1.05, A × 1.05 |
| Libertar        | O × 1.05, C × 0.95 |
| Adoçar a mente | A × 1.05, O × 1.05 |

### Acoplamento (fora da diagonal)

| Efeito                  | Matriz                   |
| ----------------------- | ------------------------ |
| Realçar                | C += 0.01·O             |
| Contagiar               | E += 0.01·A             |
| Acalmar os ansiosos     | N × 0.9, N += 0.005·C  |
| Fechar os curiosos      | O × 0.9, O += 0.005·E  |
| Amolecer os rígidos    | C × 0.95, C += 0.005·A |
| Enrijecer os instáveis | C × 1.05, C += 0.01·N  |

### Rotação (troca de traços)

| Efeito        | Matriz       |
| ------------- | ------------ |
| Inverter E↔A | rotação 2D |
| Trocar O↔E   | rotação 2D |
| Espelhar C↔N | rotação 2D |
| Cruzar O↔A   | rotação 2D |

### Bloco (subespaço)

| Efeito           | Matriz                        |
| ---------------- | ----------------------------- |
| Ativar           | O, C, E × 1.05               |
| Acalmar o social | A, N × 0.95                  |
| Equilibrar       | O, C × 0.95; E, A × 1.05    |
| Focar no eu      | O, N × 1.05; C, E, A × 0.95 |

### Jordan (cascata)

| Efeito               | Matriz                     |
| -------------------- | -------------------------- |
| Cascata de ordem     | C += 0.01·E, E += 0.01·O |
| Cascata de medo      | N += 0.01·C, C += 0.01·O |
| Cascata de gentileza | A += 0.01·E, E += 0.01·O |

---

## Novos itens — Diagonal simples

### Mel

- **Efeito:** adoçar forte
- **Matriz:** A × 1.10
- **Lógica culinária:** doçura pura, viscoso, conserva
- **Lógica psicológica:** amabilidade, gentileza, acolhimento
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 999`

### Pimenta

- **Efeito:** agitar + instabilizar
- **Matriz:** E × 1.08, N × 1.05
- **Lógica culinária:** ardência, calor, energia
- **Lógica psicológica:** extroversão, nervosismo
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 999`

### Camomila

- **Efeito:** serenar
- **Matriz:** N × 0.90, E × 0.95
- **Lógica culinária:** chá calmante, flor
- **Lógica psicológica:** reduz ansiedade, reduz energia
- **Cozimento:** infusão, calor médio
  - `m = 1200`, `s_menos = 400`, `s_mais = 600`
  - `T_min = 60`, `T_max = 100`
  - `t_min = 30`, `t_max = 120`

### Café

- **Efeito:** focar + agitar + instabilizar
- **Matriz:** C × 1.05, E × 1.08, N × 1.03
- **Lógica culinária:** amargo, estimulante
- **Lógica psicológica:** foco, energia, ansiedade
- **Cozimento:** torra, calor alto
  - `m = 2500`, `s_menos = 500`, `s_mais = 700`
  - `T_min = 150`, `T_max = 250`
  - `t_min = 60`, `t_max = 180`

### Alho

- **Efeito:** proteger
- **Matriz:** C × 1.05, A × 1.05
- **Lógica culinária:** tempero forte, conserva, afasta
- **Lógica psicológica:** ordem, cooperação, proteção
- **Cozimento:** refogar, calor médio
  - `m = 1000`, `s_menos = 300`, `s_mais = 500`
  - `T_min = 80`, `T_max = 150`
  - `t_min = 20`, `t_max = 60`

### Orvalho

- **Efeito:** inspirar
- **Matriz:** O × 1.05, E × 1.05
- **Lógica culinária:** frescor, pureza, manhã
- **Lógica psicológica:** curiosidade, energia
- **Cozimento:** evapora fácil
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 60`
  - `t_min = 0`, `t_max = 30`

### Cinza

- **Efeito:** desorganizar + fechar
- **Matriz:** C × 0.95, O × 0.95
- **Lógica culinária:** resíduo, fim, destruição
- **Lógica psicológica:** caos, mente fechada
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 999`

### Vinagre

- **Efeito:** endurecer + fechar
- **Matriz:** A × 0.95, O × 0.95
- **Lógica culinária:** acidez, conserva, corta
- **Lógica psicológica:** inflexibilidade, mente fechada
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 999`

### Açúcar

- **Efeito:** adoçar + agitar
- **Matriz:** A × 1.08, E × 1.05
- **Lógica culinária:** doçura, energia rápida
- **Lógica psicológica:** gentileza, energia
- **Cozimento:** carameliza, calor alto
  - `m = 1800`, `s_menos = 400`, `s_mais = 800`
  - `T_min = 120`, `T_max = 200`
  - `t_min = 30`, `t_max = 120`

### Sal grosso

- **Efeito:** conservar forte
- **Matriz:** C × 1.08, O × 0.92
- **Lógica culinária:** conserva intensa, cristais
- **Lógica psicológica:** rigidez, mente fechada
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 45`

---

## Novos itens — Diagonal dupla

### Amora

- **Efeito:** amolecer
- **Matriz:** A × 1.05, C × 0.95
- **Lógica culinária:** fruta mole, doce, escura
- **Lógica psicológica:** gentileza, menos rigidez
- **Cozimento:** amolece rápido, oxida
  - `m = 800`, `s_menos = 300`, `s_mais = 500`
  - `T_min = 50`, `T_max = 100`
  - `t_min = 20`, `t_max = 60`

### Gengibre

- **Efeito:** encorajar
- **Matriz:** E × 1.05, N × 0.95
- **Lógica culinária:** picante, aquece, revigora
- **Lógica psicológica:** energia, menos medo
- **Cozimento:** infusão, calor médio
  - `m = 1200`, `s_menos = 400`, `s_mais = 600`
  - `T_min = 70`, `T_max = 120`
  - `t_min = 30`, `t_max = 90`

### Hortelã

- **Efeito:** focar
- **Matriz:** C × 1.05, E × 0.95
- **Lógica culinária:** refrescante, mentolado
- **Lógica psicológica:** disciplina, menos distração
- **Cozimento:** infusão, calor baixo
  - `m = 800`, `s_menos = 300`, `s_mais = 500`
  - `T_min = 50`, `T_max = 90`
  - `t_min = 20`, `t_max = 60`

### Lavanda

- **Efeito:** serenar
- **Matriz:** N × 0.95, E × 0.95
- **Lógica culinária:** floral, calmante
- **Lógica psicológica:** calma, quietude
- **Cozimento:** infusão, calor baixo
  - `m = 600`, `s_menos = 250`, `s_mais = 400`
  - `T_min = 40`, `T_max = 80`
  - `t_min = 20`, `t_max = 60`

### Canela

- **Efeito:** inspirar
- **Matriz:** O × 1.05, E × 1.05
- **Lógica culinária:** especiaria doce, aroma
- **Lógica psicológica:** curiosidade, energia
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 999`

### Cebola

- **Efeito:** proteger
- **Matriz:** C × 1.05, A × 1.05
- **Lógica culinária:** camadas, conserva, afasta
- **Lógica psicológica:** ordem, cooperação
- **Cozimento:** refogar, calor médio
  - `m = 1000`, `s_menos = 300`, `s_mais = 500`
  - `T_min = 80`, `T_max = 140`
  - `t_min = 30`, `t_max = 90`

### Limão

- **Efeito:** libertar
- **Matriz:** O × 1.05, C × 0.95
- **Lógica culinária:** ácido, corta, refresca
- **Lógica psicológica:** abertura, menos rigidez
- **Cozimento:** não cozinha
  - `m = 0`, `s_menos = 0`, `s_mais = 0`
  - `T_min = 0`, `T_max = 999`
  - `t_min = 0`, `t_max = 999`

### Tomilho

- **Efeito:** adoçar a mente
- **Matriz:** A × 1.05, O × 1.05
- **Lógica culinária:** erva aromática, suave
- **Lógica psicológica:** gentileza, curiosidade
- **Cozimento:** refogar, calor médio
  - `m = 900`, `s_menos = 300`, `s_mais = 500`
  - `T_min = 70`, `T_max = 120`
  - `t_min = 20`, `t_max = 60`

---

## Novos itens — Acoplamento

### Fermento

- **Efeito:** cascata de gentileza
- **Matriz:**
