package com.moneyflow.mobile

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

private const val CHANNEL = "com.moneyflow.mobile/downloads"

/// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
/// biometric prompt (Mục 14 — PIN/Vân tay app lock).
///
/// Also hosts a small MethodChannel used only by
/// `core/export/excel_export_service.dart` to save exported files into the
/// public "Tải xuống" (Downloads) folder via MediaStore — the app's own
/// `Android/data/<package>/files/` directory (path_provider's
/// `getExternalStorageDirectory()`) works but isn't reasonably findable by
/// a normal user in a file manager, which was the original complaint this
/// exists to fix.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                try {
                    val fileName = call.argument<String>("fileName")!!
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes")!!
                    result.success(saveToDownloads(fileName, mimeType, bytes))
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Scoped storage (Android 10+): insert into the MediaStore
            // Downloads collection instead of touching a raw file path — the
            // only API-correct way to land a file in the public Downloads
            // folder without the (Play-Store-gated) MANAGE_EXTERNAL_STORAGE
            // permission.
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Không thể tạo file trong Tải xuống")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Không thể ghi dữ liệu vào file")
            return "Tải xuống/$fileName"
        } else {
            // Pre-scoped-storage devices (Android 9 and below, minSdk 23):
            // a direct file path write works without MediaStore, but does
            // need the legacy WRITE_EXTERNAL_STORAGE permission granted —
            // see the matching <uses-permission maxSdkVersion="28"> in
            // AndroidManifest.xml. If it's not granted, this throws and the
            // Dart side falls back to the app-private directory instead of
            // crashing the export.
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            val file = File(downloadsDir, fileName)
            FileOutputStream(file).use { it.write(bytes) }
            return file.absolutePath
        }
    }
}
