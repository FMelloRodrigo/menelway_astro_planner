package com.astrotargets.app.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.astrotargets.app/storage"
    private val REQUEST_PICK_IMAGE = 1001
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDir" -> result.success(applicationContext.filesDir.absolutePath)
                "getCacheDir" -> result.success(applicationContext.cacheDir.absolutePath)
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                "pickImage" -> {
                    if (pendingPickerResult != null) {
                        try {
                            pendingPickerResult?.success(null)
                        } catch (_: Exception) {}
                    }
                    pendingPickerResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(intent, REQUEST_PICK_IMAGE)
                    } catch (e: Exception) {
                        pendingPickerResult = null
                        result.error("LAUNCH_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_IMAGE) {
            val result = pendingPickerResult
            pendingPickerResult = null
            if (result == null) return

            if (resultCode != Activity.RESULT_OK || data == null || data.data == null) {
                result.success(null)
                return
            }

            val uri: Uri = data.data!!
            try {
                val inputStream = contentResolver.openInputStream(uri)
                if (inputStream == null) {
                    result.success(null)
                    return
                }

                val panoramasDir = File(applicationContext.filesDir, "panoramas")
                if (!panoramasDir.exists()) {
                    panoramasDir.mkdirs()
                }

                val fileName = getFileName(uri) ?: "panorama_${System.currentTimeMillis()}.jpg"
                val safeFileName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                val destFile = File(panoramasDir, "img_${System.currentTimeMillis()}_$safeFileName")

                inputStream.use { input ->
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                }

                result.success(destFile.absolutePath)
            } catch (e: Exception) {
                result.error("PICK_IMAGE_ERROR", e.localizedMessage, null)
            }
        }
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        if (uri.scheme == "content") {
            try {
                val cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index != -1) {
                            name = it.getString(index)
                        }
                    }
                }
            } catch (_: Exception) {}
        }
        if (name == null) {
            name = uri.path?.let { File(it).name }
        }
        return name
    }
}
