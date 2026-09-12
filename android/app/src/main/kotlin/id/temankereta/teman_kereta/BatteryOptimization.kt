package id.temankereta.teman_kereta

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Standard Android battery-optimization exemption, plus a best-effort deep
 * link into the OEM-specific "autostart"/"protected apps" screen that
 * Xiaomi (MIUI), Oppo/Realme (ColorOS) and Vivo/iQOO (FuntouchOS) ship in
 * addition to stock Android's own Doze allowlist — [ActiveTripLocationService]
 * has `stopWithTask=false` and its own stalled-fix watchdog, but neither
 * survives an OEM battery manager killing the process outright, which the
 * standard exemption alone does not always prevent on these ROMs.
 *
 * The OEM component names below are undocumented and can change between ROM
 * versions, so every attempt is wrapped so a missing/renamed activity just
 * means "no shortcut available" rather than a crash.
 */
internal object BatteryOptimization {
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return true
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    /** Shows the system's own "Allow app to ignore battery optimizations?" dialog. */
    fun requestIgnoreIntent(context: Context): Intent =
        Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
        }

    /** Manufacturer name, for showing OEM-specific instructions in the UI. */
    fun manufacturer(): String = Build.MANUFACTURER.orEmpty()

    /**
     * The OEM's own background-app allowlist screen, if this device's ROM
     * exposes one of the known ones and it actually resolves. Null means
     * "nothing OEM-specific to offer" — callers fall back to the app's own
     * details screen instead.
     */
    fun manufacturerSettingsIntent(context: Context): Intent? {
        val candidates = when (manufacturer().lowercase()) {
            "xiaomi" -> listOf(
                "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            )
            "oppo", "realme" -> listOf(
                "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            )
            "vivo" -> listOf(
                "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            )
            else -> emptyList()
        }
        val packageManager = context.packageManager
        for ((pkg, cls) in candidates) {
            val intent = Intent().apply {
                component = android.content.ComponentName(pkg, cls)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                return intent
            }
        }
        return null
    }

    /** Always resolves: the app's own "App info" screen as a universal fallback. */
    fun appDetailsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
}
