# 🧙‍♀️ Jogo Bruxa

> Um jogo narrativo de alquimia e decisões entre o mundo dos vivos e dos mortos.

---

## 📌 Info

| Prop.       | Val.          |
| ----------- | ------------- |
| Engine      | Godot         |
| Plataforma  | Android       |
| Resolução | 640 x 960     |
| Gênero     | Point & Click |

---

## 🏗️ Estrutura de Jogo

```
MAIN
├── GameManager (game_manager.gd)
│   ├── DatabaseManager (database_manager.gd)  ← Lê database.json
│   ├── AudioManager
│   ├── Interpeter
│   └── GameTemp                              ← Estado: vars, pers, inventario
│
├── CanvasLayer
│   ├── HUD
│   │   ├── Inventario
│   │   │   ├── Panel
│   │   │   ├── GridContainer → Slot1, Slot2
│   │   │   ├── InfoItem (Label)
│   │   │   └── TextureRect (frame.png)
│   │   ├── ColorRect2 (fundo)
│   │   └── Label (Bruxa stats)
│   │
│   ├── PauseMenu
│   │   ├── Background
│   │   ├── VBoxContainer
│   │   │   ├── Continuar → GameManager._on_continuar_pressed
│   │   │   ├── Opcoes
│   │   │   └── Sair → GameManager._on_sair_pressed
│   │   └── Label
│   │
│   ├── Notificacao
│   │   └── Container → NotificacaoItem (Panel)
│   │
│   ├── CenaPreparo (invisível)
│   │   ├── Background
│   │   ├── CenterContainer
│   │   │   └── VBoxContainer
│   │   │       ├── Animation (AnimatedSprite2D)
│   │   │       ├── Graph (Control)
│   │   │       └── HBoxContainer
│   │   │           ├── LeftButton
│   │   │           ├── ListaHorizontal
│   │   │           └── RightButton
│   │   └── Label
│   │
│   └── MenuPrincipal (invisível)
│       ├── TextureRect
│       ├── VBoxContainer
│       │   ├── Iniciar
│       │   ├── Carregar
│       │   ├── Opções
│       │   └── Sair
│       ├── Label (título)
│       └── Label2
│
└── Mundo
	├── Player (CharacterBody2D)
	│   ├── Camera2D
	│   ├── Sprite2D (player_parado.png)
	│   ├── CollisionShape2D
	│   ├── AnimationTree
	│   └── AnimationPlayer
	└── MapaFlorestaA (instância)
```

---

## 🗺️ Mapa

MIRO:

---

Cap1: https://miro.com/app/board/uXjVHHRQsyM=/

Cap2: ...

Cap3: ...

---

## Relações no Mapa

Corrigir os objetivos do Jogador*****

Avaliar os Elementos Principais ******

Avaliar as Funções de Jogo*****

| ID    | Cena              | Dimensão Aproximada | Conecta com         | Função no Jogo                 | Elementos Principais                    | Objetivo do Jogador                             |
| ----- | ----------------- | -------------------: | ------------------- | -------------------------------- | --------------------------------------- | ----------------------------------------------- |
| 1     | Floresta          |              8000 px | 1.1, 2, 7           | Exploração principal           | Árvores, ervas, ingredientes, inimigos | Coletar recursos e avançar                     |
| 1.1   | BruxaOut          |              1280 px | 1, 1.1.1            | Área externa da base            | Casa, árvore, jardim                   | Acessar a casa da bruxa ou retornar à floresta |
| 1.1.1 | BruxaIn           |              1280 px | 1.1                 | Base inicial                     | Caldeirão, mesa, itens de alquimia     | Criar poções e interagir com o caldeirão     |
| 2     | Bosque            |              2000 px | 1, 3                | Área de transição             | Vegetação mais aberta                 | Chegar à cidade                                |
| 3     | CidadeA           |              5000 px | 2, 3.1, 3.2, 3.3, 4 | Hub social                       | NPCs, casas, lojas, diálogos           | Conversar com NPCs e receber missões           |
| 3.1   | CasaNPC1          |   1280 px (estimado) | 3                   | Interior de NPC                  | Comerciante ou morador                  | Obter itens ou informações                    |
| 3.2   | CasaNPC2          |   1280 px (estimado) | 3                   | Interior de NPC                  | Morador ou alquimista                   | Completar uma missão                           |
| 3.3   | CasaNPC3          |   1280 px (estimado) | 3                   | Interior de NPC                  | Personagem especial                     | Desbloquear recompensas                         |
| 4     | Estrada           |   2000 px (estimado) | 3, 5                | Estrada principal após a cidade | Caminho aberto                          | Prosseguir até a ponte                         |
| 5     | Ponte             |              2000 px | 4, 6                | Evento intermediário            | Ponte, rio                              | Superar um desafio ou checkpoint                |
| 6     | CasteloOut        |              3000 px | 5, 6.1, 7           | Exterior do castelo              | Muralhas, portão                       | Entrar no castelo                               |
| 6.1   | CasteloIn         |              2500 px | 6                   | Clímax da aventura              | Salões, guardas, chefe final           | Concluir a missão principal                    |
| 7     | EstradaSecundaria |   2000 px (estimado) | 1, 6                | Atalho entre floresta e castelo  | Caminho alternativo                     | Acessar rapidamente o castelo                   |

---

## 📖 História

### 🌌 Contexto / Mundo

Cenário: Europa Medieval

> Entre o mundo dos vivos e o mundo dos mortos existe um fino véu que os separa. Para a maioria das pessoas esse véu é imperceptível, mas aqueles que têm contato com a magia podem ver através.

> A cada dia que passa o mundo dos mortos está mais cheio e alguns espíritos, por vontade ou acaso, acabam chegando tão perto do véu que interferem no mundo dos vivos.

> A Bruxa [............], se mudou para perto da cidade a pouco tempo, ela veio para descansar. Porém, os mortos e vivos têm problemas diversos e ficam te chamando toda hora para fazer poções para eles.

> Para as poções são necessários ingredientes de lugares diversos, então a bruxa resolveu pendurar na sua porta, um pedaço do véu entre mundos, assim não precisará perder tempo ou importar ingredientes caros.

> Foram 4 dias para a criação da casa. Um dia para para cortar as madeiras. Outro para montar a casa. Um dia para pegar um pedaço do véu. E o último dia, para preparar os móveis e encantamentos. Assim a casa estava pronta e a bruxa pôde descansar.

### 🌫️ Intro

Cenário: Casa da bruxa (na floresta), manhã com névoa:

> A neblina ainda dança entre os pinheiros quando os primeiros sinos de argila pendurados na porta soam. Por dentro da casa, frascos coloridos repousam em prateleiras tortas, raízes secando pendem do teto, e um caldeirão fumegante com uma mistura esverdeada. O cheiro é de hortelã, enxofre e terra úmida.

> Você, a bruxa, está próxima à mesa, enrolando rabos de salamandra quando a porta se abre com um rangido lento. Um jovem camponês entra, com chapéu nas mãos e os olhos baixos.

<protótipo>

> "Dona… minha irmã vai se casar amanhã, mas ela perdeu a voz. Pode nos ajudar?"

</protótipo>

> Você se levanta, pega um livro pesado com fecho de ossos e o abre sobre a mesa. A luz das velas tremula. Um menu aparece com ingredientes possíveis: mel de fada, língua de tritão, eco de caverna, orvalho de flor da manhã, etc…

## Parte jogável

### 🏰 Capítulo 1

* Cenário: Cidade A / Bosque / Castelo
* Missão: curar doença misteriosa no castelo

> (roteiro)

### 🏙️ Capítulo 2

* Cenário: Cidade B
* Missão: (...)

> (roteiro)

### 💀 Capítulo 3

* Cenário: Mundo dos Mortos
* Missão: enganar o diabo, eventos ambíguos

> (roteiro)

---

## 🔁 Fluxo de Missões

```
Idle
 ↓
Visitante chega
 ↓
História (3 mensagens no máx)
 ↓
Investigação (diálogo, NPC, livro, ...)
 ↓
Explorar mapa/pegar ingredientes
 ↓
 
Criação de poção
 ↓
Resultado (curar/falhar)
 ↓
Conclusão
 ↓
Idle
```

---

## 🧱 Layout

```
Tela (640x960)

┌─────────────────────────┐
│                         │
│    Cena (640x640)       │
│                         │
│                         │
│                         │
│                         │
│         (60%)           │
│                         │
├─────────────────────────┤
│         (40%)           │
│                         │
│               |         │
│ Texto (60%)   |Opções40%│
│               |         │
└─────────────────────────┘
```

---

## ⚙️ Mecânicas

### 🎮 Oficial

* Sistema de preparar poções
* Escolhas com consequências
* Portas mágicas
* Personalidade

$$
x \in \mathbb{R}^5
$$

* Poção:

$$
f(x) = Ax + b
$$

---

### 🧪 Brainstorm (possiveis mecânicas)

```
Legenda:
(-1) = fazer urgente
(0) = fazer logo
(1) = fazer depois do cap 1
(2) = fazer depois do cap 2
(...)
-----------------------------------
(-1) 
- implementar sistemas basicos (dialogo, escolhas, preparo poção, interação, save) 
- fazer testes ostensivos

(0) 
- terminar cap 1 

(1)
- Clima / tempo (terminar primeiro o capítulo 1)
- Economia (compra/venda ou valor dinâmico) (trabalhoso)
- Fama / inveja (se sobrar tempo)
- Equipamentos de alquimia (para melhorar poção?)
- HP? 
- Personalidade de todos seres/jogar poção em qqr ser.

(2)
- NPCs auxiliares (pra q?) 
- FadeOut/In circular com raio crescendo/descrescendo, mirando num ponto.
```

### 🧾 Interpreter

Comandos (estilo RPG Maker)

```
[ ]		wait(tempo)
[ ]		label(nome)
[ ]		goto(nome)
[ ]		if / else (condicao)
[ ]		while(condicao)
[ ]		break_loop

[x]		mostrar_texto(texto)
[ ]		mostrar_opcoes(opcoes,desfechos,cancel)

[x]		mudar_variavel(id,operacao,valor)
[ ]		mudar_personalidade(id,operacao, novo_p)
[ ]		mudar_item(id,operacao, qtd)

[ ]		teleport(map_id, x, y, direcao)
[ ]		chamar_evento(id, forcar_pagina) 
[ ]		move_evento()
[ ]		move_camera(pos,tempo)
[ ]		treme_camera(intensidade,freq,tempo)
[ ]		mudar_cor_tela(cor,tempo)

[ ]		mostrar_animacao(id, anima,x,y,origem,sx,sy,alfa)
[ ]		mover_animacao(id,t,x,y,origem,sx,sy,alfa)
[ ]		apagar_animacao(id)
[ ]		tocar_som(nome, vol)
[ ]		tocar_musica(nome, vol)
```

---
