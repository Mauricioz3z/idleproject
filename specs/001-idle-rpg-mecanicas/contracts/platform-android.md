# Contract — Superfície Android

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04 | **Mecânica**: [M11](../mechanics/M11-widget-notificacao.md), [M12](../mechanics/M12-monetizacao-recompensas.md)

Contrato entre o app Flutter e a plataforma Android: payload do widget de tela inicial, notificações, tarefas de segundo plano, deep links e identificadores de monetização. É a fronteira onde o domínio determinístico encontra um sistema operacional que não dá garantias de agendamento.

---

## 1. Widget de tela inicial

### Payload

Escrito via `home_widget` em `SharedPreferences` compartilhado, lido pelo `AppWidgetProvider` em Kotlin. Chaves planas — o provider Android não desserializa JSON aninhado de forma conveniente.

| Chave | Tipo | Origem | Exemplo |
|---|---|---|---|
| `w_goldPerSec` | `String` | Formatado, já abreviado | `"1.2K"` |
| `w_act` | `int` | `ProgressPosition.act` | `2` |
| `w_wave` | `int` | `ProgressPosition.wave` | `143` |
| `w_difficulty` | `int` | `ProgressPosition.difficulty` | `1` |
| `w_bestHeroName` | `String` | Maior nível na formação | `"Vanguard"` |
| `w_bestHeroLevel` | `int` | | `31` |
| `w_lastRareName` | `String` | Último lendário+ | `"Elmo Mítico"` |
| `w_lastRareRarity` | `String` | Chave de cor | `"mitico"` |
| `w_projectionBaseMs` | `int` | Epoch do último estado real | `1785600000000` |
| `w_goldPerSecRaw` | `String` | `GameNumber` serializado | `"1.234:3"` |

**Por que as duas últimas chaves existem**: pelo achado R4 da pesquisa, fora de serviço em primeiro plano o Android impõe piso de ~15 minutos entre atualizações. Com `w_projectionBaseMs` e `w_goldPerSecRaw`, o provider Kotlin **projeta** o valor no instante em que desenha, em vez de exibir um retrato congelado. O jogador vê ouro coerente mesmo quando o sistema não deixou o app acordar.

A projeção no widget usa a mesma fórmula de M09, inclusive o teto de 8 h e a penalidade de 0,8. O widget nunca promete mais do que o jogo vai conceder.

### Cadência

| Estado do app | Mecanismo | Cadência |
|---|---|---|
| Primeiro plano | Chamada direta pós-tick | 1 min |
| Segundo plano com foreground service | `flutter_foreground_task` | 1 min |
| Encerrado | `WorkManager` periódico | ≥15 min (piso da plataforma) |

`updatePeriodMillis` no XML do provider fica em 1800000 (30 min) como rede de segurança; não é o caminho primário.

### Estado inicial

Sem save (widget adicionado antes da primeira abertura), todas as chaves ausentes → o provider renderiza o convite "Toque para começar" (CEN-M11-011). Nunca exibir zeros como se fossem estado real.

---

## 2. Notificações

### Persistente (foreground service)

Só existe com o app em segundo plano e com a opção habilitada (CEN-M11-010).

```
Título:   Pixel Idle Quest — Wave 143 (Ato 2)
Subtexto: 3 heróis em combate | 1.2k ouro/min
Ações:    [Abrir]  [Coletar Loot]
Canal:    idle_status   (IMPORTANCE_LOW, sem som, sem vibração)
Flags:    ongoing, silent
```

Ambas as ações abrem o app (R-M11-07). "Coletar Loot" leva ao resumo offline quando houver; nenhuma recompensa é concedida pela notificação em si.

### Push de eventos

| Evento | Canal | Gatilho |
|---|---|---|
| Item lendário+ obtido | `idle_loot` (DEFAULT) | CEN-M11-007 |
| Inventário cheio | `idle_inventory` (DEFAULT) | CEN-M11-008 |

**Permissão negada** (`POST_NOTIFICATIONS`, Android 13+): nenhuma notificação é exibida, e os eventos continuam registrados e visíveis no resumo ao abrir o app (CEN-M11-E01). Permissão nunca é pré-requisito de recompensa.

---

## 3. Tarefas de segundo plano

| Tarefa | Tipo | Intervalo | Responsabilidade |
|---|---|---|---|
| `refresh_widget` | `WorkManager` periódica | 15 min | Projetar estado e reescrever o payload |
| `detect_rare_events` | `WorkManager` periódica | 15 min | Avaliar loot raro / inventário cheio e notificar |
| `foreground_status` | `flutter_foreground_task` | 1 min | Notificação persistente + widget em cadência fina |

**Restrições que a implementação precisa respeitar:**

- Nenhuma dessas tarefas executa combate real (§8 de `specification.md`, CEN-M09-010). Elas projetam a partir do estado salvo; a resolução verdadeira acontece no `OfflineSimulator` quando o jogador reabre.
- Nenhuma delas grava estado de jogo. Só leem o save e escrevem payload de widget e notificações. Isso mantém uma única escritora do save e elimina a corrida de CEN-M10-E03.
- Otimização agressiva de bateria por fabricante pode suprimir as tarefas por completo. É comportamento aceito e coberto por CEN-M11-E02; a recuperação vem do cálculo offline na reabertura.

---

## 4. Deep links

| URI | Destino | Origem |
|---|---|---|
| `pixelidle://combat` | Tela de combate | Toque no widget (CEN-M11-003), ação "Abrir" |
| `pixelidle://offline-summary` | Resumo offline, ou combate se vazio | Ação "Coletar Loot" (CEN-M11-006) |
| `pixelidle://inventory` | Inventário | Notificação de inventário cheio |

Todos abrem direto no destino, sem passar por menu intermediário.

---

## 5. Monetização

### Anúncios (AdMob)

| Slot | Formato | Recompensa | Regra |
|---|---|---|---|
| `rw_gold_boost` | Rewarded | +50% ouro / 4 h | Estende validade se já ativo (V-ENT-01) |
| `rw_instant_revive` | Rewarded | Revive imediato | Cancela o timer de 30 s |
| `rw_cube_slot` | Rewarded | +1 slot de cubo | |
| `int_act_transition` | Interstitial | — | A cada 5 transições de ato; suprimido por `adsRemoved` |

Recompensa concedida **apenas** no callback de visualização completa. Fechamento antecipado não concede nada e não consome recurso (CEN-M12-004). Sem rede, a falha é comunicada e o jogo segue normalmente (CEN-M12-E01).

### Compras (Google Play Billing)

| Product ID | Tipo | Efeito |
|---|---|---|
| `remove_ads` | Não consumível | `adsRemoved = true` |
| `starter_pack` | Não consumível | Antecipa o 4º slot + skin + 500 gemas |
| `gems_small` … `gems_mega` | Consumível | Crédito de gemas |
| `dlc_class_<id>` | Não consumível | Desbloqueia classe |

**Restauração** (CEN-M12-E04): produtos não consumíveis são reconsultados no boot. `starter_pack` restaurado passa obrigatoriamente por `ProgressionService.evaluateFourthSlot` — se a conta já chegou ao nível 25 nesse meio-tempo, o resultado é compensação, não um quinto slot (V-PA-01).

Falha no processamento não cobra nem concede (CEN-M12-E03).

---

## 6. Manifesto e permissões

| Permissão | Motivo | Obrigatória |
|---|---|---|
| `INTERNET` | Anúncios, IAP, analytics | Sim |
| `POST_NOTIFICATIONS` | Notificações (Android 13+) | Não — degrada por CEN-M11-E01 |
| `FOREGROUND_SERVICE` | Notificação persistente | Sim, se a opção estiver ativa |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Exigida no Android 14+ | Sim, se a opção estiver ativa |
| `RECEIVE_BOOT_COMPLETED` | Reagendar WorkManager após reinício | Sim |

`SCHEDULE_EXACT_ALARM` **não** é solicitada — alarmes exatos foram descartados em research R4 por custo de bateria e atrito de permissão.

`minSdkVersion 24`, conforme §3.1 de `specification.md`.
