package com.astrotargets.app.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.astrotargets.app/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDir" -> result.success(applicationContext.filesDir.absolutePath)
                "getCacheDir" -> result.success(applicationContext.cacheDir.absolutePath)
                else -> result.notImplemented()
            }
        }
    }
}
