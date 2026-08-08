package id.kirain.app.kirain

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Renders the "sisa budget Wajib/Keinginan" summary pushed from Dart via
 * `HomeWidget.saveWidgetData` (see lib/features/home/data/home_widget_sync.dart)
 * and offers a one-tap shortcut into Catat, per CLAUDE.md's "Widget home
 * screen — ringkasan sisa budget + quick-add".
 */
class KirainWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val placeholder = context.getString(R.string.widget_placeholder)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.kirain_widget)

            views.setTextViewText(
                R.id.widget_wajib_remaining,
                widgetData.getString("wajib_remaining", placeholder),
            )
            views.setTextViewText(
                R.id.widget_keinginan_remaining,
                widgetData.getString("keinginan_remaining", placeholder),
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            views.setOnClickPendingIntent(
                R.id.widget_catat_button,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("kirain://catat"),
                ),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
