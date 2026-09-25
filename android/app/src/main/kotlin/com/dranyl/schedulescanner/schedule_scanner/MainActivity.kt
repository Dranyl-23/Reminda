package com.dranyl.schedulescanner.schedule_scanner

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.schedly.app/home_widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateHomeWidget") {
                    val title = call.argument<String>("title") ?: "No Upcoming Classes"
                    val subtitle = call.argument<String>("subtitle") ?: "All caught up!"
                    val status = call.argument<String>("status") ?: "FREE"
                    val isOngoing = call.argument<Boolean>("isOngoing") ?: false
                    val activeCount = call.argument<Int>("activeCount") ?: 0

                    val prefs = applicationContext.getSharedPreferences(
                        SchedlyWidgetProvider.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    prefs.edit()
                        .putString("title", title)
                        .putString("subtitle", subtitle)
                        .putString("status", status)
                        .putBoolean("isOngoing", isOngoing)
                        .putInt("activeCount", activeCount)
                        .apply()

                    SchedlyWidgetProvider.updateAllWidgets(applicationContext)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
