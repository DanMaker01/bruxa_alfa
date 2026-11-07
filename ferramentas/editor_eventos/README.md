# Editor de eventos

Editor visual dos eventos do jogo (`dados/eventos/*.tres`): páginas, condições, comandos, diálogos e fluxo (Se/Senão/Fim, labels).

## Abrir

Clique duas vezes em `abrir_editor.bat`. Na primeira vez ele instala o PySide6 (`pip install PySide6`).
Ou pelo terminal, nesta pasta: `python editor_eventos.py`.

O editor acha o projeto sozinho (a pasta com `project.godot` acima desta).

## Como funciona

- Lê os scripts do jogo (`src/dados/comandos/*.gd`, `pagina_data.gd`, `condicao.gd`, `passo_rota.gd`). Comando ou campo novo no jogo aparece aqui sozinho (F5 recarrega).
- Salva os `.tres` no mesmo formato do Godot. Campo igual ao padrão sai do arquivo (como o Godot faz).
- Cada vez que salva (Ctrl+S), guarda a versão anterior em `backup/AAAAMMDD_HHMMSS/` (mantém as últimas 30).
- Se o arquivo mudar fora do editor (Godot), ele recarrega sozinho quando não há mudança não salva aqui; se houver, avisa antes de sobrescrever.
- No Godot, não deixe aberto no Inspector um evento que você está editando aqui (o Godot pode salvar a versão dele por cima).

## Telas

- **Eventos** (esquerda): filtro por nome. Ctrl/Shift + clique seleciona vários: as páginas de todos aparecem juntas.
- **Páginas**: vale a ÚLTIMA página com todas as condições verdadeiras. Selecione várias (até de eventos diferentes) e mude um campo no formulário: vale para todas.
- **Comandos** (direita): indentado pelos blocos. Cores: azul = diálogo, roxo = fluxo, verde = variáveis/itens, laranja = cena.
  Vermelho = label que não existe ou Se/Fim sem par. Azul claro = o par do bloco selecionado.

## Atalhos (F1 no editor)

| Onde | Tecla | O quê |
|---|---|---|
| geral | Ctrl+S | salvar tudo |
| geral | Ctrl+Z / Ctrl+Y | desfazer / refazer |
| geral | Ctrl+Shift+F | buscar e substituir em todos os eventos (ex.: renomear variável) |
| geral | F5 | recarregar scripts e arquivos |
| páginas | Del, Ctrl+D, Alt+↑/↓ | apagar, duplicar, mover |
| páginas | Ctrl+C / Ctrl+V | copiar e colar páginas (entre eventos também) |
| comandos | Enter / duplo clique | editar (na última linha: inserir) |
| comandos | Insert | inserir comando (digite para filtrar) |
| comandos | Ctrl+M | nova fala com o mesmo falante da anterior |
| comandos | Ctrl+C / X / V, Ctrl+D | copiar, recortar, colar, duplicar (entre páginas e eventos) |
| comandos | Alt+↑/↓ ou arrastar | mover |
| comandos | Ctrl+B | selecionar o bloco Se ... Fim |
| comandos | F12 | no "ir para"/opções: vai ao label; no label: mostra quem pula para ele |
| comandos | Ctrl+T | diálogo em texto |
| diálogos | Ctrl+Enter | confirmar |

## Diálogo em texto (Ctrl+T)

Com 2 ou mais comandos selecionados, edita esse trecho; senão, a página toda.

```
@padre 100
Bem-vinda à casa de Deus, senhora.

...Mesmo sendo quem a senhora é.

@bruxa:pensando
Hmm.
Segunda linha da mesma fala.

[[3]] Esperar 1 s
```

- `@falante` muda quem fala (nome do arquivo em `dados/falantes`); `@falante:face 100` com face e posição; `@-` sem nome.
- Linha em branco separa as falas; linhas seguidas = quebra de linha na mesma fala. Fala sem `@` antes usa quem falou por último.
- `[[n]]` é um comando que não é fala: pode mover ou apagar a linha, não edite o texto dela.
- Linha de fala que começa com `@` ou `[[`: ponha `\` antes. Linha só com `\` = linha vazia dentro da fala.

## Opções

No comando Opções, a tabela junta o texto de cada botão com o label para onde ele pula. Marque
"criar no fim da página os labels que faltam" para gerar os labels (cada um com um "ir para" um label de saída).

## Arquivos

- `editor_eventos.py` janela · `widgets.py` campos e diálogos · `modelo.py` projeto, resumos, diálogo em texto
- `esquema.py` lê os scripts .gd · `tres.py` lê e escreve .tres
- `config.json` (tamanho da janela, último evento) e `backup/` são locais (fora do git).
