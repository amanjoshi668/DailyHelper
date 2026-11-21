package com.dailyhelper.daily_helper_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.dailyhelper.app/native"
        private const val REQ_POST_NOTIF = 4101
        private const val REQ_CREATE_DOC = 4102
    }

    private var pendingNotifResult: MethodChannel.Result? = null
    private var pendingReminderArgs: Map<String, Any?>? = null
    private var pendingExportContent: String? = null
    private var pendingExportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ReminderScheduler.ensureChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "configureReminders" -> handleConfigureReminders(call, result)
                    "saveExportDocument" -> handleSaveExportDocument(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleConfigureReminders(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        val amHour = call.argument<Int>("amHour") ?: 8
        val amMinute = call.argument<Int>("amMinute") ?: 30
        val pmHour = call.argument<Int>("pmHour") ?: 17
        val pmMinute = call.argument<Int>("pmMinute") ?: 30

        if (enabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

            if (!granted) {
                pendingNotifResult = result
                pendingReminderArgs = mapOf(
                    "enabled" to enabled,
                    "amHour" to amHour,
                    "amMinute" to amMinute,
                    "pmHour" to pmHour,
                    "pmMinute" to pmMinute
                )
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_POST_NOTIF
                )
                return
            }
        }

        ReminderScheduler.saveAndApply(this, enabled, amHour, amMinute, pmHour, pmMinute)
        result.success(enabled)
    }

    private fun handleSaveExportDocument(call: MethodCall, result: MethodChannel.Result) {
        val filename = call.argument<String>("filename") ?: "daily_helper_khata.csv"
        val mimeType = call.argument<String>("mimeType") ?: "text/csv"
        val content = call.argument<String>("content") ?: ""

        try {
            pendingExportContent = content
            pendingExportResult = result
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, filename)
            }
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQ_CREATE_DOC)
        } catch (_: Exception) {
            try {
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, filename)
                    putExtra(Intent.EXTRA_TEXT, content)
                }
                startActivity(Intent.createChooser(shareIntent, "Export Khata"))
                pendingExportContent = null
                pendingExportResult = null
                result.success(true)
            } catch (e: Exception) {
                pendingExportContent = null
                pendingExportResult = null
                result.error("EXPORT_FAILED", e.message, null)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_POST_NOTIF) {
            val res = pendingNotifResult
            val args = pendingReminderArgs
            pendingNotifResult = null
            pendingReminderArgs = null

            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted && args != null) {
                ReminderScheduler.saveAndApply(
                    this,
                    true,
                    (args["amHour"] as? Int) ?: 8,
                    (args["amMinute"] as? Int) ?: 30,
                    (args["pmHour"] as? Int) ?: 17,
                    (args["pmMinute"] as? Int) ?: 30
                )
                res?.success(true)
            } else {
                ReminderScheduler.saveAndApply(this, false, 8, 30, 17, 30)
                res?.success(false)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_CREATE_DOC) {
            val res = pendingExportResult
            val content = pendingExportContent ?: ""
            pendingExportResult = null
            pendingExportContent = null

            val uri = data?.data
            if (resultCode == Activity.RESULT_OK && uri != null) {
                try {
                    contentResolver.openOutputStream(uri)?.use { out ->
                        out.write(content.toByteArray(Charsets.UTF_8))
                    }
                    res?.success(true)
                } catch (e: Exception) {
                    res?.error("WRITE_FAILED", e.message, null)
                }
            } else {
                res?.success(false)
            }
        }
    }
}
