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

## Triagem (o que falta, por esforço)

```
	
MÉDIO (já sei o que fazer, mas leva mais tempo ou mexe em mais coisas)
	[ ] Tutorial do caldeirão na 1ª vez (talvez com a poção concentrada; sem deixar errar). Decidido: a bruxa fala e guia, livre (não trava botões). Fazer depois.
	[?] Anéis de aproveitamento: decidir o formato final e tirar os modos de teste (M, P, C). Feito: semáforo, anel começa vazio, régua absoluta; teclas M/P/C removidas (T e K continuam).
		Corrigir, o anel completo ao invés das bolinhas é melhor, e as cores antigas estavam melhores tbm. quero poder escolhre melhor.
		[?] Feito: o anel agora é sempre contínuo (ANEL_CONTINUO em icones_caldeirao.gd); a tecla P troca só as cores: faixa (padrão) > dourado > aproxima > semáforo > cor única. C liga o anel já colorido (o caminho todo fraquinho, revelando). Régua absoluta.
	[ ] Estilo visual padronizado de diálogo/opções (borda, cor, fonte, janela).
	[ ] Organizar a pasta assets no estilo RPG Maker (mexe em muitos caminhos: fazer com calma, de uma vez).
	[ ] Padronizar camadas de parallax em todos os mapas.
	[ ] Medir os 10 testes de 8 ervas + 4 cogumelos (teste seu).

PRECISA DE PLANEJAMENTO ANTES (decisões de design)
	[ ] Receitas: tempo entre 5 s e 5 min (média 1 min), excesso de um ingrediente, mesmo ingrediente 2x, receita dobrada, padrão das receitas, peso de cada erro.
	[ ] Quando o HUD abre a primeira vez.
	[ ] Pentagrama do Cap. 2 (arestas = a_ij, animações por tipo de matriz).
	[ ] História/roteiro, diálogos do Cap. 1, quests (Zigmund, Bosque Goblin, Casamento), fichas e linguajar dos personagens.
	[ ] Arte e áudio (faces, sprites, cenários, BGM/BGS/SE, balão de expressão): dependem dos arquivos.
	[ ] Expansões (clima, fama, compra/venda, mercado).
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
			[ ] Livro de Receitas
			[ ] ...
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
		[ ] cidade, cidade_in01, cidade_in02
		[ ] cidade_in03
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01, castelo_in02
		[ ] castelo_in03
		[ ] estrada_b
	[ ] BGS
		[ ] tremor
		[ ] passaros
		[ ] som floresta
		[ ] vento
	[ ] SE
		[ ] porta01 	(porta batendo normalmente)
		[ ] porta02 	(rangido de porta fechando devagar)
		[ ] passos 		(para transição)
		[ ] pulo 		(velocidade)
		[ ] dash
		[ ] magia01		(genérico)
		[ ] magia02 
		[ ] magia03
		[ ] pancada01
		[ ] pancada02
		[ ] corte
		[ ] vidro01
		[ ] vidro02
		[ ] carta 		(girando)
		[ ] aplausos
		
[ ]	Menus 100%
	[ ] Estilo de cartas
		[ ] definir audio das interações
		[ ] definir carta para cada clicável.
	[.] menu inicial
		[!] start, load, config, sair
	[.] menu pause
		[ ] continuar, save, load, opções, menu principal
	[.] cena caldeirão
		[ ] bruxa, caldeirão, botões, inventário
	[ ] cena loja
		[ ] ... (depois)
	[.] opções (único)
		[ ] audio, 
		[ ] video, etc
	[ ] cartas/hud
		[ ] definir pentagrama para o verso das cartas inventário/status 
		[ ] interação com outros menus


[ ] Caldeirão 100%
	[ ]	Tutorial do caldeirão na 1ª vez. usando poucos ingredientes, mudar intro talvez. tentar integrar naturalmente com o que já tem.  talvez ensinar fazendo a poção concentrada? não deixar errar pq não é fácil achar o item.
	[ ] Layout
		[ ] Reformular Layout (pensar em celular). Menus, botões,Bruxa_chibi,caldeirão, texto em cima do caldeirão (passar para falas da bruxa), feedback rápido da bruxa.
		[?] O ícone de +Fogo deve ser centralizado no botão, baixar tbm. (feito no +Fogo; o Abaixar só tem texto, que já é centralizado)
	[ ] Feedback bom pra temperatura do caldeirão e itens, tanto frio quanto quente
		[.] TESTE de P e M:
			M = absoluto
			P = anel completo, provavelmente semáforo ou aproxima.
			C = o anel já é colorido, mas vai sendo revelado.
	[.] ver se consigo jogar 8 ervas e 4 cogumelos rapidamente e sem erros, medir 10 testes. no meio da receita as vezes esqueço um cogumelo. talvez dar um jeito de agrupar antes ou jogar multiplos, por exemplo segurando o botão do ingrediente ou podendo combinar eles antes. UI:caso segure o botão, ou caso selecione a jogue multiplos joga em quantidade/velocidade maior.
		Feito (jogar_varios.gd): segurar joga um item a cada 0,32 s (velocidade constante, INTERVALO_INI) e a bruxa vai contando no balão quantos entraram ("1!", "2!"...). Toque joga 1. Falta medir os 10 testes.
		A bruxa vai contando sem exclamação. (ou talvez vai contando 1..., 2..., ... e quando largar o botão ela diz o último como N !!)
		Tentar: se jogar 1 item, esperar um tempo INTERVALO_JOGAR_ITEM e segurar para jogar os próximos, ela consegue fazer a contagem contínua.
		[?] Feito: jogar o mesmo item de novo (toque ou segurar) até 1 s depois do último continua a contagem (INTERVALO_JOGAR_ITEM em jogar_varios.gd). Sem lance novo por 1 s, ela fala o total "N!!" (só se N >= 2); ao soltar depois de segurar, fala assim que o último cai.
	[ ] Resultado da Poção:
		[?] Tenho que analisar, o tamanho da matriz fica sem margem para a carta. o pentagrama também, está muito grande para a carta. os itens estão ok. 
	[ ] Usar cartas tbm na cena do caldeirão, para botões, etc? testar como ficaria.


[ ] Livro de Receitas:
	[ ] Receitas:
		[ ] Balanceamento de Receitas:
			[ ] DEPOIS: (Todas) As receitas têm (devem ter) tempo entre [5seg,5min], com o tempo médio 1min.		
			[ ] Se eu colocar muita (QUANTO?) quantidade de um ingrediente, vai fazer uma poção muito forte.
			[ ] Faz sentido uma receita que leva o mesmo ingrediente 2x em tempos diferentes? I_tempo, I_Temper, Q, como conseguir aprovetar duas vezes um mesmo tipo de item numa mesma receita?
			[ ] DEPOIS: Fazer receita dobrada tem efeito de potencializar (escalar) a matriz resultante. por exemplo se fizer uma poção da calma profunda dobrada, 
			[ ] 
		[ ] 1ª receita: calma profunda
			[ ] escrever e padronizar:o padrão é nome, passos (só existe 2 passos: cor de fogo(cor) e colocar ingrediente(qtd,tempo)). pensar tem algo mais que possa ser feito numa receita?
		[ ] 2ª receita: desenvoltura
			Ajustado: musgo t_max 12 → 35 (aguenta os ~30 s finais); flor m 2400 → 5000, s−/s+ 900/1400 → 1900/2900 (Q de 60 s a ~85 °C ≈ 5100). Juntos dão diag(1,1,1.4,1,1) se o musgo entra depois.
			balancear tempo, u,s-,s+, Tmin,Tmax,tmin,tmax, etc de cada item. infusao
		[ ] balancear dificuldade, peso de cada erro: tempo, temp, cozimento, explorar os TIPOS de matrizes. explorar o que é posível nesse sistema térmico
			[?] balancear o resultado da poção de extroversão. pois um cogumelo já está sendo suficiente para o melhor resultado, entender o pq.
			Por quê: o cogumelo multiplica E por 1,16 (+16%) e o critério do filho do mercador aceitava qualquer E que subisse 10% (e aceitava C/A/O mudando até "pouco").
			Ajuste: E precisa subir "muito" (>= +30%; a desenvoltura dá +40%) e O, C, A não podem mudar (menos de 10%); N não pode subir; nenhum traço extremo.
			Com 1 cogumelo agora: "B-bom... dia." / "Melhorou um pouco, mas ainda não dá para deixar a loja com ele."
	[] Cena do Livro:
		[ ] ao abrir o livro, ele inicia na primeira página, corre até a página mais atual (ou temporária), daí faz as ações dela (transcrever página temporária, etc).
		[.] animações de livro abrindo(mais lento), livro fechando(mais lento), avançar página, voltar página, avançar até encontrar página, adicionar página, remover página
			Feito: abre/fecha esticando da lombada; virar = a folha fecha na lombada e a outra abre; ir até uma página = folhas rápidas; página nova: a tinta aparece; apagar: a página cai e some.
		[.]	Ao clicar numa página mostra seus ingredientes e tempo relacionado com seu gráfico, seu resultado.
			Feito (detalhe_receita.gd): tocar no papel de uma página já feita abre o melhor preparo: gráfico T(t) com as faixas de cor da chama e a entrada de cada ingrediente, aproveitamento de cada um e a matriz. Só para preparos feitos a partir de agora (guardam a curva).
			EDIT: remova isso.
		[.] Database (nomes das proibidas ficam para o Cap. 2): Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). Poção da Calma Profunda. Poção #2. Poções proíbidas. 
			Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
			Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
			Poção de Pó de Retorno Concentrada no catálogo, com efeito (teleporte para bruxa_in). Pó: diag(0.97,1,1,1,1.03), cozimento leniente (m 3000, T 60–170, t 10–150, folgas 0,4/0,6).
			Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").


[ ] História/Roteiro
	[ ]	Diálogos devem condizer com a época
		[ ] Cap. 1 (-N)
			[?] intro-Campones
			[ ] Guardas
			[ ] Bosque NPC
			[ ] Cidade 
			[ ] Castelo
		[ ] Cap. 2 (+E)
	[ ] Usar traços na história: 
		O,(conservador com pouca abertura)
		C (consequencialidade, prudencia, preguiçoso),
		A (amabilidade, aumentar ou diminuir?)
	[ ] Usar permutação de traços
	[ ] Poções proibidas


[ ] Diálogos 100%
	[ ] Intro : revisar texto (tempo e ritmo).
	[ ] Cap. 1: Revisão de cada evento.
	[ ] Sprites: Balão de expressão por sprite: precisa da arte (1 sprite de balão, se der pra fazer sem deformar as quinas seria ideal)
	[ ] Estilo visual:
		[ ] organizar o layout e textura dialogo/opções
		[ ]	Ajuste estético, borda, cor, fonte, etc.
		[ ]	Criação de estilos padronizados para cada coisa. estilo de texto, estilo de janela, paleta de cores, animação coerente, etc...
		[?] Eventos de diálogo devem verificar se o próximo evento a tomar a frente será diálogo também, exceto depois de comando wait, etc.
			Feito: a carta do diálogo não desvira se vem outro diálogo em seguida (Interpreter.dialogo_a_seguir: fila de diálogos ou próximo comando de um evento rodando, pulando os instantâneos como variável/if/label/item/som). 
			Esperar, mover, fade etc. interrompem. Espera no máximo 1,5 s (carta.gd: ESPERA_MAX_DIALOGO).
			se um evento acabar em mensagem e outro iniciar em mensagem com o mesmo falante, nome, foto etc então o card não deve fechar depois do primeiro evento, pois é uma continudade. 
			exemplos disso acontecem ao chamar eventos por comando, entre outros.
			Testar mais: no camponês, no castelo_in01.
			Feito também: quem chamou outro evento (Chamar evento) e volta com fala depois que o chamado termina em fala: a carta não fecha entre os dois.

[ ] Quests
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
		[ ] cidadeA_in01 não tem quest?


[ ] Personagens
	[ ] Fazer uma ficha de personagem 
	[ ] Criar personalidades big five
	[ ] Cada personagem tem seu linguajar próprio e manias.
		[ ] Bruxa
		[ ] Campones
		[ ] Guarda1
		[ ] Guarda2
		[ ] bosque_npc
		[ ] Cidade
			[ ] NPC Adulto
			[ ] NPC Criança 1 
			[ ] NPC Criança 2
			[ ] Casa 1
				[ ] NPC 
			[ ] Casa 2
				[ ] Mercador Pai
				[ ] Mercador Filho
			[ ] Igreja
				[ ] Padre


[ ] Eventos/Core:
	[?] Colisão:
		depois de pegar o véu. quando clico no véu acima da porta, a bruxa(centro dela) vai até a posição que eu cliquei e ativa o evento do véu (as vezes ativa até antes). 
		o certo deve ser: quando clicar em eventos, deve ir até encostar no retangulo de colisao(colisão e não interação) e já ativar o evento, não precisa ir até a posição clicada. Quero testar se isso é bom para o game feel.  
		Feito para testar: clicar num evento longe faz a bruxa andar só até encostar na borda da colisão do evento (do lado dela; vale também para passáveis) e já ativa. Para voltar ao jeito antigo: game_manager.gd, CLIQUE_ATE_COLISAO = false.
	[ ] O comando de pular intro com clique, no começo, parece estar demorando muito para fazer o fade e só parece que está escuro mto tempo, se eu ficar pulando.
	[?] Retirar isso de só encostar na área já interage. antes estava melhor e essa mudança não resolveu o problema ainda. o problema é que ao ficar clicando no véu acima da porta, a bruxa começa a ir para o centro da porta, eu queria que se ela já está na área para ativar, ela não anda para ativar novamente, só ativa. mas tem que pensar pra isso não virar um problema maior.
		Feito: voltou ao jeito antigo (CLIQUE_ATE_COLISAO = false). E agora: clicar dentro da área de um evento de clique em que a bruxa JÁ está não faz ela andar; o evento só ativa (se puder). Para não virar problema: só vale se o clique cai na área de interação do evento, o evento é de clique, tem comandos e a bruxa já está dentro dessa área; fora disso ela anda normal.
[ ] Documentação e Organização
	[ ] organização da pasta Graphics(está sendo chamada de assets neste projeto) estilo rpgmaker:
		Animations (efeitos especiais, magias, etc)
		Characters (eventos)
		Icons
		Panoramas (imagens para cenário)
		Pictures (sprites para controlar na tela)
		Transitions
		Windowskins (janelas, etc)
	[.]	Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
	[ ] GDD
		[!] v1
		[!] v2
		[!] v3.3


[ ] Decisões menores:
	[ ] Quando o HUD abre a primeira vez (bruxa_out1 na intro? bruxa_in antes do diálogo?).
	[.] Guardas da ponte e da estradaB: o Mover da bruxa vinha antes da variável que libera, e a página sólida bloqueava. Agora a variável vem antes: a página muda na hora (passável) e o Mover anda. Regra: a página do evento troca assim que a variável muda, mesmo com os comandos ainda rodando. (mudar para 250px de deslocamento)
	[?] Editor de eventos em Python (_/editor_eventos, abrir com abrir_editor.bat; precisa de PySide6): páginas, condições, comandos, diálogo em texto (Ctrl+T), labels (F12), várias páginas/eventos de uma vez, buscar/substituir, desfazer, backup ao salvar. Ver _/editor_eventos/README.md.
	[.] brilho na porta, da mesma cor do véu, ao trocar o véu.
		Feito: ao clicar no véu adicione um flash da cor do véu no sprite da porta, para que ele pisque da cor.
		Feito: saiu o brilho da porta (o do véu continua); a porta pisca 2 vezes na cor nova. Novo tipo de efeito PISCAR no Mostrar efeito (serve para qualquer evento)
		Correção: tingiu, mas como a cor do objeto não era branca misturou as cores do objeto mais a tintura. quero que leve em consideração isso e pinte da cor que eu pedi. preciso mandar o mesmo sprite com tons de branco para isso?
	[ ]	Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
	[ ]		(Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
	[ ]		(Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.

[ ] Bugs/Revisão:
	[ ] missao01_convite é gravada e nunca lida: fica para o Cap. 2 (convite do casamento).
	[?]		misc: Variações no flip card. Sorteadas: normal = 1 flip diagonal; variações no mesmo tempo: 5 flips com velocidade decrescente; flip mudando a dimensão horizontal, com 1 ou 5 flips.
		Feito (carta.gd, vale para todas as cartas): eixo diagonal 80% / vertical 20%; voltas: 1, ou 3 bem raro (5%); mesmo tempo total. Desliga com variar_virada = false. 
	[?]		godot: Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
					Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.
	[?]		Testar: loop de bgm, loop de bgs. (floresta.mp3 já está com loop=true no import)
	[?]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
				Feito: mapa_base tem bgm/bgm_volume no Inspector. Mesmo bgm = continua; outro = troca; vazio = para. Só a floresta tem bgm (floresta.mp3).
	[?] Parallax e câmera nas bordas (juntos):
		Como está: câmera presa entre 0 e a borda direita da maior imagem do "Meio" (mapa_base). Parallax simples: cada camada só segue a câmera pelo seu fator (fundo 0.2, meio 1.0, frente 1.1, interiores "Frente+" 0.9). SUAVIZAR = false (câmera sem suavização).
		Decidido: o mais simples. Na borda a câmera para e todas as camadas param junto (PARALLAX_NA_BORDA = false, BRUXA_NO_CENTRO = false, BORDA_SUAVE = 0). Testados e descartados: camadas continuando na borda (tranco), freio suave da câmera (quebra a ilusão), bruxa parando antes da ponta (encurtava os mapas). O código ficou desligado, cada um com sua constante.
		Regra das imagens (para não aparecer cinza): camada sem loop precisa de largura ≥ 640 + fator × (largura do mapa − 640). Ex.: Frente 1.1 em mapa de 6000 px = 6536 px (ou scale x 1.09). Mapas maiores não são necessários.
		Por camada: bosque (Meio chão 1.0, Frente árvores 1.1, scale 1.07); bruxa_out (Fundo 0.2, casa no Meio); castelo_in03 (Fundo 0.2, Frente 1.1, scale 1.051); castelo_out (Fundo 0.2, Frente 1.1); cidadeA, estradaA, estradaB (Fundo 0.2); ponte (Fundo4 céu, Fundo3 nuvens longe pan -6, Fundo2 montanha, Fundo nuvens pan -12, todos 0.2; Meio/Meio2/Meio3 1.0; Frente nuvens 1.1 pan -40).
		[?]	Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários? (câmera com borda suave; CamadaParallax na ponte)


```

## Possíveis expansões (futuras)

```
[ ] Sistema de clima
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
[ ]	Sistema de mercado/valor dinâmico

```
