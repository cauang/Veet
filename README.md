# Veet

RPG de batalha por turnos estilo Undertale em que o jogador, um residente de Medicina Veterinária da UNIFOR, diagnostica e trata pacientes por meio de "lutas" não violentas.

- **Motor:** Godot 4 (2D, GDScript)
- **Plataforma:** PC (Windows / Linux / macOS)
- **Resolução-base:** 640 × 360, ampliada em escala inteira, filtro Nearest

## Documentação (`docs/`)

| Arquivo | Conteúdo |
|---|---|
| `GDD.docx` | Game Design Document: mecânicas, UI, requisitos técnicos |
| `Narrativa.docx` | Universo, tutores, catálogo de casos clínicos, falas |
| `Lista-de-Assets.docx` | O que desenhar: tamanhos, estados, nomes de arquivo |
| `Guia-de-Prompts-IA.docx` | Como gerar assets com IA mantendo o padrão |

## Estrutura de pastas

| Pasta | Para que serve |
|---|---|
| `assets/` | Arte, áudio e fontes (ver abaixo) |
| `scenes/` | Cenas `.tscn`, uma pasta por tela do jogo |
| `scripts/` | Scripts `.gd`, separados por responsabilidade |
| `data/` | Conteúdo do jogo em dados: casos, pacientes, diálogos, padrões de ataque |
| `shaders/` | Shaders `.gdshader` (brilho, distorção, dessaturação) |
| `resources/` | Recursos reutilizáveis do Godot (`.tres`: temas, estilos) |
| `saves/` | Saves locais de teste (não vão para o git) |
| `tools/` | Scripts auxiliares fora do jogo (ex.: `pixelfy.py`) |
| `docs/` | Documentação do projeto |

### `assets/`

- `home/`: fundo, logo, UI, mascote e efeitos da tela Home
- `animais/<nome>/`: `fonte/` (arquivo editável) e `exportado/` (PNG final)
- `patinha/`: avatar do minigame e projéteis
- `fontes/`: fontes pixel
- `audio/`: `musica/` e `sfx/`

### `scenes/`

`home`, `triagem` (anamnese), `batalha` (com `caixinha`, `menu_acoes`, `projeteis`), `prontuario`, `resumo_dia`, `opcoes` e `componentes` (peças reutilizáveis).

### `scripts/`

`nucleo` (estado do jogo, progressão), `batalha`, `dialogo` (árvore de decisão), `prontuario`, `ui`, `utilitarios`.

### `data/`

`casos`, `pacientes`, `tutores`, `dialogos`, `padroes_ataque`, `tratamentos`, `pistas`.

## Convenções

- **Nomes de arquivo:** minúsculas, sem acento, separadas por `_` (`fibonacci_sheet.png`, `tela_home.tscn`).
- **Cenas e scripts:** o script de uma cena tem o mesmo nome dela e fica em `scripts/` na pasta equivalente.
- **Conteúdo é dado:** pacientes, casos e diálogos entram em `data/`, não dentro de scripts.
- **Assets de terceiros:** registrar em `CREDITOS.md` na hora do download.
- **Pixel art:** filtro **Nearest**, escala inteira. Nunca redimensionar com suavização.

## Primeiros passos no Godot

1. Abrir o Godot 4 e **importar** esta pasta como projeto (ela vira a raiz do projeto).
2. Em *Project Settings → Display → Window*: viewport **640 × 360**, stretch mode **viewport**, scale mode **integer**.
3. Em *Project Settings → Rendering → Textures*: filtro padrão **Nearest**.
4. As pastas `docs/` e `tools/` já têm `.gdignore`, então o Godot não as importa.
