/// Enums de conteúdo do jogo. Os nomes serializados (`id`) são contrato de
/// persistência — mudá-los quebra saves existentes. Ver
/// contracts/persistence-save-schema.md.
library;

/// Os 7 tipos de slot de equipamento (R-M04-01).
enum ItemType {
  weapon('weapon'),
  armor('armor'),
  helmet('helmet'),
  gloves('gloves'),
  boots('boots'),
  amulet('amulet'),
  ring('ring');

  const ItemType(this.id);
  final String id;

  static ItemType fromId(String id) =>
      values.firstWhere((e) => e.id == id, orElse: () => ItemType.weapon);

  /// Prefixo principal coerente com o tipo (V-GI-02, CEN-M04-003).
  AffixType get primaryStat => switch (this) {
    ItemType.weapon => AffixType.attack,
    ItemType.armor || ItemType.helmet || ItemType.boots => AffixType.defense,
    ItemType.gloves => AffixType.attack,
    ItemType.amulet || ItemType.ring => AffixType.health,
  };
}

/// As 8 raridades, em ordem crescente (R-M04-02).
///
/// A ordem da declaração **é** a ordem de raridade: `index` é usado para
/// comparar e para promover no Cubo. Inserir um valor no meio reescreve o
/// significado de todos os saves — só acrescente ao fim.
enum ItemRarity {
  bronze('bronze'),
  prata('prata'),
  ouro('ouro'),
  epico('epico'),
  lendario('lendario'),
  mitico('mitico'),
  transcendental('transcendental'),
  cosmico('cosmico');

  const ItemRarity(this.id);
  final String id;

  static ItemRarity fromId(String id) =>
      values.firstWhere((e) => e.id == id, orElse: () => ItemRarity.bronze);

  bool get isMax => this == ItemRarity.cosmico;

  /// Raridade imediatamente superior, ou `null` se já é a máxima
  /// (R-M06-03, CEN-M06-E01).
  ItemRarity? get next => isMax ? null : values[index + 1];

  /// Elegível para venda automática ao lotar o inventário (R-M05-06).
  bool get isAutoSellable =>
      this == ItemRarity.bronze || this == ItemRarity.prata;

  /// Dispara destaque visual e notificação (CEN-M04-011, CEN-M11-007).
  bool get isRareHighlight => index >= ItemRarity.lendario.index;

  bool operator >(ItemRarity other) => index > other.index;
  bool operator <(ItemRarity other) => index < other.index;
}

/// Tipos de atributo que um prefixo ou sufixo pode conceder.
enum AffixType {
  attack('attack'),
  defense('defense'),
  health('health'),
  critChance('critChance'),
  critDamage('critDamage'),
  attackSpeed('attackSpeed'),
  goldFind('goldFind'),
  xpGain('xpGain'),
  fireResist('fireResist'),
  iceResist('iceResist'),
  lightningResist('lightningResist');

  const AffixType(this.id);
  final String id;

  static AffixType fromId(String id) =>
      values.firstWhere((e) => e.id == id, orElse: () => AffixType.attack);

  /// Sufixos sorteáveis em itens — exclui os prefixos principais, que são
  /// determinados pelo tipo do item, não sorteados.
  static List<AffixType> get suffixPool => const [
    critChance,
    critDamage,
    attackSpeed,
    goldFind,
    xpGain,
    fireResist,
    iceResist,
    lightningResist,
  ];
}

/// Papel da classe na formação (M02).
enum HeroRole { tank, magicDamage, rangedDamage, support, meleeDamage, brute }

/// Regra de escolha de alvo, definida por classe (R-M01-02).
enum TargetingRule { nearest, lowestHp }

/// Mecânica única de cada classe (M02). Sempre ativa, sem ativação manual.
enum ClassMechanic {
  taunt,
  areaElemental,
  defensePenetration,
  healAndHaste,
  bleed,
  rageOnLowHp,
}

/// Como o 4º slot de formação foi obtido (V-PA-02).
///
/// Este campo existe para distinguir CEN-M03-011 (concede o slot) de
/// CEN-M03-012 (concede 500 gemas de compensação). Sem ele os dois casos são
/// indistinguíveis no nível 25.
enum FourthSlotSource {
  none('none'),
  accountLevel('accountLevel'),
  purchase('purchase');

  const FourthSlotSource(this.id);
  final String id;

  static FourthSlotSource fromId(String id) => values.firstWhere(
    (e) => e.id == id,
    orElse: () => FourthSlotSource.none,
  );
}
