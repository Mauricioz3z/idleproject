# Checklist Anti-Plágio e Pré-Publicação

**Origem**: `specification.md` §9 | **Tarefa**: T151 | **Percorrido em**: 2026-08-06

Percurso do checklist de §9 com evidência do que foi verificado no repositório.
Itens que dependem de decisão humana ou de material que ainda não existe ficam
explicitamente **em aberto** — marcar um item verde sem evidência é pior que
deixá-lo vermelho, porque some do radar.

## Situação por item

| # | Item de §9 | Situação | Evidência |
|---|---|---|---|
| 1 | Nenhum asset visual copiado | ✅ **Verificado** | `assets/` não contém nenhum arquivo binário. Toda a apresentação é desenhada em código (retângulos, silhuetas, `CustomPaint`). Não há o que ter sido copiado. |
| 2 | Nomes originais | ⚠️ **Verificado, com ressalva** | Classes: Vanguard, Elementalist, Sharpshooter, Medtech, Tracker, Berserker. Monstros: Broto Rastejante, Espreitador da Mata, Sarça Torcida, Guardião do Bosque, Roedor das Fendas, Cristalino, Bruto de Pedra, Fauce do Abismo, Sentinela Enferrujada, Carcereiro Pálido, Espectro de Guerra, Tirano da Cidadela. Raridades: Bronze→Cósmico. São descritivos e genéricos do gênero, não retirados de outro jogo. **Falta busca de marca registrada** para o nome do jogo — ver "Em aberto". |
| 3 | Taskbar adaptada para Android | ✅ **Verificado** | Entregue como widget de tela inicial + notificação persistente (M11, Fase 7). A limitação de agendamento do Android está tratada por projeção no desenho, documentada em `research.md` R4 — não é cópia de mecanismo, é solução de plataforma. |
| 4 | Código 100% próprio ou com licença compatível | ✅ **Verificado** | Todo o código de `lib/` e `android/` foi escrito para este projeto. Dependências e licenças na tabela abaixo — todas permissivas. |
| 5 | Música e SFX originais ou licenciados | ➖ **Não aplicável hoje** | O jogo não tem áudio. Quando tiver, este item volta a valer. |
| 6 | Termos de uso e Política de privacidade | ❌ **Em aberto** | Não existem no repositório. **Bloqueia publicação**: o app coleta dados via Firebase Analytics/Crashlytics e exibe anúncios do AdMob, o que torna a política de privacidade exigência da Play Store, não opção. |
| 7 | Descrição da Play Store não menciona o jogo original | ➖ **Pendente por inexistência** | Não há listagem de loja escrita. Verificar quando existir. |

## Licenças das dependências

Todas permissivas e compatíveis com distribuição comercial fechada:

| Pacote | Licença |
|---|---|
| flame, flutter_riverpod, flutter_foreground_task, workmanager, cupertino_icons | MIT |
| hive, hive_flutter, google_mobile_ads, fake_async | Apache 2.0 |
| firebase_core, firebase_analytics, firebase_crashlytics, in_app_purchase, flutter_lints, test | BSD-3-Clause |
| flutter_local_notifications, home_widget | BSD-3-Clause |

Nenhuma dependência copyleft (GPL/LGPL/AGPL). Nenhuma exige abertura do código
do jogo.

## Em aberto — exige decisão ou ação humana

1. **Política de privacidade e termos de uso** (item 6). Bloqueiam a publicação
   por exigência da Play Store, dada a presença de AdMob e Firebase. Precisam
   declarar, no mínimo: coleta de identificador de publicidade, dados de
   travamento e eventos de uso.
2. **Busca de marca registrada** para "Pixel Idle Quest" e para os nomes das
   seis classes, nas jurisdições de publicação. Nenhuma ferramenta do repositório
   substitui essa consulta.
3. **Revisão humana do item 2**: a semelhança conceitual com o jogo de origem
   citado em `specification.md` é de **gênero** (idle ARPG com loot procedural,
   cubo de fusão e árvore de passivas), o que não é protegível. Confirmar que
   nenhum texto, nome próprio ou arte foi reaproveitado é julgamento de quem
   conhece o material de origem — não é verificável a partir deste repositório.
4. **Descrição da loja** (item 7), quando escrita.

## Conclusão

Dos 7 itens, **3 verificados**, 2 não aplicáveis hoje, **1 bloqueador** (política
de privacidade) e 1 pendente de material que ainda não existe. Nada encontrado no
repositório sugere reaproveitamento indevido de terceiros.
