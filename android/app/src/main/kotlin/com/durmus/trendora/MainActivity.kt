package com.durmus.trendora

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.durmus.trendora/share"
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareText") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val text = call.argument<String>("text")?.trim().orEmpty()
            if (text.isEmpty()) {
                result.error(
                    "EMPTY_SHARE_TEXT",
                    "Paylaşılacak haber bilgisi bulunamadı.",
                    null
                )
                return@setMethodCallHandler
            }

            try {
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(shareIntent, "Haberi paylaş"))
                result.success(null)
            } catch (_: Exception) {
                result.error(
                    "SHARE_UNAVAILABLE",
                    "Paylaşım paneli açılamadı.",
                    null
                )
            }
        }
    }
}
