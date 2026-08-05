package id.temankereta.teman_kereta

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import java.text.DateFormat
import java.util.Date

class NextDepartureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(
                appWidgetId,
                TemanKeretaWidgetUpdater.nextDepartureViews(context, appWidgetId),
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH_NEXT_DEPARTURE) {
            // Deliberately refreshes only the last locally stored value. Network refreshes are
            // owned by Flutter and are never started silently by a home-screen widget.
            TemanKeretaWidgetUpdater.updateNextDeparture(context)
        }
    }

    companion object {
        const val ACTION_REFRESH_NEXT_DEPARTURE =
            "id.temankereta.teman_kereta.action.REFRESH_NEXT_DEPARTURE_WIDGET"
    }
}

class ActiveTripWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(
                appWidgetId,
                TemanKeretaWidgetUpdater.activeTripViews(context, appWidgetId),
            )
        }
    }
}

class DailyRouteWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(
                appWidgetId,
                TemanKeretaWidgetUpdater.dailyRouteViews(context, appWidgetId),
            )
        }
    }
}

class ServiceStatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(
                appWidgetId,
                TemanKeretaWidgetUpdater.serviceStatusViews(context, appWidgetId),
            )
        }
    }
}

internal object TemanKeretaWidgetUpdater {
    fun updateNextDeparture(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, NextDepartureWidgetProvider::class.java)
        manager.getAppWidgetIds(component).forEach { id ->
            manager.updateAppWidget(id, nextDepartureViews(context, id))
        }
    }

    fun updateActiveTrip(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, ActiveTripWidgetProvider::class.java)
        manager.getAppWidgetIds(component).forEach { id ->
            manager.updateAppWidget(id, activeTripViews(context, id))
        }
    }

    fun updateDailyRoute(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, DailyRouteWidgetProvider::class.java)
        manager.getAppWidgetIds(component).forEach { id ->
            manager.updateAppWidget(id, dailyRouteViews(context, id))
        }
    }

    fun updateServiceStatus(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, ServiceStatusWidgetProvider::class.java)
        manager.getAppWidgetIds(component).forEach { id ->
            manager.updateAppWidget(id, serviceStatusViews(context, id))
        }
    }

    fun nextDepartureViews(context: Context, appWidgetId: Int): RemoteViews {
        val prefs = NativeStateStore.preferences(context)
        val hasData = prefs.getBoolean(NativeStateStore.NEXT_HAS_DATA, false)
        val isDemo = prefs.getBoolean(NativeStateStore.NEXT_IS_DEMO, false)
        val station = prefs.getString(NativeStateStore.NEXT_STATION, null).orEmpty()
        val departureTime = prefs.getString(NativeStateStore.NEXT_TIME, null).orEmpty()
        val destination = prefs.getString(NativeStateStore.NEXT_DESTINATION, null).orEmpty()
        val status = prefs.getString(NativeStateStore.NEXT_STATUS, null).orEmpty()
        val updatedAt = prefs.getLong(NativeStateStore.NEXT_UPDATED_AT, 0L)

        return RemoteViews(context.packageName, R.layout.widget_next_departure).apply {
            setTextViewText(
                R.id.widget_next_departure_badge,
                context.getString(if (hasData && isDemo) R.string.widget_data_demo else R.string.widget_no_data_badge),
            )
            setViewVisibility(
                R.id.widget_next_departure_badge,
                if (!hasData || isDemo) View.VISIBLE else View.GONE,
            )
            setTextViewText(
                R.id.widget_next_departure_station,
                station.ifBlank { context.getString(R.string.widget_choose_station) },
            )
            setTextViewText(R.id.widget_next_departure_time, departureTime.ifBlank { "—" })
            setTextViewText(
                R.id.widget_next_departure_destination,
                destination.ifBlank { context.getString(R.string.widget_no_departure) },
            )
            setTextViewText(
                R.id.widget_next_departure_status,
                when {
                    !hasData -> context.getString(R.string.widget_open_to_configure)
                    status.isBlank() -> context.getString(R.string.widget_status_unavailable)
                    else -> status
                },
            )
            setTextViewText(
                R.id.widget_next_departure_updated,
                if (updatedAt > 0L) {
                    context.getString(R.string.widget_updated_at, formatTime(updatedAt))
                } else {
                    ""
                },
            )

            val openIntent = deepLinkPendingIntent(
                context,
                appWidgetId,
                Uri.parse("temankereta://app/departures?source=widget"),
            )
            setOnClickPendingIntent(R.id.widget_next_departure_root, openIntent)

            val refreshIntent = Intent(context, NextDepartureWidgetProvider::class.java).apply {
                action = NextDepartureWidgetProvider.ACTION_REFRESH_NEXT_DEPARTURE
                data = Uri.parse("temankereta://widget/refresh/next/$appWidgetId")
            }
            setOnClickPendingIntent(
                R.id.widget_next_departure_refresh,
                PendingIntent.getBroadcast(
                    context,
                    appWidgetId,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
    }

    fun activeTripViews(context: Context, appWidgetId: Int): RemoteViews {
        val prefs = NativeStateStore.preferences(context)
        val isActive = prefs.getBoolean(NativeStateStore.ACTIVE, false)
        val isDemo = prefs.getBoolean(NativeStateStore.ACTIVE_IS_DEMO, false)
        val line = prefs.getString(NativeStateStore.ACTIVE_LINE, null).orEmpty()
        val destination = prefs.getString(NativeStateStore.ACTIVE_DESTINATION, null).orEmpty()
        val current = prefs.getString(NativeStateStore.ACTIVE_CURRENT_STATION, null).orEmpty()
        val next = prefs.getString(NativeStateStore.ACTIVE_NEXT_STATION, null).orEmpty()
        val remaining = prefs.getInt(NativeStateStore.ACTIVE_REMAINING, 0).coerceAtLeast(0)
        val eta = prefs.getString(NativeStateStore.ACTIVE_ETA, null).orEmpty()
        val progress = (prefs.getFloat(NativeStateStore.ACTIVE_PROGRESS, 0f) * 100).toInt().coerceIn(0, 100)

        val route = when {
            !isActive -> context.getString(R.string.widget_no_active_trip)
            line.isNotBlank() && destination.isNotBlank() ->
                context.getString(R.string.widget_route_to, line, destination)
            line.isNotBlank() -> line
            destination.isNotBlank() -> destination
            else -> context.getString(R.string.widget_active_trip_title)
        }

        return RemoteViews(context.packageName, R.layout.widget_active_trip).apply {
            setTextViewText(
                R.id.widget_active_trip_badge,
                context.getString(if (isActive && isDemo) R.string.widget_data_demo else R.string.widget_no_data_badge),
            )
            setViewVisibility(
                R.id.widget_active_trip_badge,
                if (!isActive || isDemo) View.VISIBLE else View.GONE,
            )
            setTextViewText(R.id.widget_active_trip_route, route)
            setTextViewText(
                R.id.widget_active_trip_current,
                if (isActive && current.isNotBlank()) {
                    context.getString(R.string.widget_current_station, current)
                } else {
                    context.getString(R.string.widget_start_trip_in_app)
                },
            )
            setTextViewText(
                R.id.widget_active_trip_next,
                if (isActive && next.isNotBlank()) context.getString(R.string.widget_next_station, next) else "",
            )
            setTextViewText(
                R.id.widget_active_trip_remaining,
                if (!isActive) {
                    ""
                } else if (remaining == 1) {
                    context.getString(R.string.widget_one_remaining_station)
                } else {
                    context.getString(R.string.widget_remaining_stations, remaining)
                },
            )
            setTextViewText(
                R.id.widget_active_trip_eta,
                if (isActive && eta.isNotBlank()) context.getString(R.string.widget_eta, eta) else "",
            )
            setProgressBar(R.id.widget_active_trip_progress, 100, if (isActive) progress else 0, false)
            setTextViewText(
                R.id.widget_active_trip_open,
                context.getString(if (isActive) R.string.widget_open_trip else R.string.widget_open_app),
            )

            val openIntent = deepLinkPendingIntent(
                context,
                10_000 + appWidgetId,
                Uri.parse(
                    if (isActive) {
                        "temankereta://app/active-trip?source=widget"
                    } else {
                        "temankereta://app/home?source=widget"
                    },
                ),
            )
            setOnClickPendingIntent(R.id.widget_active_trip_root, openIntent)
            setOnClickPendingIntent(R.id.widget_active_trip_open, openIntent)
        }
    }

    fun dailyRouteViews(context: Context, appWidgetId: Int): RemoteViews {
        val prefs = NativeStateStore.preferences(context)
        val hasData = prefs.getBoolean(NativeStateStore.DAILY_ROUTE_HAS_DATA, false)
        val isDemo = prefs.getBoolean(NativeStateStore.DAILY_ROUTE_IS_DEMO, false)
        val label = prefs.getString(NativeStateStore.DAILY_ROUTE_LABEL, null).orEmpty()
        val lineStatus = prefs.getString(NativeStateStore.DAILY_ROUTE_LINE_STATUS, null).orEmpty()
        val updatedAt = prefs.getLong(NativeStateStore.DAILY_ROUTE_UPDATED_AT, 0L)
        val times = NativeStateStore.DAILY_ROUTE_DEPARTURE_TIME.map { prefs.getString(it, null).orEmpty() }
        val destinations = NativeStateStore.DAILY_ROUTE_DEPARTURE_DESTINATION.map {
            prefs.getString(it, null).orEmpty()
        }
        val timeViewIds = listOf(
            R.id.widget_daily_route_dep1_time,
            R.id.widget_daily_route_dep2_time,
            R.id.widget_daily_route_dep3_time,
        )
        val destinationViewIds = listOf(
            R.id.widget_daily_route_dep1_destination,
            R.id.widget_daily_route_dep2_destination,
            R.id.widget_daily_route_dep3_destination,
        )

        return RemoteViews(context.packageName, R.layout.widget_daily_route).apply {
            setTextViewText(
                R.id.widget_daily_route_badge,
                context.getString(if (hasData && isDemo) R.string.widget_data_demo else R.string.widget_no_data_badge),
            )
            setViewVisibility(
                R.id.widget_daily_route_badge,
                if (!hasData || isDemo) View.VISIBLE else View.GONE,
            )
            setTextViewText(
                R.id.widget_daily_route_label,
                label.ifBlank { context.getString(R.string.widget_daily_route_title) },
            )
            setTextViewText(
                R.id.widget_daily_route_status,
                lineStatus.ifBlank { context.getString(R.string.widget_daily_route_status_unavailable) },
            )
            timeViewIds.indices.forEach { index ->
                setTextViewText(timeViewIds[index], times[index].ifBlank { "—" })
                setTextViewText(
                    destinationViewIds[index],
                    destinations[index].ifBlank { context.getString(R.string.widget_daily_route_no_departure) },
                )
            }
            setTextViewText(
                R.id.widget_daily_route_updated,
                if (hasData && updatedAt > 0L) {
                    context.getString(R.string.widget_updated_at, formatTime(updatedAt))
                } else {
                    ""
                },
            )

            val openIntent = deepLinkPendingIntent(
                context,
                20_000 + appWidgetId,
                Uri.parse("temankereta://app/departures?source=widget_daily_route"),
            )
            setOnClickPendingIntent(R.id.widget_daily_route_root, openIntent)
        }
    }

    fun serviceStatusViews(context: Context, appWidgetId: Int): RemoteViews {
        val prefs = NativeStateStore.preferences(context)
        val hasData = prefs.getBoolean(NativeStateStore.SERVICE_STATUS_HAS_DATA, false)
        val isDemo = prefs.getBoolean(NativeStateStore.SERVICE_STATUS_IS_DEMO, false)
        val updatedAt = prefs.getLong(NativeStateStore.SERVICE_STATUS_UPDATED_AT, 0L)
        val names = NativeStateStore.SERVICE_STATUS_LINE_NAME.map { prefs.getString(it, null).orEmpty() }
        val statuses = NativeStateStore.SERVICE_STATUS_LINE_STATUS.map { prefs.getString(it, null).orEmpty() }
        val nameViewIds = listOf(
            R.id.widget_service_status_line1_name,
            R.id.widget_service_status_line2_name,
            R.id.widget_service_status_line3_name,
            R.id.widget_service_status_line4_name,
        )
        val statusViewIds = listOf(
            R.id.widget_service_status_line1_status,
            R.id.widget_service_status_line2_status,
            R.id.widget_service_status_line3_status,
            R.id.widget_service_status_line4_status,
        )

        return RemoteViews(context.packageName, R.layout.widget_service_status).apply {
            setTextViewText(
                R.id.widget_service_status_badge,
                context.getString(if (hasData && isDemo) R.string.widget_data_demo else R.string.widget_no_data_badge),
            )
            setViewVisibility(
                R.id.widget_service_status_badge,
                if (!hasData || isDemo) View.VISIBLE else View.GONE,
            )
            nameViewIds.indices.forEach { index ->
                val hasLine = names[index].isNotBlank()
                setTextViewText(
                    nameViewIds[index],
                    if (hasLine) names[index] else if (index == 0) context.getString(R.string.widget_service_status_no_data) else "",
                )
                setTextViewText(statusViewIds[index], if (hasLine) statuses[index] else "")
                setTextColor(statusViewIds[index], statusColor(context, statuses[index]))
            }
            setTextViewText(
                R.id.widget_service_status_updated,
                if (hasData && updatedAt > 0L) {
                    context.getString(R.string.widget_updated_at, formatTime(updatedAt))
                } else {
                    ""
                },
            )

            val openIntent = deepLinkPendingIntent(
                context,
                30_000 + appWidgetId,
                Uri.parse("temankereta://app/home?source=widget_service_status"),
            )
            setOnClickPendingIntent(R.id.widget_service_status_root, openIntent)
        }
    }

    private fun statusColor(context: Context, status: String): Int {
        val colorRes = when (status.lowercase()) {
            "normal" -> R.color.tk_widget_status_normal
            "delayed", "terlambat", "limited", "terbatas" -> R.color.tk_widget_status_delayed
            "disrupted", "gangguan" -> R.color.tk_widget_status_disrupted
            else -> R.color.tk_widget_status_unavailable
        }
        return context.getColor(colorRes)
    }

    private fun deepLinkPendingIntent(
        context: Context,
        requestCode: Int,
        uri: Uri,
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, uri, context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun formatTime(epochMs: Long): String =
        DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(epochMs))
}
