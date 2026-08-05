# Quickstart — Validação das Mecânicas do Idle RPG

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04 | **Plan**: [plan.md](plan.md)

Guia para rodar e **provar** que as mecânicas funcionam. Não contém código de implementação — isso é a Fase 2 (`/speckit-tasks`) e a implementação. Aqui estão os comandos, os cenários de validação e os resultados esperados.

> **Estado atual do repositório**: só existem documentos. Não há projeto Flutter ainda. A seção 1 é o que a primeira leva de tarefas precisa produzir para que o restante deste guia passe a ser executável.

---

## 1. Pré-requisitos

| Item | Versão | Verificação |
|---|---|---|
| Flutter SDK | 3.22+ | `flutter --version` |
| Dart | 3.4+ | incluso no Flutter |
| Android SDK | API 24+, build-tools 34 | `flutter doctor` |
| Dispositivo ou emulador | Android 7.0+ | `flutter devices` |
| **Aparelho de referência** | 4 GB RAM, SoC de entrada, Android 10 | Obrigatório para medir desempenho |

Os números de desempenho deste guia — 30 FPS sustentados e resumo offline em ≤3 s — valem no **aparelho de referência** definido em [plan.md](plan.md), não no aparelho de desenvolvimento. Medir em um topo de linha e declarar aprovado é o jeito mais fácil de entregar um jogo que engasga no aparelho da maioria dos jogadores.

```bash
flutter doctor          # tudo verde na seção Android antes de seguir
flutter pub get
```

Para os cenários de widget e notificação é necessário **dispositivo ou emulador real**, não apenas testes headless — o piso de agendamento do Android (research R4) não se reproduz em teste unitário.

---

## 2. Camadas de validação

A validação é dividida em três, do mais barato ao mais caro. Rode nessa ordem: se a primeira falha, as outras não dizem nada de útil.

| Camada | Alvo | Comando | Tempo esperado |
|---|---|---|---|
| Domínio | ~160 dos 180 cenários | `flutter test test/domain/` | segundos |
| Dados | Serialização e migração | `flutter test test/data/` | segundos |
| Integração | Plataforma Android | `flutter test integration_test/` | minutos, exige dispositivo |

```bash
flutter test                      # domínio + dados + apresentação
flutter test --coverage           # relatório em coverage/lcov.info
flutter test integration_test/    # requer dispositivo conectado
```

### Rastreabilidade de cenário

Cada teste de domínio é nomeado pelo ID do cenário da spec, o que permite ir direto do teste ao parágrafo que ele defende:

```bash
flutter test --plain-name "CEN-M01-003"    # dano mínimo garantido
flutter test test/domain/m09_offline_test.dart
```

Uma falha reporta `CEN-M09-003 — teto de 8 horas`, e o requisito violado está em [mechanics/M09-progressao-offline.md](mechanics/M09-progressao-offline.md). Contar testes por prefixo `CEN-Mxx` dá cobertura de mecânica direta.

---

## 3. Rodar o jogo

```bash
flutter run                                   # debug
flutter run --profile                         # medir FPS — alvo 30 (research R10)
flutter build apk --release --split-per-abi   # alvo < 30 MB por ABI
```

---

## 4. Cenários de validação manual

Os que não cabem em teste automatizado, ou cujo valor está em ver funcionando.

### V1 — O laço idle funciona sozinho (M01, M03, M04)

1. Instale limpo e abra o app.
2. Não toque em nada por 5 minutos.

**Esperado**: primeiro monstro morto em ≤10 s (SC-M01-01); ouro e XP subindo; ao menos 1 item no inventário; ao menos 1 wave avançada (SC-M09-02 e SC-M01-02). Nenhum toque foi necessário em momento algum.

### V2 — Loot melhora o personagem (M04, M05)

1. Jogue até ter duas armas do mesmo slot com ATK diferente.
2. Abra o inventário e compare-as.
3. Equipe a melhor.

**Esperado**: a comparação mostra a diferença por atributo com ganho e perda distinguíveis; equipar sobe o ATK efetivo imediatamente, sem reiniciar a wave; a arma anterior volta ao inventário (CEN-M05-003); monstros passam a morrer mais rápido.

**Conte as interações**: da tela de combate até o item equipado devem bastar **3 toques** (SC-007). Se forem mais, o fluxo de inventário precisa encurtar — é um critério de sucesso da spec, não preferência estética.

### V2b — Progressão sem decisões obrigatórias (M08)

Jogue do início até a wave 100 do Ato 1 sem tomar nenhuma decisão além de equipar itens.

**Esperado**: nenhuma tela exige escolha, configuração ou desbloqueio para prosseguir (SC-008). Qualquer ponto que force uma decisão é falha.

### V3 — Progresso offline (M09)

1. Jogue até estabilizar uma taxa de ouro/segundo e anote-a.
2. Force o fechamento do app.
3. Avance o relógio do dispositivo em 2 horas.
4. Reabra.

**Esperado**: resumo em ≤3 s (SC-M09-01) com ouro ≈ `taxa × 7200 × 0,8`; waves avançadas e itens listados; lendários+ destacados. Repita com 12 h: o resumo deve indicar teto de 8 h (CEN-M09-003).

**Contraprova obrigatória**: atrase o relógio em 3 h e reabra. Esperado: relatório vazio, **nenhum recurso subtraído** (CEN-M09-E02). É o cenário que costuma passar despercebido e destrói saves.

### V4 — Persistência (M10)

1. Equipe itens, desbloqueie nós de runa, avance de ato.
2. Force o encerramento pelo gerenciador de apps sem passar por pausa limpa.
3. Reabra.

**Esperado**: heróis, equipamentos, inventário, runas e ato preservados; perda ≤30 s (SC-M10-01); a wave reinicia do começo, o que é o comportamento correto (CEN-M10-E01), não um bug.

### V5 — Widget e notificação (M11) — *o cenário que mais revela problema real*

1. Adicione o widget à tela inicial.
2. Com o app em primeiro plano, observe por 3 minutos.
3. Mande o app para segundo plano com a notificação persistente ativa; observe por 3 minutos.
4. Force o encerramento do app e observe o widget por 20 minutos.

**Esperado**: nos passos 2 e 3, atualização a cada ~1 min (FR-023). No passo 4, a atualização real cai para ≥15 min — **mas os valores exibidos continuam coerentes**, porque o widget projeta a partir de `w_projectionBaseMs` e `w_goldPerSecRaw` ([contracts/platform-android.md](contracts/platform-android.md) §1). Widget congelado no passo 4 significa que a projeção não foi implementada; é falha, não limitação da plataforma.

Toque no widget: abre direto no combate, sem menu (CEN-M11-003).

### V6 — O 4º slot é alcançável sem pagar (M03, M12)

1. Em conta nova, sem nenhuma compra, leve a conta ao nível 25.

**Esperado**: 4º slot desbloqueado gratuitamente; é possível posicionar 4 heróis (CEN-M03-011, CEN-M12-013).

2. Em outra conta nova, compre o Pacote de Início em ambiente de teste e depois alcance o nível 25.

**Esperado**: slot liberado na compra; ao chegar ao nível 25, **compensação em gemas, não um quinto slot** (CEN-M03-012, CEN-M12-015). Um quinto slot aqui viola V-PA-01 e é bug crítico.

### V7 — Nada de progressão atrás de paywall (M12)

Com uma conta que nunca assistiu anúncio nem comprou nada, verifique que waves, atos, dificuldades, raridades e nós de runa permanecem alcançáveis e que nenhuma tela exige pagamento para continuar (SC-M12-01, CEN-M12-010).

---

## 5. Verificações de determinismo

Estas sustentam a arquitetura inteira (research R3 e R5). Se falharem, o problema é estrutural, não um detalhe:

```bash
flutter test --plain-name "determinism"
```

- **Mesma semente, mesmo loot**: `LootGenerator` com semente e contador idênticos produz a sequência idêntica de itens.
- **Online ≡ offline**: simular 1 h por `OfflineSimulator` produz o mesmo ouro, waves e loot que rodar `CombatEngine.tick` pelo tempo equivalente, dentro da tolerância declarada. Divergência aqui significa que as duas trilhas de código se separaram — o risco que a arquitetura de `plan.md` existe para eliminar.
- **Independente de FPS**: 300 ticks de 33 ms e 150 ticks de 66 ms produzem o mesmo resultado de combate.

---

## 6. Portões de qualidade antes de considerar a feature pronta

- [ ] `flutter test` verde, com um teste por cenário `CEN-Mxx-nnn` de domínio
- [ ] `flutter test integration_test/` verde em dispositivo real
- [ ] V1 a V7 validados manualmente no aparelho de referência, incluindo V2b
- [ ] Verificações de determinismo da seção 5 passando
- [ ] 30 FPS sustentados em `--profile` com 4 heróis e 8 monstros
- [ ] APK release < 30 MB por ABI
- [ ] Resumo offline de 8 h em ≤3 s em dispositivo de entrada
- [ ] `flutter analyze` sem avisos
