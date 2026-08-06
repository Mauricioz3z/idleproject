package com.pixelidle.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import com.pixelidle.pixel_idle_quest.MainActivity
import com.pixelidle.pixel_idle_quest.R
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.pow

/**
 * Widget de status na tela inicial (M11).
 *
 * O ponto não óbvio deste provider: ele **projeta** o ouro no instante em que
 * desenha, em vez de exibir o que o app gravou. Fora de um serviço em primeiro
 * plano o Android impõe piso de ~15 minutos entre atualizações, então um retrato
 * congelado ficaria visivelmente errado. Como o estado do jogo fechado é função
 * determinística de (save, tempo decorrido), dá para recalcular aqui — com a
 * mesma fórmula de M09, o mesmo teto de 8 h e a mesma penalidade de 0,8.
 *
 * O widget nunca promete mais do que o jogo vai conceder na reabertura.
 */
class IdleStatusWidgetProvider : AppWidgetProvider() {

    private companion object {
        const val KEY_GOLD_PER_SEC = "w_goldPerSec"
        const val KEY_ACT = "w_act"
        const val KEY_WAVE = "w_wave"
        const val KEY_DIFFICULTY = "w_difficulty"
        const val KEY_BEST_HERO_NAME = "w_bestHeroName"
        const val KEY_BEST_HERO_LEVEL = "w_bestHeroLevel"
        const val KEY_LAST_RARE_NAME = "w_lastRareName"
        const val KEY_LAST_RARE_RARITY = "w_lastRareRarity"
        const val KEY_PROJECTION_BASE_MS = "w_projectionBaseMs"
        const val KEY_GOLD_PER_SEC_RAW = "w_goldPerSecRaw"

        /** R-M09-02: teto de 8 h, igual ao do simulador. */
        const val MAX_OFFLINE_SECONDS = 8 * 60 * 60

        /** R-M09-04: o jogo passivo rende 80% do ativo. */
        const val OFFLINE_PENALTY = 0.8

        val RARITY_COLORS = mapOf(
            "bronze" to Color.parseColor("#9C7A55"),
            "prata" to Color.parseColor("#B9BEC7"),
            "ouro" to Color.parseColor("#E8B44A"),
            "epico" to Color.parseColor("#9B3FBF"),
            "lendario" to Color.parseColor("#E8702A"),
            "mitico" to Color.parseColor("#D24B4B"),
            "transcendental" to Color.parseColor("#4AC5E8"),
            "cosmico" to Color.parseColor("#7BE88C"),
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // CEN-M11-E03: todos os widgets na tela recebem o mesmo estado, porque
        // todos leem a mesma origem e projetam no mesmo instante.
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_idle_status)
        val data = HomeWidgetPlugin.getData(context)

        val baseMs = data.getLong(KEY_PROJECTION_BASE_MS, 0L).let {
            // `home_widget` pode gravar como Int quando o valor cabe.
            if (it != 0L) it else data.getInt(KEY_PROJECTION_BASE_MS, 0).toLong()
        }
        val wave = data.getInt(KEY_WAVE, 0)

        if (baseMs <= 0L || wave <= 0) {
            renderEmptyState(context, views)
            return views
        }

        val act = data.getInt(KEY_ACT, 1)
        val difficulty = data.getInt(KEY_DIFFICULTY, 1)
        val heroName = data.getString(KEY_BEST_HERO_NAME, "") ?: ""
        val heroLevel = data.getInt(KEY_BEST_HERO_LEVEL, 0)
        val rareName = data.getString(KEY_LAST_RARE_NAME, "") ?: ""
        val rareRarity = data.getString(KEY_LAST_RARE_RARITY, "") ?: ""
        val goldPerSecRaw = data.getString(KEY_GOLD_PER_SEC_RAW, "") ?: ""
        val goldPerSecLabel = data.getString(KEY_GOLD_PER_SEC, "0") ?: "0"

        views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
        views.setViewVisibility(R.id.widget_content, android.view.View.VISIBLE)

        views.setTextViewText(R.id.widget_wave, "Wave $wave")
        views.setTextViewText(
            R.id.widget_act,
            if (difficulty > 1) "Ato $act · Dif. $difficulty" else "Ato $act",
        )
        views.setTextViewText(R.id.widget_gold_rate, "$goldPerSecLabel ouro/s")

        views.setTextViewText(
            R.id.widget_hero,
            if (heroName.isEmpty()) "—" else "$heroName Nv $heroLevel",
        )

        if (rareName.isEmpty()) {
            views.setTextViewText(R.id.widget_rare, "nenhum item raro ainda")
            views.setTextColor(R.id.widget_rare, Color.parseColor("#B4AAC6"))
        } else {
            views.setTextViewText(R.id.widget_rare, rareName)
            views.setTextColor(
                R.id.widget_rare,
                RARITY_COLORS[rareRarity] ?: Color.WHITE,
            )
        }

        views.setTextViewText(
            R.id.widget_projected,
            "+${formatCompact(projectedGain(goldPerSecRaw, baseMs))} desde o último acesso",
        )

        // CEN-M11-003 / SC-M11-02: uma interação leva ao combate.
        views.setOnClickPendingIntent(
            R.id.widget_root,
            launchIntent(context, "pixelidle://combat"),
        )

        return views
    }

    private fun renderEmptyState(context: Context, views: RemoteViews) {
        // CEN-M11-011: convite, nunca zeros que pareceriam progresso real.
        views.setViewVisibility(R.id.widget_content, android.view.View.GONE)
        views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            launchIntent(context, "pixelidle://combat"),
        )
    }

    /**
     * Ouro acumulado desde o último estado real, pela fórmula de M09.
     *
     * Relógio atrasado devolve zero em vez de valor negativo (CEN-M09-E02), e o
     * intervalo é limitado a 8 h (R-M09-02) — as mesmas duas bordas do
     * simulador, porque o número exibido aqui é o que o resumo vai confirmar.
     */
    private fun projectedGain(goldPerSecRaw: String, baseMs: Long): Double {
        val perSecond = decodeGameNumber(goldPerSecRaw)
        if (perSecond <= 0.0) return 0.0

        val elapsedSeconds = (System.currentTimeMillis() - baseMs) / 1000.0
        if (elapsedSeconds <= 0) return 0.0

        val capped = minOf(elapsedSeconds, MAX_OFFLINE_SECONDS.toDouble())
        return perSecond * capped * OFFLINE_PENALTY
    }

    /** Formato `mantissa:expoente`, escrito por `HomeWidgetService`. */
    private fun decodeGameNumber(raw: String): Double {
        val parts = raw.split(":")
        if (parts.size != 2) return 0.0
        val mantissa = parts[0].toDoubleOrNull() ?: return 0.0
        val exponent = parts[1].toIntOrNull() ?: return 0.0
        // Acima disso o valor não cabe em Double; o widget mostra o teto em vez
        // de infinito, e o número exato continua correto dentro do jogo.
        if (exponent > 300) return Double.MAX_VALUE
        return mantissa * 10.0.pow(exponent)
    }

    /** Mesma escala curta do app: 1.2K, 3.4M, 5.6B. */
    private fun formatCompact(value: Double): String {
        if (value <= 0) return "0"
        if (value < 1000) return value.toInt().toString()

        val suffixes = listOf("", "K", "M", "B", "T", "aa", "ab", "ac")
        val tier = floor(log10(value) / 3).toInt().coerceAtMost(suffixes.size - 1)
        val scaled = value / 10.0.pow(tier * 3)
        return String.format("%.1f%s", scaled, suffixes[tier])
    }

    private fun launchIntent(context: Context, uri: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(uri),
        )

    override fun onEnabled(context: Context) {
        // Primeiro widget adicionado: nada a fazer além de deixar o onUpdate
        // desenhar. O payload chega quando o app rodar.
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
    }
}
