# Jogo da Bruxa

![1793375384971](image/readme/1793375384971.png)

![1793377160839](image/readme/1793377160839.png)

![1793375398241](image/readme/1793375398241.png)

MAPA: https://miro.com/app/board/uXjVHHRQsyM=/

# Coisas a fazer

```
  ==============================
||		LEGENDA:	||
||	[ ] A fazer		||
||	[.] Em progresso	||
||	[?] Testar		||
||	[!] Finalizado		||
  ==============================
```

## Terminar até o Cap. 1 (1)

```

[ ] Sprites 100%
	[ ] Faces
		[ ] Bruxa
			[ ] neutro
			[ ] pensando
		[ ] Rei
			[ ] neutro
			[ ] furioso
		[ ] Princesa
			[ ] neutro
		[ ] Guarda1
		[ ] Guarda2
		[ ] NPC1 - Criança
			[ ] neutro
		[ ] NPC2 - Criança
			[ ] neutro
		[ ] NPC3 - Adulto
			[ ] neutro
		[ ] Goblin
			[ ] neutro
		[ ] Padre
			[ ] neutro
	[ ] Sprites
		[ ] Bruxa
			[ ] parada
			[ ] andando
		[ ] Rei
		[ ] Princesa
		[ ] Guarda1
			[ ] parado
			[ ] andando
		[ ] Guarda2
			[ ] parado
			[ ] andando
		[ ] NPC1 - Criança
			[ ] parado
			[ ] andando
		[ ] NPC2 - Criança
			[ ] parado
			[ ] andando
		[ ] NPC3 - Adulto
			[ ] parado
		[ ] Mercador pai
			[ ] parado
		[ ] Mercador filho
			[ ] parado
		[ ] Padre
			[ ] parado
		[ ] Portas
			[ ] porta padrão
			[ ] porta bruxa
			[ ] portão castelo
		[ ] Objetos
			[ ] 
	[ ] Cenários
		[ ] floresta
		[ ] bruxa_in
		[ ] bruxa_out1
		[ ] bruxa_out2
		[ ] bruxa_out3
		[ ] bosque
		[ ] cidade
		[ ] cidade_in01
		[ ] cidade_in02
		[ ] cidade_in03 (será aumentado)
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01 (será aumentado)
		[ ] castelo_in02
		[ ] castelo_in03
		[ ] estrada_b

[ ]	Audio 100%
	[ ] BGM
		[ ] intro (xxxHolic opening)
		[ ] floresta
		[ ] bruxa_out1
		[ ] bruxa_out2
		[ ] bruxa_out3
		[ ] bruxa_in
		[ ] bosque
		[ ] cidade
		[ ] cidade_in01
		[ ] cidade_in02
		[ ] cidade_in03
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01
		[ ] castelo_in02
		[ ] castelo_in03
		[ ] estrada_b
	[ ] BGS
		[ ] tremor
		[ ] passaros
		[ ] grilo
	[ ] SE
		[ ] porta01
		[ ] porta02
		[ ] passos
		[ ] pulo
		[ ] dash
		[ ] magia01
		[ ] magia02
		[ ] magia03
		[ ] pancada01
		[ ] pancada02
		[ ] corte01
		[ ] corte02
		[ ] vidro01
		[ ] vidro02
		[ ] flip card
		[ ] aplausos
		
[ ]	Menus 100%
	[ ] estilo das cartas
	[ ] inicial
		[ ] start, load, config, sair
	[ ] pause
		[ ] continuar, save, load, menu principal
	[ ] caldeirão
		[ ] bruxa, caldeirão, botões, inventário
	[ ] loja
		[ ] completa

[ ] Diálogos 100%
	[ ] Intro: melhorar texto (tempo e ritmo).
	[ ] Revisão de cada evento.
	[ ] Balão de expressão por sprite: precisa da arte (1 sprite de balão, se der pra fazer sem deformar as quinas seria ideal)

[ ] Caldeirão 100%
	[ ] Menus, botões
		[?] Botão de ingrediente: afunda e clareia ao encostar o dedo (antes não reagia). Continua lançando ao soltar, para não atrapalhar a rolagem da lista.
		[ ] Reformular Layout (pensar em celular)
	[ ] Poções balanceadas
	[ ] Feedback bom pra temperatura do caldeirão, tanto frio quanto quente
		[?] Ícone do ingrediente quente/frio: antes eram degraus (nada até 5% do limite; 30% de cor até o limite; 65% depois), por isso ficava vermelho de repente.
			Agora (padrão FOLGA): a cor começa antes do limite na distância da folga do ingrediente ((1 − k_max)·T_max no quente, (1 + k_min)·T_min no frio),
			cresce sem degraus até 45% no limite e até 80% na punição total. Tecla T no preparo (só testes): folga / porcentagem 80% / 25 °C fixos / degraus (antigo).
			Gelo no frio continua igual.
		[?] Partículas maiores (menos as bolhas, que ficam do tamanho original): x1,8 (ESCALA_PARTICULAS) e as do abanar o fogo (labaredas e brasas) x2,6 (ESCALA_ABANAR), em visual_caldeirao.gd.
			Particulas de bolha e caldeirão não devem sofrer a escala. somente as fogo.
		[?] Bolhas e estrelas pela temperatura em curva exponencial (quase nada no começo, máximo em 200 °C): quantidade, velocidade e giro das estrelas. Limites baixos em visual_caldeirao.gd (PARTICULAS_CURVA, BOLHAS_*_MAX, ESTRELAS_*_MAX).
		[?] Vermelho do caldeirão por pontos (GRADIENTE_VERMELHO em visual_caldeirao.gd): 100 °C só o fundinho, 160 °C todo vermelho claro, 200 °C bem vermelho. Para mudar, edite os pontos (°C, progresso).
		[?]  anéis branco > amarelo > laranja > vermelho > verde no ideal, e volta ao passar.
			(item antigo dos círculos branco > amarelo > laranja > vermelho > verde juntado aqui: feito, paleta "aproxima" na tecla P)
			Modos para testar no preparo (teclado):
				M = régua (punição / proporcional / absoluto), já existia.
				P = cores: FAIXA (padrão: anéis contínuos, cada trecho com a cor do aproveitamento naquele ponto: vermelho > amarelo > verde no ideal > amarelo > vermelho; o anel começa vazio e vai revelando a cor; anel de fora = cozimento, de dentro = tempo) · dourado (antiga) · aproxima (branco > amarelo > laranja > vermelho > VERDE no ideal; passando: vermelho > laranja > amarelo > branco) · semáforo (cinza > amarelo > verde; passando: amarelo > laranja > vermelho > preto) · cor única (o anel inteiro na cor do estado atual).
				C = anel já colorido (as bolhinhas apagadas já mostram a cor do trecho, fraquinhas, e a "barra" vai acendendo).
				A vela usa as mesmas cores. Começa em "faixa". Outras ideias de feedback: me diga e eu ponho como mais um modo.
	[ ] Receitas 
		[ ] Definir 2~3 receitas
		[ ] balancear dificuldade, peso de cada erro: tempo, temp, cozimento, explorar os TIPOS de matrizes. explorar o que é posível nesse sistema térmico
			[?] balancear o resultado da poção de extroversão. pois um cogumelo já está sendo suficiente para o melhor resultado, entender o pq.
			Por quê: o cogumelo multiplica E por 1,16 (+16%) e o critério do filho do mercador aceitava qualquer E que subisse 10% (e aceitava C/A/O mudando até "pouco").
			Ajuste: E precisa subir "muito" (>= +30%; a desenvoltura dá +40%) e O, C, A não podem mudar (menos de 10%); N não pode subir; nenhum traço extremo.
			Com 1 cogumelo agora: "B-bom... dia." / "Melhorou um pouco, mas ainda não dá para deixar a loja com ele."

	[?] Resultado Caldeirão: animação do produtório das matrizes no resultado.
		Feito (src/preparo/animacao_produtorio.gd, antes da poção na JanelaResultado): ingredientes se alinham (A = B_n·…·B_1, o 1º à direita/embaixo), anel enche até a_i e a grade desbota de A_i para B_i, os B_i se combinam em ordem até a matriz final, que fica no lugar da grade da janela. Sem agrupar iguais. A poção só aparece ao confirmar (toque): a matriz encolhe e vira a poção, que vai para o inventário. Só em coluna; depois da 1ª combinação o cartão vira ícone de poção e o anel mostra a média do aproveitamento. Teste no preparo: K = toque acelera/pula.
		Ao finalizar: os cartões saem dos ícones dos ingredientes no caldeirão (perdidos não), a tela vai ao preto puro e a cena do caldeirão fica escondida e parada (CenaPreparo.cobrir_cena) até a janela fechar. Mais leve.



[ ] Roteiro/Estilo/Personagens
	[ ] Princípios
		[ ]	Diálogos devem condizer com a época
		[ ] Cada personagem tem seu linguajar próprio e manias.

	[ ] Quest Zigmund
		[ ] personalidade
		[ ] situação
			[ ] problema
			[ ] objetivo
			[ ] plano
			[!] sumiu na floresta
			[!] pediu para a bruxa ajudar a princesa
			[!] casamento
		
	[ ] Quest Bosque Goblin
		[ ] ???
	[ ] Cap. 1 Casamento
		[?] após o casamento as falas no castelo_in01 devem mudar
			Feito: rei, princesa e os dois guardas têm falas novas depois do casamento, diferentes para resultado 1 (convidada, grata) e 2 (não convidada, princesa "calma demais").
	
	

[ ] Quando o HUD abre a primeira vez (bruxa_out1 na intro? bruxa_in antes do diálogo?).
[ ] Pode apagar: dados/eventos/cidadeA_in03_vazia.tres, dados/falantes/bruxa_pensando.tres. (conferido: nada usa; o editor daqui não consegue apagar, apague pelo explorador)

[ ] Usar traços na história:
	[ ] O
	[ ] C
	[!] E (cidade_in02, mercador)
	[ ] A
	[!] N (cap 1, princesa)

[ ] ervas muito escondidas na floresta. mudar o sprite da erva para destacar mais na floresta.

[?] Escolta do castelo_in01: guardas e bruxa desalinhavam. Causa: o player aplicava fricção mesmo quando um Mover com velocidade fixa mandava nele, então a bruxa andava mais devagar que os eventos (e dependia do FPS). Agora com velocidade fixa não há fricção (InputManager.velocidade_fixa_ativa).
[?] Guardas da ponte e da estradaB: o Mover da bruxa vinha antes da variável que libera, e a página sólida bloqueava. Agora a variável vem antes: a página muda na hora (passável) e o Mover anda. Regra: a página do evento troca assim que a variável muda, mesmo com os comandos ainda rodando.
[?] Editor de eventos em Python (_/editor_eventos, abrir com abrir_editor.bat; precisa de PySide6): páginas, condições, comandos, diálogo em texto (Ctrl+T), labels (F12), várias páginas/eventos de uma vez, buscar/substituir, desfazer, backup ao salvar. Ver _/editor_eventos/README.md.
[?] entrando em portas sem querer com o touch, feedback quando clicar em eventos
	Feito: todo toque no mapa mostra um anel no ponto tocado (src/ui/toque_feedback.gd) e o evento de clique tocado clareia rapidinho (evento_base._destacar_toque).
[?] cor nas palavras/frases, efeito nas palavras/frases no comando mostrarmsg.
	Toc toc (efeito SOM): os risquinhos apontam sempre para a esquerda (dentro ou fora da tela).
	Prints de debug tirados de interaction_zone.gd, pagina.gd e evento_base.gd (davam "output overflow").
	Feito: BBCode do Godot no texto: [color=red]..[/color], [b], [i], [u], [s], [wave], [shake], [rainbow], [tornado], [fade], [bgcolor=..], [font_size=..], [outline_color=..], [outline_size=..].
	Outros "[" continuam aparecendo como texto. A escrita letra a letra conta só as letras (sem as tags). O cabeçalho antigo [nome;foto;pos] continua valendo.
	Anotado: lista de comandos (e BBCode) no fim do readme, em "Comandos de evento (referência)".
[.] brilho na porta, da mesma cor do véu, ao trocar o véu.
	Feito: ao clicar no véu adicione um flash da cor do véu no sprite da porta, para que ele pisque da cor.
	Feito: saiu o brilho da porta (o do véu continua); a porta pisca 2 vezes na cor nova. Novo tipo de efeito PISCAR no Mostrar efeito (serve para qualquer evento)
	Correção: tingiu, mas como a cor do objeto não era branca misturou as cores do objeto mais a tintura. quero que leve em consideração isso e pinte da cor que eu pedi. preciso mandar o mesmo sprite com tons de branco para isso?




[ ] organização da pasta Graphics(está sendo chamada de assets neste projeto) estilo rpgmaker:
	Animations (efeitos especiais, magias, etc)
	Characters (eventos)
	Icons
	Panoramas (imagens para cenário)
	Pictures (sprites para controlar na tela)
	Transitions
	Windowskins

[ ] missao01_convite é gravada e nunca lida: fica para o Cap. 2 (convite do casamento).


[ ] 2ª receita:  - desenvoltura
	Ajustado: musgo t_max 12 → 35 (aguenta os ~30 s finais); flor m 2400 → 5000, s−/s+ 900/1400 → 1900/2900 (Q de 60 s a ~85 °C ≈ 5100). Juntos dão diag(1,1,1.4,1,1) se o musgo entra depois.
	balanceat tempo, u,s-,s+, Tmin,Tmax,tmin,tmax, etc de cada item. infusao


[.]Database (nomes das proibidas ficam para o Cap. 2): Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). Poção da Calma Profunda. Poção #2. Poções proíbidas. 
	Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
	Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
	Poção de Pó de Retorno Concentrada no catálogo, com efeito (teleporte para bruxa_in). Pó: diag(0.97,1,1,1,1.03), cozimento leniente (m 3000, T 60–170, t 10–150, folgas 0,4/0,6).
	Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").


[ ]	Save/Load (DEPOIS: muita coisa ainda pode mudar)
[ ]		Game_Temp deve ter save e load de arquivo_unico de titulo "save"+time_stamp
[ ]		GameTemp, posição player, mapa, etc

[ ]		Tutorial do caldeirão na 1ª vez.

[ ] Bugs/Revisão:
[!]		Faces em .tres: dados/falantes/*.tres são Personagem (src/dados/personagem.gd): nome + faces com nome ({"normal": ..., "pensando": ...}; a primeira é a padrão). O lado da tela não fica no personagem.
			Mostrar mensagem / Mostrar opções: personagem, face ("" = a primeira) e posicao (0 = esquerda, 100 = direita) em cada fala. As 201 falas convertidas (bruxa 0, os outros 100, guarda2 50 numa fala; pensamentos da bruxa com face "pensando").
			Posição: menu "(padrão)" / "escolher posição" no inspetor (no arquivo, posicao -1 = padrão). (padrão) repete a última posição em que aquele personagem falou (0 na primeira vez); qualquer outro valor vira a nova posição lembrada dele. Cada personagem lembra a sua.
			[nome;foto;pos] no começo do texto continua valendo, com prioridade.
			Personagens: bruxa (normal, pensando), campones, desconhecido (???), guarda1, guarda2, princesa, rei. bruxa_pensando.tres ficou sem uso: pode apagar.
[ ]		Variações no flip card. Sorteadas: normal = 1 flip diagonal; variações no mesmo tempo: 5 flips com velocidade decrescente; flip mudando a dimensão horizontal, com 1 ou 5 flips. 


[ ]	Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
[ ]		(Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
[ ]		(Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.


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

[ ] Estilo:
[ ] 	organizar o layout e textura dialogo/opções
[ ]		Ajuste estético, borda, cor, fonte, etc.
[ ]		Criação de estilos padronizados para cada coisa. (?) tipo estilo texto, estilo menu, ...?
[ ]

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

## Comandos de evento (referência)

```
Cada página (PaginaData) tem: condições (todas valem), gatilho (CLIQUE / TOQUE / PARALELO), aparência,
colisão/área (tamanho = sprite x escala; sem sprite = 32x32), movimento (FIXO / ROTA) e a lista de comandos.
Vale a ÚLTIMA página cujas condições são todas verdadeiras. Página sem sprite e área bem pequena (ex. 0.015) = evento "some".

CONDIÇÃO (páginas, if, while)
	tipo: VARIAVEL (variavel op valor) · ITEM (quantidade no inventário) · PERSONALIDADE (traço O/C/E/A/N)
		  POSICAO_X / POSICAO_Y (bruxa, px) · DIRECAO_PLAYER (== / !=) · SELF_VAR (A/B/C/D deste evento)
		  ITEM_NOME (itens com esse nome; "Poção*" = começa com)
	operador: == != > < >= <=     · variáveis são sempre número (0 e 1 para não/sim)

FLUXO
	if (condicao) ... else ... end      blocos podem ser aninhados
	while (condicao) ... end            break sai do while mais interno
	label (nome) / goto (label)         pular para um ponto da lista
	esperar (segundos)
	chamar_evento (evento .tres, esperar)        roda a página válida de outro evento como se estivesse aqui
												 (labels/if/goto valem só dentro dele)
	pular_com_toque (label)             daqui em diante, tocar na tela pula para o label (ex.: pular intro)
	apagar_evento (evento, parar)       some até sair do mapa; parar = interrompe o que ele estiver rodando

DIÁLOGO
	mostrar_msg (personagem, face, posicao 0-100 ou padrão, texto)
		padrão = última posição em que esse personagem falou
		"[nome;foto;pos] texto" no começo ainda funciona e tem prioridade
		BBCode no texto: [color=red]..[/color] [b] [i] [u] [s] [wave] [shake] [rainbow] [tornado] [fade]
						 [bgcolor=..] [font_size=..] [outline_color=..] [outline_size=..]
						 ex.: "Isso é [color=red]perigoso[/color]!"   "[shake]Socorro![/shake]"
		texto igual ao nome de uma variável = mostra o valor dela
	mostrar_opcoes (personagem, face, posicao, pergunta, opcoes[ ], labels[ ])   cada opção pula para o seu label (até 5)
	estilo_dialogo (restaurar, fonte, cor, itálico, efeito NENHUM/ONDA/TREMOR, transparência, fundo, pensamento...)
		(pensamento da bruxa: chamar_evento pensamento_inicio ... pensamento_fim. (futuramente quero remover esse negócio de pensamento_inicio, pensamento_fim como um comando. pode ser feito só com BBCode)
	legenda (texto, segundos 0 = espera toque, fonte, altura, fade)       narração no meio da tela
	balao (alvo BRUXA/EVENTO, evento, emocao ! ? ... coração raiva nota !?, duracao, altura 120, esperar)

BRUXA E EVENTOS
	player (TRAVAR / DESTRAVAR / MOSTRAR / SUMIR)
	mover (alvo BRUXA/EVENTO, destino X / ATE_EVENTO / DESLOCAR / PARAR, x, y, manter_y, velocidade, direcao, esperar)  · andando vira sozinho; direcao = para onde olhar ao chegar
		bruxa: velocidade 0 = normal (acelera); > 0 = fixa (use a mesma dos eventos que acompanham)
		evento: velocidade 0 = 100 px/s
	direcao (alvo, evento, ESQ / DIR / INVERTER / CENTRO / OLHAR_PARA, olhar_para)
	travar_direcao (alvo BRUXA/EVENTO, evento, travar) trava/destrava: andando não vira (Direção ainda vira)
	passavel (alvo BRUXA/EVENTO, evento, passavel)
	evento_animacao (evento, animacao; vazio = a da página)
	teleportar (mapa, posicao, direcao)

TELA, CÂMERA, SOM
	fade (FADE_OUT / FADE_IN, tempo, esperar)
	camera (MOVER posicao+tempo / VOLTAR tempo / TREMER intensidade+velocidade+duracao)   não espera: use esperar
	mostrar_efeito (alvo BRUXA/EVENTO/TELA, evento, tipo, cor, altura, esperar)
		MAGICO · BRILHOS · CLARAO · FUMACA · SOM (três risquinhos) · PISCAR (sprite pisca na cor)
	som (canal BGM/BGS/SE, arquivo, volume)
	hud (mostrar)

VARIÁVEIS, ITENS, POÇÕES
	variavel (escopo GLOBAL/DO_EVENTO, variavel ou letra+evento, DEFINIR/SOMAR/SUBTRAIR/MULTIPLICAR/DIVIDIR/ALEATORIO, valor, valor_max)
		variáveis novas: um .tres em dados/variaveis/ (entram sozinhas)
	item (ADICIONAR / REMOVER / LIMPAR, item, quantidade)
	preparo (abrir)                      abre o caldeirão e espera fechar
	aplicar_pocao (personalidade, variavel 1/0, texto_botao, evento_alvo)   bruxa escolhe um item e aplica
	classificar_personalidade (personalidade, referencia, prefixo, limite_neutro, limite_muito, ...)
		grava <prefixo>_O/_C/_E/_A/_N (-2..+2) e <prefixo>_extremo
	mudar_personalidade (personalidade, traco, valor)

ROTA (movimento autônomo da página): MOVER, FRENTE, TRAS, ALEATORIO, PULAR, OLHAR, FIXAR_DIRECAO,
	ESPERAR (segundos, segundos_max), BALAO, VELOCIDADE, ANIMACAO · chance, rota_repetir, rota_raio
```
