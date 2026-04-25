package com.urbanfootball.app

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity: FlutterActivity() {

    private val GALLERY_CHANNEL = "urbanfootball/gallery"
    private val DEEP_LINK_CHANNEL = "deeplink_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 🔥 기존 갤러리 코드 유지
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GALLERY_CHANNEL)
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
                        result.success(if (saved) "ok" else "fail")
                    } catch (e: Exception) {
                        result.success("error: ${e.message}")
                    }
                } else {
                    result.notImplemented()
                }
            }

        // 🔥 앱 실행 시 딥링크 처리
        handleDeepLink(intent, flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.let {
            handleDeepLink(intent, it)
        }
    }

    private fun handleDeepLink(intent: Intent?, engine: FlutterEngine) {
        val data: Uri? = intent?.data

        if (data != null) {
            val link = data.toString()

            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                DEEP_LINK_CHANNEL
            ).invokeMethod("onDeepLink", link)
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