# 🦈 OceanCleaners

Um jogo educativo no estilo *survivor* (inspirado em Vampire Survivors), onde você controla um tubarão que enfrenta ondas de poluição para limpar o oceano. O projeto está alinhado ao **ODS 14 — Vida na Água**, buscando conscientizar sobre o impacto do descarte incorreto de resíduos nos ecossistemas marinhos, através de uma experiência interativa e divertida.

> Projeto desenvolvido como parte de uma atividade de extensão universitária, conectando conhecimento acadêmico, tecnologia e sustentabilidade.

🔗 **[Jogar versão beta no navegador](https://scintillating-zuccutto-ecd067.netlify.app)** — projeto em desenvolvimento, pode conter bugs e funcionalidades incompletas

---

## 🎮 Sobre o jogo

Você controla um tubarão herói que ataca automaticamente os inimigos mais próximos — latas de lixo que representam a poluição marinha. Sobreviva o máximo possível, derrote inimigos para ganhar XP, suba de nível e escolha upgrades para ficar mais forte a cada partida.

---

## ✨ Funcionalidades

### Combate
- Ataque automático (habilidade "Mordida"), disparado por um temporizador que mira sempre no inimigo mais próximo
- Sistema de vida com dano visual (flash vermelho ao ser atingido)
- Inimigos com máquina de estados (parado, perseguindo, atacando, morto) e IA de perseguição/ataque
- Sistema de *pool* de inimigos (reaproveitamento de objetos em vez de criar/destruir constantemente, otimizando performance)

### Progressão (XP e Level Up)
- Cada inimigo derrotado concede uma quantidade de XP
- O XP necessário para subir de nível cresce geometricamente: `xp_necessario = 30 × 1.3^(nível - 1)`, tornando a evolução progressivamente mais desafiadora
- Ao subir de nível, o jogo pausa e exibe um painel de escolha entre três melhorias:
  - ❤️ **Vida** — +20 de vida máxima
  - 🗡️ **Dano** — +5 de dano de ataque
  - 👟 **Velocidade** — +20 de velocidade de movimento
- Os upgrades são válidos apenas durante a partida atual, reiniciando ao começar uma nova

### Interface (HUD)
- Barra de vida do jogador
- Barra de XP e indicador de nível atual
- Cronômetro de sobrevivência
- Contador de inimigos derrotados

### Áudio
- Trilha sonora de fundo contínua durante o jogo (via sistema Autoload, não reinicia ao trocar de cena)
- Música exclusiva para o menu inicial, com transição suave entre menu e gameplay
- Efeitos sonoros para: ataque do jogador, dano recebido, morte de inimigo e game over
- Música pausada automaticamente na tela de game over

### Menus e fluxo
- Tela inicial com opções de Começar e Sair
- Tela de Game Over exibindo tempo sobrevivido e total de inimigos derrotados, com opções de tentar novamente ou voltar ao menu

---

## 🛠️ Tecnologias

- **Motor:** [Godot Engine 4.6.2](https://godotengine.org/)
- **Linguagem:** GDScript
- **Arte:** Tiny Swords (asset pack) + arte customizada
- **Áudio:** Trilhas e efeitos sonoros royalty-free (Pixabay)

---

## 📁 Estrutura do projeto

```
OceanCleaners-beta/
├── assets/
│   ├── sfx/              # Efeitos sonoros
│   ├── ui/                # Elementos de interface
│   └── tiny_swords/        # Asset pack de arte
├── scenes/
│   ├── ui/                # Telas (menu, HUD, game over, upgrade panel)
│   ├── abilities/          # Habilidades (mordida, jato de bolhas, etc.)
│   ├── maps/               # Cenas de mapa/fase
│   ├── player.tscn
│   └── inimigo.tscn
├── scripts/
│   ├── abilities/
│   ├── player.gd
│   ├── inimigo.gd
│   ├── gerenciador_inimigos.gd
│   └── musica_fundo.tscn   # Autoload de música global
└── project.godot
```

---

## 🚀 Como rodar localmente

1. Instale o [Godot Engine 4.6.2](https://godotengine.org/download)
2. Clone este repositório:
   ```bash
   git clone https://github.com/Natan121206/Oceancleaner.git
   ```
3. Abra o projeto pelo Godot (`project.godot`)

### ⚠️ Ajuste necessário na câmera (primeira execução)

Ao rodar o projeto pela primeira vez no editor, a câmera pode não seguir o jogador corretamente. Para corrigir:

1. No ícone de câmera na parte superior do nó do player, habilite a opção **"Manipular câmera do jogo diretamente"**
2. Em seguida, nas **opções de integração**, desative a caixa **"Interagir jogo na próxima execução"**
3. Feche a janela do jogo e execute novamente

---

## 📅 Histórico de versões

| Versão | Destaques |
|---|---|
| 0.1 / 0.2 | Versões iniciais (base de movimentação, combate e mapa) |
| 0.3 | Sistema de XP e níveis — jogador ganha XP ao derrotar inimigos e sobe de nível |
| 0.4 | Painel de upgrades ao subir de nível (vida, dano, velocidade), com botões reativos (hover/pressed) |

---

## 🗺️ Roadmap (próximas implementações)

- [ ] Novas variações de inimigos
- [ ] Diferentes tipos de ataque para o jogador
- [ ] Novas opções de upgrade voltadas para os ataques
- [ ] Mapa funcional com colisões (atualmente uma arena plana sem obstáculos)

---

## 👥 Equipe

- Arthur Kauan
- Eduardo Apolonio
- Guilherme Araujo
- Henrique Santiago
- Natan Yuji

---

## 🎵 Créditos de áudio

Trilhas sonoras e efeitos sonoros obtidos via [Pixabay](https://pixabay.com/music/), sob a *Pixabay Content License* (uso livre, incluindo comercial, sem exigência de atribuição).
