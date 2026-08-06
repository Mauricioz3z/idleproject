import 'package:home_widget/home_widget.dart';

import '../core/numeric/game_number.dart';
import '../core/numeric/number_format.dart';
import '../domain/engines/state_projector.dart';

/// Escreve o payload do widget de tela inicial
/// (contracts/platform-android.md §1).
///
/// Chaves planas porque o `AppWidgetProvider` em Kotlin lê `SharedPreferences`
/// direto e não desserializa JSON aninhado de forma conveniente.
class HomeWidgetService {
  const HomeWidgetService({
    this.appGroupId = 'group.com.pixelidle',
    this.androidProviderName = 'IdleStatusWidgetProvider',
  });

  final String appGroupId;
  final String androidProviderName;

  // Nomes de chave são contrato com o Kotlin: mudar aqui exige mudar lá.
  static const String keyGoldPerSec = 'w_goldPerSec';
  static const String keyAct = 'w_act';
  static const String keyWave = 'w_wave';
  static const String keyDifficulty = 'w_difficulty';
  static const String keyBestHeroName = 'w_bestHeroName';
  static const String keyBestHeroLevel = 'w_bestHeroLevel';
  static const String keyLastRareName = 'w_lastRareName';
  static const String keyLastRareRarity = 'w_lastRareRarity';
  static const String keyProjectionBaseMs = 'w_projectionBaseMs';
  static const String keyGoldPerSecRaw = 'w_goldPerSecRaw';

  /// Serializa um [GameNumber] como `mantissa:expoente`.
  ///
  /// O Kotlin precisa **calcular** com este valor, não só exibi-lo, então a
  /// forma abreviada não serve. E `double` puro estouraria nas dificuldades
  /// altas, que é o motivo de `GameNumber` existir (research.md R6).
  static String encodeNumber(GameNumber value) =>
      '${value.mantissa}:${value.exponent}';

  static GameNumber decodeNumber(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return GameNumber.zero;
    final mantissa = double.tryParse(parts[0]) ?? 0;
    final exponent = int.tryParse(parts[1]) ?? 0;
    return GameNumber(mantissa, exponent);
  }

  /// Grava a projeção e pede o redesenho.
  ///
  /// [projection] sem save escreve o estado neutro: o provider mostra o convite
  /// "toque para começar" em vez de zeros que pareceriam progresso perdido
  /// (CEN-M11-011).
  Future<void> publish(ProjectedState projection) async {
    await HomeWidget.setAppGroupId(appGroupId);

    if (!projection.hasSave) {
      await _clear();
      await _requestUpdate();
      return;
    }

    final position = projection.position!;
    await Future.wait([
      HomeWidget.saveWidgetData<String>(
        keyGoldPerSec,
        NumberFormat.compact(projection.goldPerSecond),
      ),
      HomeWidget.saveWidgetData<int>(keyAct, position.act),
      HomeWidget.saveWidgetData<int>(keyWave, position.globalWave),
      HomeWidget.saveWidgetData<int>(keyDifficulty, position.difficulty),
      HomeWidget.saveWidgetData<String>(
        keyBestHeroName,
        projection.bestHeroClassId ?? '',
      ),
      HomeWidget.saveWidgetData<int>(
        keyBestHeroLevel,
        projection.bestHeroLevel,
      ),
      HomeWidget.saveWidgetData<String>(
        keyLastRareName,
        projection.lastRare == null
            ? ''
            : '${projection.lastRare!.rarity.id} '
                  '${projection.lastRare!.type.id}',
      ),
      HomeWidget.saveWidgetData<String>(
        keyLastRareRarity,
        projection.lastRare?.rarity.id ?? '',
      ),
      // As duas chaves da projeção: com elas o provider recalcula o ouro no
      // instante do desenho, em vez de exibir um retrato de até 15 min atrás
      // (research.md R4).
      HomeWidget.saveWidgetData<int>(
        keyProjectionBaseMs,
        projection.baseTimestampMs,
      ),
      HomeWidget.saveWidgetData<String>(
        keyGoldPerSecRaw,
        encodeNumber(projection.goldPerSecond),
      ),
    ]);

    await _requestUpdate();
  }

  Future<void> _clear() async {
    await Future.wait([
      for (final key in const [
        keyGoldPerSec,
        keyBestHeroName,
        keyLastRareName,
        keyLastRareRarity,
        keyGoldPerSecRaw,
      ])
        HomeWidget.saveWidgetData<String>(key, ''),
      for (final key in const [
        keyAct,
        keyWave,
        keyDifficulty,
        keyBestHeroLevel,
        keyProjectionBaseMs,
      ])
        HomeWidget.saveWidgetData<int>(key, 0),
    ]);
  }

  Future<void> _requestUpdate() =>
      HomeWidget.updateWidget(androidName: androidProviderName);
}
