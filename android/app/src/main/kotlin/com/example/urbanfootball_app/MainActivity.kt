package com.urbanfootball.app

import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import android.util.Base64

class MainActivity: FlutterActivity() {
    private val CHANNEL = "urbanfootball/gallery"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveImageToGallery") {
                    val base64 = call.argument<String>("base64")
                    val fileName = call.argument<String>("fileName") ?: "card.jpg"

                    if (base64.isNullOrEmpty()) {
                        result.error("INVALID_DATA", "base64 is empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val bytes = Base64.decode(base64, Base64.DEFAULT)
                        val saved = saveImage(bytes, fileName)
                        if (saved) {
                            result.success("ok")
                        } else {
                            result.success("fail")
                        }
                    } catch (e: Exception) {
                        result.success("error: ${e.message}")
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveImage(bytes: ByteArray, fileName: String): Boolean {
        val resolver = applicationContext.contentResolver

        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/UrbanFootball")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: return false

        var outputStream: OutputStream? = null

        return try {
            outputStream = resolver.openOutputStream(uri)
            outputStream?.write(bytes)
            outputStream?.flush()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }
            true
        } catch (e: Exception) {
            false
        } finally {
            outputStream?.close()
        }
    }
}