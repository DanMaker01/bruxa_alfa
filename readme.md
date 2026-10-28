# Jogo da Bruxa

<table>
<tr><td>Engine</td><td>Godot 4</td></tr>
<tr><td>Plataforma</td><td>Android</td></tr>
<tr><td>Resolução</td><td>640 × 960 px</td></tr>
<tr><td>Gênero</td><td>Point & Click</td></tr>
<tr><td>Estilo</td><td>2D Side-scroller</td></tr>
<tr><td>Gameplay</td><td>Exploração + Crafting</td></tr>
<tr><td>Idioma</td><td>Português</td></tr>
</table>

```
Floresta    -   BruxaOut    -   BruxaIn
Bosque
Bosque
CidadeA     -   in01    -   in02    -   in03
EstradaA
Ponte
Castelo     -   in
EstradaB
```

![1788646480585](image/readme/1788646480585.png)![1788646486876](image/readme/1788646486876.png)

## Coisas a fazer

```
  ==============================
||		LEGENDA:	||
||	[ ] A fazer		||
||	[.] Em progresso	||
||	[?] Testar		||
||	[!] Finalizado		||
  ==============================
```

## Terminar logo (0)

```

[.] v3
[?] no debug do caldeirão não consegue mostrar valores altos de F(t), ajuste a escala de F para que alcance as temperaturas máximas do Fogo.
	Feito (grafico_temperatura.gd): eixo F vai até 2000 (fogo mais forte) e cresce sozinho se F passar disso, como o eixo T.
[ ] História / missão: (em ordem)
	[?]	Aumentar o mapa do castelo para 2000, deixar o rei e princesa mais para direita, adaptar tudo ao redor. Os guardaas agora acompanham por um deslocamento maior. Os guardas acompanham a bruxa até perto do trono. Os guardas saem. Espera. A cena centraliza no Rei. Começa o diálogo.
		Feito (castelo_in01_auto): câmera vai até o rei (1552) e volta mais devagar (2,5 s / 2 s); bruxa anda até 1364, guarda1 para um pouco antes (1450) e guarda2 atrás dela (1270); pausa de 0,8 s e os guardas voltam para os postos sem a bruxa esperar; espera 1,5 s; câmera centraliza em 1510 (bruxa, rei e princesa na tela); diálogo. No fim (sem fuga) a câmera volta para a bruxa. Chegada vinda do castelo_in02 agora na porta (1280).
	[?]	Fuga (fuga_castelo): depois do "Prendam-na! AGORA!" pausa curta, a bruxa pensa "Melhor fugir... e aproveitar para pegar o véu.", outra pausa, e ela corre (200 px/s, no máximo a velocidade normal) até a porta do in02, a porta abre (som), ela entra (some), a porta fecha (som), fade e teleporte; ela reaparece no castelo_in02.
	[?]	Véu: pega com pausa (0,5 s antes de mudar missao01_veu, 0,5 s depois) e só então continua o diálogo; vale na fuga (castelo_in03_auto) e nos resultados 1 e 2 (castelo_in03_veu).
	[?]	castelo_in03, guardas sem sucesso: depois do "Parece que ela desapareceu." os dois olham para um lado e para o outro em tempos diferentes (cmd_direcao), continuam olhando enquanto a tela escurece (fade com "esperar" desligado, novo campo no cmd_fade) e vem o teleporte.
		Guardas mais lentos: castelo_in01 150 px/s (a bruxa espera o guarda2 chegar), castelo_in03 130 px/s.
	[?]	Verificação de diálogos e de todos os caminhos possíveis do Cap. 1 (resultados 1 a 5, caso você enrole e chege o dia do casamento, com e sem poção no bolso, voltar à ponte/estradaB depois da fuga, véu pego ou não). Colocar um contador de tempo a partir de quando fala com o Rei para chegar o dia do casamento? Como evitar algo de corrida contra o tempo? Porque ela tem que pegar o véu para continuar o jogo, o que muda é o convite, se não ocorre ou se o rei manda prender a bruxa.
	[] Casamento:
		Decidido: sem prazo no Cap. 1. O casamento só acontece depois que ela entrega a poção e pega o véu; ninguém perde por demorar (sem contador de tempo).
		Não mexi (decidir depois):
		missao01_convite é gravada e nunca lida: fica para o Cap. 2 (convite do casamento).


```

## Terminar até o Cap. 1 (1)

```

[ ] BETA / DEMO:
[ ]		Caldeirão 100%
[ ]		Diálogos 100%
[ ]		Sprites 100%
[ ]		Audio 100%
[ ]		Menus 100%

[] 2ª receita:  - desenvoltura
	Ajustado: musgo t_max 12 → 35 (aguenta os ~30 s finais); flor m 2400 → 5000, s−/s+ 900/1400 → 1900/2900 (Q de 60 s a ~85 °C ≈ 5100). Juntos dão diag(1,1,1.4,1,1) se o musgo entra depois.
	balanceat tempo, u,s-,s+, Tmin,Tmax,tmin,tmax, etc de cada item. infusao


[.]Database (nomes das proibidas ficam para o Cap. 2): Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). Poção da Calma Profunda. Poção #2. Poções proíbidas. 
	Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
	Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
	Poção de Pó de Retorno Concentrada no catálogo, com efeito (teleporte para bruxa_in). Pó: diag(0.97,1,1,1,1.03), cozimento leniente (m 3000, T 60–170, t 10–150, folgas 0,4/0,6).
	Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").


[ ] Bugs/Revisão:
[ ]		Tutorial do caldeirão na 1ª vez.
[!]		Faces em .tres: dados/falantes/*.tres são Personagem (src/dados/personagem.gd): nome + faces com nome ({"normal": ..., "pensando": ...}; a primeira é a padrão). O lado da tela não fica no personagem.
			Mostrar mensagem / Mostrar opções: personagem, face ("" = a primeira) e posicao (0 = esquerda, 100 = direita) em cada fala. As 201 falas convertidas (bruxa 0, os outros 100, guarda2 50 numa fala; pensamentos da bruxa com face "pensando").
			Posição: menu "(padrão)" / "escolher posição" no inspetor (no arquivo, posicao -1 = padrão). (padrão) repete a última posição em que aquele personagem falou (0 na primeira vez); qualquer outro valor vira a nova posição lembrada dele. Cada personagem lembra a sua.
			[nome;foto;pos] no começo do texto continua valendo, com prioridade.
			Personagens: bruxa (normal, pensando), campones, desconhecido (???), guarda1, guarda2, princesa, rei. bruxa_pensando.tres ficou sem uso: pode apagar.
[ ]		Variações no flip card. (depois) Sorteadas: normal = 1 flip diagonal; variações no mesmo tempo: 5 flips com velocidade decrescente; flip mudando a dimensão horizontal, com 1 ou 5 flips.


[ ]	Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
[ ]		(Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
[ ]		(Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.


[ ]	Escrita/Estilo:
[ ]		Diálogos devem condizer com a época
[ ]		Cada personagem tem seu linguajar próprio e manias.

[ ]	Cena Livro de Receitas: (DEPOIS DO CAP. 1)
[ ]		Ao criar uma poção nova a bruxa tem opção de anotar a receita no livro. Caso escolha anotar: Abre a cena do livro de receitas já anotando.
[ ]		Iniciar o livro de receitas, cena com janela que inicia após uma nova receita. A cena de livro abre e é escrita uma nova receita.
[ ]		Pensar no Layout
[ ]		Uma receita por página, 2 páginas por folha, mostra o livro aberto e tem opção de controlar com clique ou arrastando, é redundante para melhor UX.
[ ]		Ao clicar numa página mostra seus ingredientes e tempo relacionado com seu gráfico, seu resultado.
[ ]		Fazer tudo bem animado e temático de bruxaria.


[.] Itens:
[?]		Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
				Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.


[ ]	Caldeirão:
[ ]		Tutorial(leve) na primeira vez. (DEPOIS DO CAP. 1) (cozinhar apenas 1 ou 2 itens.)

[ ] Mapa:
[.]         Remover todos eventos placeholders de item dos mapas
				Removidos os 6 cogumelos de teste (teste_magia) de bruxa_out e castelo_out. Fica só o da história (estradaA). teste_magia.tres sem uso.
[.]     Resolver problema de área de colisão, verificar cada evento, posição, etc.
[?]		Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários? (câmera com borda suave; CamadaParallax na ponte)
[.]		Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
[?]		Testar loop de bgm, loop de bgs. (floresta.mp3 já está com loop=true no import)
[?]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
			Feito: mapa_base tem bgm/bgm_volume no Inspector. Mesmo bgm = continua; outro = troca; vazio = para. Só a floresta tem bgm (floresta.mp3).
[ ]	Verificar todos os parallaxes (valores, direção, bordas).

[.]	HUD/inventário:
		Feito (1ª versão): src/ui/carta.gd + hud.tscn refeito. Duas cartas: CartaInventario (Verso/Inventario/Dialogo) e CartaStatus (Verso/Status/Opcoes).
		Toque no verso abre; 4 s sem tocar na carta (nem popup do item aberto) desvira. Independentes. Fechada ocupa o mesmo espaço.
		Diálogo/opções: DialogBox e OptionBox vão para dentro das cartas (face de prioridade); a carta vira sozinha e volta para onde estava.
		mostrar_hud/sumir_hud: ativa/desativa as cartas (inativas somem, mas aparecem no diálogo).
		Virada na diagonal (angulo_diagonal 45°), sem pulinho. Conteúdo vai para um Node2D "Giro" no _ready: use carta.face("Nome").
		Margens (hud.gd): MARGEM_CARTA = 14 entre a carta e a caixa preta (painel do diálogo, botões das opções e avançar, todos iguais); MARGEM_CONTEUDO = 20 entre a caixa preta e o texto.
		Foto e nome do falante ficam fora da carta (CanvasLayer): não giram, fade só quando mudam.
		Ajustar: tempo_aberta, tempo_virar, angulo_diagonal (Inspector da carta).
		Verso provisório: pentagrama desenhado (src/ui/pentagrama_verso.gd, gira devagar; cor/espessura/raio/giro no Inspector). Trocar pela arte quando existir.

[?] Parallax e câmera nas bordas (juntos):
	Como está: câmera presa entre 0 e a borda direita da maior imagem do "Meio" (mapa_base). Parallax simples: cada camada só segue a câmera pelo seu fator (fundo 0.2, meio 1.0, frente 1.1, interiores "Frente+" 0.9). SUAVIZAR = false (câmera sem suavização).
	Decidido: o mais simples. Na borda a câmera para e todas as camadas param junto (PARALLAX_NA_BORDA = false, BRUXA_NO_CENTRO = false, BORDA_SUAVE = 0). Testados e descartados: camadas continuando na borda (tranco), freio suave da câmera (quebra a ilusão), bruxa parando antes da ponta (encurtava os mapas). O código ficou desligado, cada um com sua constante.
	Regra das imagens (para não aparecer cinza): camada sem loop precisa de largura ≥ 640 + fator × (largura do mapa − 640). Ex.: Frente 1.1 em mapa de 6000 px = 6536 px (ou scale x 1.09). Mapas maiores não são necessários.
	Por camada: bosque (Meio chão 1.0, Frente árvores 1.1, scale 1.07); bruxa_out (Fundo 0.2, casa no Meio); castelo_in03 (Fundo 0.2, Frente 1.1, scale 1.051); castelo_out (Fundo 0.2, Frente 1.1); cidadeA, estradaA, estradaB (Fundo 0.2); ponte (Fundo4 céu, Fundo3 nuvens longe pan -6, Fundo2 montanha, Fundo nuvens pan -12, todos 0.2; Meio/Meio2/Meio3 1.0; Frente nuvens 1.1 pan -40).


[ ]     Fazer sprite:
[ ]         inventário e status de costas (card que gira)


[ ] Audio:
[ ]     Fazer músicas: 
[ ]         intro, 
[ ]         casa bruxa, 
[?]         floresta, 
[ ]         estradas, 
[ ]			ponte (ouvir ost: ragnarok, pokemon, nobuo uematsu)
[ ]         castelo, 
[ ]         ...
[ ]	Fazer sons:
[ ]		Teleport entre mapas
[ ]		Flip card
[ ]		Efeitos (...)

[ ]	Animações:
[ ]


[ ] Estilo:
[ ] 	organizar o layout e textura dialogo/opções
[ ]		Ajuste estético, borda, cor, fonte, etc.
[ ]		Criação de estilos padronizados para cada coisa. (?) tipo estilo texto, estilo menu, ...?
[ ]


[ ]	Estudar se vale:
[ ]		- Definir posição dos eventos no mapa, tudo por código


[ ]	Menu Principal e Pausa (DEPOIS DO CAP. 1)
[ ]	Save/Load (DEPOIS: muita coisa ainda pode mudar)
[ ]		Game_Temp deve ter save e load de arquivo_unico de titulo "save"+time_stamp
[ ]		GameTemp, posição player, mapa
[?]	Animações do player e eventos melhor organizada e testes.

[ ]	Core:
[ ]		Modularizar evento_base (ainda precisa?)
[ ]   Melhorias estruturais no sistema.
```

## Terminar até o Cap. 2 (2)

```
[ ] Sistema de clima
[ ]	Sistema de mercado/valor dinâmico
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
```
