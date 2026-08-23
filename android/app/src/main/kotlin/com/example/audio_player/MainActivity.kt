package com.example.audio_player

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentUris
import android.content.IntentSender
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import com.example.audio_player.widget.WidgetState
import com.example.audio_player.widget.WidgetBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DELETE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteTrack" -> {
                        val path = call.argument<String>("path")
                        result.success(path != null && requestDelete(path))
                    }
                    else -> result.notImplemented()
                }
            }
        val widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        WidgetBridge.channel = widgetChannel
        widgetChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    WidgetState.update(
                        title = call.argument<String>("title") ?: "NeonWave",
                        artist = call.argument<String>("artist") ?: "",
                        playing = call.argument<Boolean>("playing") ?: false,
                        favorite = call.argument<Boolean>("favorite") ?: false,
                        shuffle = call.argument<Boolean>("shuffle") ?: false,
                        repeat = (call.argument<Number>("repeat") ?: 0).toInt(),
                        artBytes = call.argument<ByteArray>("artBytes"),
                    )
                    WidgetState.pushAll(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestDelete(path: String): Boolean {
        return try {
            val uri = getMediaUriForPath(path)
            if (uri == null) {
                false
            } else if (Build.VERSION.SDK_INT >= 30) {
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    DELETE_REQUEST_CODE,
                    null,
                    0,
                    0,
                    0,
                )
                true
            } else {
                contentResolver.delete(uri, null, null) > 0
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getMediaUriForPath(path: String): android.net.Uri? {
        return try {
            val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            contentResolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DATA}=?",
                arrayOf(path),
                null,
            )?.use { c ->
                if (c.moveToFirst()) {
                    ContentUris.withAppendedId(collection, c.getLong(0))
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val DELETE_CHANNEL = "neonwave/deletion"
        private const val WIDGET_CHANNEL = "neonwave/widgets"
        private const val DELETE_REQUEST_CODE = 4831
    }
}
