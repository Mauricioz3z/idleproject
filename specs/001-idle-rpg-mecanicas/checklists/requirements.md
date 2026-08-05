# Specification Quality Checklist: Mecânicas do Idle RPG

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-04
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Format Compliance (requisito explícito do usuário)

- [x] Cada mecânica de `specification.md` tem arquivo próprio em `mechanics/`
- [x] Todos os cenários usam estritamente **Given** / **When** / **Then** (com **And** quando necessário)
- [x] Todo cenário tem identificador único (`CEN-Mxx-nnn`)
- [x] Cada arquivo declara origem no `specification.md`, regras, cenários, casos de borda, critérios de sucesso e suposições
- [x] Cenários são verificáveis sem conhecimento de implementação

## Cobertura de `specification.md`

| Seção de origem | Mecânica | Coberta |
|-----------------|----------|---------|
| §3.3.A Combate | M01 | Sim |
| §3.3.B Classes | M02, M03 | Sim |
| §3.3.C Loot | M04, M05 | Sim |
| §3.3.D Cubo | M06 | Sim |
| §3.3.E Runas | M07, M03 | Sim |
| §3.3.F Ato e Dificuldade | M08 | Sim |
| §3.3.G Offline | M09, M11 | Sim |
| §4.5 Salvamento | M10 | Sim |
| §4.6 Widget/Notificação | M11 | Sim |
| §5 Monetização | M12 | Sim |
| §1 Tecnologia, §2 Legal, §4.1–4.4 Arquitetura, §6 Roadmap, §7 Assets, §8 Performance, §9 Anti-plágio, §10 Próximos passos | — | Fora de escopo: não são mecânicas de jogo |

## Notes

**Iteração 1 (2026-08-04)** — Validação executada. Resultado:

- Todos os itens de Content Quality, Feature Readiness, Format Compliance e Cobertura passam.
- **1 item pendente**: 1 marcador `[NEEDS CLARIFICATION]` em FR-028 / M12, sobre o significado de "+1 herói extra" no Pacote de Início.
- Todas as demais lacunas de `specification.md` (multiplicador de crítico, dano mínimo, fórmulas de escalonamento, critério de "melhor herói", proteção de itens na venda automática) foram resolvidas por defaults documentados nas seções **Suposições** de cada arquivo.

**Iteração 2 (2026-08-04)** — Clarificação resolvida pelo usuário. Resultado:

- **Todos os 17 itens passam.** Nenhum marcador `[NEEDS CLARIFICATION]` permanece.
- Decisão registrada: o 4º slot de formação existe e é desbloqueado gratuitamente no **nível de conta 25**; o Pacote de Início apenas **antecipa** o desbloqueio. Limite absoluto de 4 heróis simultâneos, inultrapassável por compra ou anúncio. Quem antecipou por compra recebe compensação ao atingir o marco gratuito.
- Arquivos atualizados: `spec.md` (FR-001, FR-028, Key Entities, Assumptions), `M01` (R-M01-01/01b, CEN-M01-012/012b/012c), `M02` (CEN-M02-010), `M03` (R-M03-09/10, CEN-M03-011/012/013, renumeração de CEN-M03-014), `M12` (R-M12-09/10/11, catálogo, CEN-M12-012/013/014/015, renumeração de CEN-M12-016).
- O marco de nível 25 é valor de balanceamento inicial, ajustável — registrado como suposição em `spec.md`, `M03` e `M12`.
- Spec pronta para `/speckit-plan`.

**Iteração 3 (2026-08-04)** — Remediação pós-`/speckit-analyze`. Resultado:

- **Todos os itens continuam passando.** Nenhum marcador `[NEEDS CLARIFICATION]` foi reintroduzido.
- Lacunas corrigidas: `Essence` passou a existir como entidade com via de obtenção (FR-013, R-M04-12/13, CEN-M04-013); gemas ganharam requisito e implementação (FR-029); FR-023 e SC-006 foram reescritos para não prometer cadência que o Android não permite; a jornada de monetização virou User Story 7; a drenagem de `pendingDrops` ficou explícita (V-INV-04).
- Ambiguidades resolvidas por default documentado: compensação de **500 gemas** (R-M03-11, R-M12-11, V-ENT-05) e **aparelho de referência** de 4 GB / SoC de entrada / Android 10 (SC-009).
- Contagem de cenários: **181** (M04 ganhou CEN-M04-013).
- **Pendente, fora do escopo desta iteração**: `.specify/memory/constitution.md` continua sendo o template não preenchido. Requer `/speckit-constitution` com decisão do responsável pelo projeto.
