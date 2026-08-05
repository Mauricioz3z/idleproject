# Especificação Técnica Completa — Clone de Idle RPG para Android

## 1. Análise de Tecnologia: Flutter vs. Alternativas

### 1.1 Flutter + Flame — RECOMENDADO com ressalvas
**Veredito:** Flutter É viável para este projeto, mas não é a escolha óbvia. A decisão depende do seu conforto com Dart e da complexidade das animações de combate.

| Critério | Flutter + Flame | Unity | Godot |
|----------|----------------|-------|-------|
| Curva de aprendizado | Baixa (se já sabe Dart/Flutter) | Média-Alta | Média |
| Performance 2D | Boa para idle/UI-heavy | Excelente | Excelente |
| Pixel art / Sprites | Suportado via Flame | Nativo e robusto | Nativo e robusto |
| Tamanho do APK | ~15-25 MB | ~20-50 MB | ~15-30 MB |
| Backend/Integração Android | Excelente (é nativo) | Requer plugins | Requer plugins |
| Mercado de trabalho / Comunidade BR | Grande | Enorme | Pequena crescente |
| Publicação na Play Store | Direta | Direta | Direta |

**Recomendação final:**
- **Se você já programa em Flutter/Dart:** Vá de **Flutter + Flame**. O ecossistema é maduro o suficiente para um idle RPG 2D. O package `flame` (v1.18+) cobre sprites, animações, tilemaps, collision e partículas. Para state management, use `Riverpod`. Para banco local, `Hive` ou `Isar`.
- **Se você não conhece Flutter:** Use **Unity 2D**. É o padrão ouro para jogos mobile 2D. Documentação infinita, asset store enorme, e o workflow de pixel art é superior.
- **Godot** só recomendo se o projeto for open-source ou se você quiser evitar taxas/royalties (embora Unity também seja gratuita até certa receita).

> **Nota importante sobre a "taskbar":** A mecânica central do TBH é a janela fixa na taskbar do Windows. No Android, o equivalente funcional seria um **Widget na tela inicial** + **notificação persistente** com progresso em tempo real. Isso é tecnicamente viável em Flutter (via `home_widget` e `flutter_local_notifications`).

---

## 2. Diferenciação Legal (Anti-Copyright)

Mecânicas de jogo **não são protegidas por copyright**. Você pode fazer um ARPG idle com combate automático, loot e classes sem problemas. **O que NÃO pode copiar:**

| Elemento | TBH (Original) | Seu Jogo (Diferenciação) |
|----------|---------------|-------------------------|
| Nome | "TBH: Task Bar Hero" | Ex: "Pixel Idle Quest", "Mini Dungeon Legends", "Pocket Hero Squad" |
| Setting | Genérico fantasy | Cyber-fantasy, Steampunk, Pós-apocalíptico mágico, etc. |
| Classes | Knight, Sorcerer, Ranger... | Renomear e redesenhar. Ex: Vanguard, Elementalist, Sharpshooter, Medtech, Tracker, Berserker |
| Raridades | Common → Cosmic | Use nomes e cores diferentes. Ex: Basic → Mythic (ou Bronze → Exotic) |
| Monstros | Esqueletos, goblins padrão | Crie variações visuais distintas. Mude paletas, formas, comportamentos |
| UI/UX | Layout específico da janela taskbar | Layout próprio, widget Android, notificação persistente |
| Música/SFX | Originais do TBH | Compor ou usar assets royalty-free (itch.io, OpenGameArt) |
| Código/Assets | Proprietários | Criar do zero ou usar assets CC0/licenciados |

**Regra de ouro:** Mude **nome, aparência visual, nomes internos, lore e soundtrack**. Mantenha apenas o *gênero* (idle ARPG).

---

## 3. Game Design Document (GDD) Resumido

### 3.1 Conceito Core
**Gênero:** Idle ARPG / Auto-battler / Loot Grinder  
**Plataforma:** Android (API 24+)  
**Monetização:** F2P com anúncios opcionais (rewarded) + IAP cosméticos/convênio  
**Sessão média:** 30 segundos (check-in) a 8 horas (idle background)  
**Diferencial:** Widget na tela inicial + notificação persistente mostrando combate em tempo real.

### 3.2 Loop Principal
1. Jogador abre o app (ou olha o widget).
2. Heróis lutam automaticamente contra waves de monstros.
3. Drop de ouro, XP e itens automático.
4. Jogador equipa itens melhores, sobe de nível, desbloqueia habilidades.
5. Avança de ato/dificuldade quando a wave atual está muito fácil.
6. Deixa rodando em background; recebe notificação de loot raro.

### 3.3 Sistemas Principais

#### A. Sistema de Combate (Auto-battle)
- **Formação:** Até 3 heróis simultâneos.
- **Alvo:** Heróis atacam o monstro mais próximo ou com menor HP (configurável por classe).
- **Progressão de Wave:** Cada ato tem 100 waves. A cada 10 waves, boss com loot garantido.
- **Dano:** Baseado em ATK do herói + bônus de itens - DEF do monstro.
- **Crítico:** Chance base 5% + bônus de itens/habilidades.
- **Morte:** Se herói morre, revive automaticamente em 30s (ou instantâneo via anúncio).

#### B. Sistema de Classes (6 iniciais)
| Classe | Papel | Stat Principal | Mecânica Única |
|--------|-------|---------------|----------------|
| Vanguard | Tanque | DEF/VIT | Provoca inimigos, reduz dano em área |
| Elementalist | Dano mágico | INT | Ataques em área, elementos (fogo/gelo/raio) |
| Sharpshooter | Dano físico dist. | DEX | Alta chance de crítico, ignora parte da DEF |
| Medtech | Suporte | INT/VIT | Cura o time, buffs de velocidade de ataque |
| Tracker | Dano físico melee | AGI | Ataques rápidos, bleed (dano ao longo do tempo) |
| Berserker | Dano brute | STR | Dano aumenta conforme HP diminui |

#### C. Sistema de Loot (Procedural)
- **Tipos:** Arma, Armadura, Elmo, Luvas, Botas, Amuleto, Anel.
- **Raridades:**  
  `Bronze → Prata → Ouro → Épico → Lendário → Mítico → Transcendental → Cósmico`
- **Atributos por item:**  
  - Prefixo principal (ex: +ATK, +DEF, +HP)  
  - 0-3 sufixos aleatórios (ex: +%Crítico, +Velocidade, +Resistência a Fogo)
- **Item Level (iLv):** Escala com a wave atual. Itens de wave 500 são drasticamente melhores que wave 10.
- **Auto-loot:** Itens vão para inventário automático. Inventário limpo a cada 50 slots (venda automática de Bronze/Prata).

#### D. Sistema de Cubo (Crafting)
- 3 itens da mesma raridade → 1 item da raridade superior (com atributos re-rolados).
- Adicionar "Essência" (drop raro) garante 1 sufixo específico.
- Sistema de "Imprimir" — salvar um item como "molde" para tentar recriar sua combinação de stats.

#### E. Árvore de Runas (Passivas)
- 200+ nós em árvore tipo "constelação".
- Pontos ganhos a cada nível de conta (não de herói).
- Nós desbloqueiam: +%dano, +%ouro, +%XP, novas mecânicas (ex: "Primeiro ataque de cada wave é crítico").
- Respecc custa ouro (escala com quantidade de respecs).

#### F. Sistema de Ato e Dificuldade
- **3 Atos** (Floresta, Caverna, Castelo/Cidadela).
- Cada ato tem 100 waves + boss final.
- Após completar Ato 3, desbloqueia **Dificuldade +1** (todas as stats dos monstros x1.5, loot iLv +10).
- Dificuldades ilimitadas (procedural scaling).

#### G. Sistema de Conta/Progressão Offline
- Cálculo de progresso offline: quando o jogador retorna, o jogo simula até 8 horas de combate idle.
- Fórmula: `ouro_ganho = (gold_per_second * offline_time * 0.8)` — penalidade de 20% para não incentivar só offline.
- Notificação push quando inventário está cheio ou quando dropa item Lendário+.

---

## 4. Especificação Técnica (Flutter + Flame)

### 4.1 Stack Tecnológico

```
Framework: Flutter 3.22+
Game Engine: flame ^1.18.0
State Management: flutter_riverpod ^2.5.0
Banco Local: hive ^2.2.3 (ou isar ^3.1.0 para queries complexas)
Notificações: flutter_local_notifications ^17.0.0
Widgets Android: home_widget ^0.6.0
Background: workmanager ^0.5.0 (para processamento offline)
Anúncios: google_mobile_ads ^5.0.0
IAP: in_app_purchase ^3.0.0
Analytics: firebase_analytics ^11.0.0
Crashlytics: firebase_crashlytics ^4.0.0
```

### 4.2 Arquitetura de Pastas

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── extensions/
├── data/
│   ├── models/              # Entidades puras (Item, Hero, Monster)
│   ├── repositories/        # Acesso a dados (Hive, Firebase)
│   └── datasources/
├── domain/
│   ├── entities/            # Regras de negócio core
│   ├── usecases/            # Casos de uso (EquipItem, CraftItem)
│   └── repositories/        # Interfaces
├── presentation/
│   ├── game/                # Camada Flame (GameWidget, components)
│   ├── screens/             # Telas Flutter (Inventário, Árvore de Runas)
│   ├── widgets/             # Componentes reutilizáveis
│   └── providers/           # Riverpod providers
└── services/
    ├── notification_service.dart
    ├── background_service.dart
    └── ad_service.dart
```

### 4.3 Estrutura de Dados (Modelos Principais)

```dart
// Item Model
class GameItem {
  final String id;               // UUID
  final ItemType type;           // weapon, armor, helmet, etc.
  final ItemRarity rarity;       // bronze → cosmic
  final int itemLevel;           // based on wave
  final int baseStat;            // ATK for weapon, DEF for armor, etc.
  final List<ItemAffix> affixes; // suffixes
  final bool isEquipped;
  final DateTime dropTimestamp;
}

// Hero Model
class Hero {
  final HeroClass heroClass;
  final int level;
  final int xp;
  final int xpToNext;
  final Stats stats;             // str, dex, int, vit, agi
  final GameItem? weapon;
  final GameItem? armor;
  // ... outros slots
  final List<Skill> unlockedSkills;
}

// Monster Model
class Monster {
  final MonsterType type;
  final int level;
  final Stats stats;
  final List<ItemRarity> possibleDrops;
  final double dropChanceModifier;
}

// Player Account
class PlayerAccount {
  final int accountLevel;
  final int runePoints;
  final List<RuneNode> unlockedRunes;
  final int highestWave;
  final int highestAct;
  final int highestDifficulty;
  final DateTime lastLogin;
}
```

### 4.4 Game Loop (Flame)

```dart
class IdleRpgGame extends FlameGame {
  late final CombatManager combatManager;
  late final LootManager lootManager;
  late final HeroParty heroParty;
  late final WaveManager waveManager;

  @override
  Future<void> onLoad() async {
    // Carregar spritesheets
    // Inicializar managers
    // Carregar estado salvo (Hive)
  }

  @override
  void update(double dt) {
    super.update(dt);
    combatManager.update(dt);   // Processa ataques auto
    waveManager.update(dt);       // Checa progressão de wave
    lootManager.processDrops(dt); // Calcula drops
  }
}
```

**Componentes Flame:**
- `HeroComponent`: SpriteComponent com animação de ataque/idle.
- `MonsterComponent`: SpriteComponent com animação de spawn/hit/death.
- `DamageNumberComponent`: TextComponent flutuante (dano/crítico/cura).
- `LootPopupComponent`: Notificação visual de drop raro.
- `BackgroundComponent`: Parallax ou tilemap estático.

### 4.5 Sistema de Salvamento

- **Frequência:** Auto-save a cada 30 segundos + onAppPause.
- **Tecnologia:** Hive (key-value, extremamente rápido, não bloqueia UI).
- **Estrutura:**
  ```
  box.put('playerAccount', account.toJson());
  box.put('heroes', heroes.map((h) => h.toJson()).toList());
  box.put('inventory', inventory.map((i) => i.toJson()).toList());
  box.put('lastSaveTimestamp', DateTime.now().millisecondsSinceEpoch);
  ```
- **Backup:** Firebase Firestore (opcional, para anti-cheat/cloud save).

### 4.6 Widget Android & Notificação Persistente

**Widget na Tela Inicial:**
- Usar `home_widget` package.
- Atualizar a cada 1 minuto via `WorkManager`.
- Mostrar: Ouro/segundo, Wave atual, Melhor herói, Último item lendário+ dropado.
- Tapping no widget abre o app direto na tela de combate.

**Notificação Persistente (Foreground Service):**
- Quando o app está em background, mostrar notificação persistente:
  - "Pixel Idle Quest — Wave 142 (Ato 2)"
  - Subtexto: "3 heróis em combate | 1.2k ouro/min"
  - Botões: "Abrir" | "Coletar Loot" (abre app)
- Implementar via `flutter_foreground_task` ou nativo (Android Service).

---

## 5. Monetização

| Tipo | Implementação | Preço/Modelo |
|------|--------------|--------------|
| Anúncios Rewarded | +50% ouro por 4h, Revive instantâneo, +1 slot de cubo | Grátis (visualização) |
| Anúncios Interstitial | A cada 5 transições de ato (não invasivo) | Grátis |
| IAP — Remover Ads | Remove intersticiais, mantém rewarded como opcional | R$ 14,90 |
| IAP — Pacote de Início | +1 herói extra, skin exclusiva, 500 gemas | R$ 9,90 |
| IAP — Gemas | Moeda premium para acelerar cubo, respec rápido | R$ 4,90 a R$ 89,90 |
| IAP — DLC Classe | Desbloqueia classe extra (ex: Necromancer) | R$ 6,90 cada |

**Regra:** Nunca bloquear progressão core atrás de paywall. Tudo deve ser farmável, gemas apenas aceleram.

---

## 6. Roadmap de Desenvolvimento (MVP em 12 semanas)

### Fase 1 — Fundação (Semanas 1-3)
- [ ] Setup Flutter + Flame + Riverpod
- [ ] Sistema de salvamento (Hive)
- [ ] Estrutura base do Game Loop (tela vazia com update rodando)
- [ ] Sprites placeholders (quadrados coloridos)
- [ ] 1 classe funcional (Vanguard), 1 monstro, 1 wave

### Fase 2 — Core Gameplay (Semanas 4-6)
- [ ] Sistema de combate completo (3 heróis, formação, targeting)
- [ ] Sistema de loot procedural (raridades, affixes, iLv)
- [ ] Inventário + equipar itens
- [ ] Progressão de wave e ato (3 atos, 100 waves cada)
- [ ] Cálculo de progresso offline (simulação)

### Fase 3 — Sistemas Avançados (Semanas 7-9)
- [ ] 6 classes completas com habilidades únicas
- [ ] Árvore de Runas (200 nós)
- [ ] Sistema de Cubo (crafting/upgrading)
- [ ] Múltiplas dificuldades (New Game+)
- [ ] Widget Android + Notificação persistente

### Fase 4 — Polimento e Monetização (Semanas 10-12)
- [ ] Pixel art final (ou assets comprados/licenciados)
- [ ] Animações de ataque, hit, death
- [ ] Integração AdMob (rewarded + interstitial)
- [ ] IAP (remover ads, gemas, DLCs)
- [ ] Firebase Analytics + Crashlytics
- [ ] Beta fechado (TestFlight/Internal Testing)

### Fase 5 — Pós-Launch
- [ ] Sistema de Clãs/Guildas
- [ ] Leaderboards semanais
- [ ] Eventos sazonais (2x ouro, drops especiais)
- [ ] Nova classe a cada 2 meses
- [ ] Endgame: Torre Infinita (waves sem limite, ranking)

---

## 7. Assets e Recursos Visuais

### 7.1 Estilo Visual
- **Resolução base:** 320x180 (16:9) — escala para tela do dispositivo.
- **Paleta:** Use uma paleta restrita (ex: 32 cores) para autenticidade pixel art.
- **Sprites:** 16x16 para personagens, 32x32 para bosses.
- **UI:** Minimalista, sem bordas arredondadas, fonte pixelada (Press Start 2P ou similar).

### 7.2 Onde conseguir assets (legais e gratuitos/low-cost)
- **Sprites:** itch.io (buscar "pixel art RPG sprite pack"), OpenGameArt, CraftPix.
- **Tilesets:** Same. Custo médio: $5-$20 por pack completo.
- **Música/SFX:** Freesound.org, OpenGameArt, ou compositores no Fiverr ($50-$150 por OST completa).
- **Fontes:** Google Fonts ("Press Start 2P", "VT323") — licença aberta.

### 7.3 Ferramentas Recomendadas
- **Arte:** Aseprite (pago, ~$20) ou LibreSprite (gratuito).
- **Áudio:** LMMS (gratuito) + Audacity.
- **Level Design:** Tiled Map Editor (gratuito, exporta para Flame via `flame_tiled`).

---

## 8. Considerações de Performance (Android)

- **Target FPS:** 30 FPS é suficiente para pixel art idle. Isso economiza bateria.
- **Otimização de sprites:** Use sprite sheets (não imagens individuais). Flame suporta `SpriteAnimation.fromFrameData`.
- **Gerenciamento de memória:** Limite o inventário em memória. Itens antigos (Bronze/Prata) devem ser auto-vendidos ou arquivados em disco.
- **Background:** O jogo NÃO roda em background de verdade (Android mata o processo). O `WorkManager` calcula o progresso offline e notifica o usuário.
- **Tamanho do APK:** Comprima sprites em WebP. Target final: < 30 MB.

---

## 9. Checklist Anti-Plágio (Antes de Publicar)

- [ ] Nenhum asset visual copiado do TBH ou de outros jogos sem licença.
- [ ] Nome do jogo, classes, monstros, itens e raridades são originais.
- [ ] Mecânica de "janela na taskbar" foi adaptada para Android (widget/notificação).
- [ ] Código é 100% seu (ou de packages open-source com licenças compatíveis).
- [ ] Música e SFX são originais ou licenciados.
- [ ] Termos de uso e Política de privacidade estão escritos.
- [ ] Não menciona o jogo original na descrição da Play Store.

---

## 10. Próximos Passos Imediatos

1. **Prototipe em 1 semana:** Use quadrados coloridos no lugar de sprites. Valide se o loop de combate é divertido.
2. **Defina a identidade visual:** Escolha o tema (fantasia tradicional, cyberpunk, etc.) antes de comprar assets.
3. **Crie uma conta de desenvolvedor Google Play** ($25 dólares, pagamento único).
4. **Configure Firebase** (gratuito para começar) para analytics e crash reports.
5. **Jogue mais idle RPGs** para entender o que funciona: "Clicker Heroes", "Idle Slayer", "Melvor Idle", "Leaf Blower Revolution".

---

*Documento gerado em 04/08/2026. Revisar stack tecnológico conforme evolução dos packages Flutter/Flame.*
