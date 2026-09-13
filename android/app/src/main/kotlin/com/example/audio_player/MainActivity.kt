package com.example.audio_player

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentUris
import android.content.Intent
import android.content.IntentSender
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import com.example.audio_player.widget.WidgetState
import com.example.audio_player.widget.WidgetBridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    /** Ожидающий ответ Dart-вызова deleteTrack (ждём подтверждения в диалоге). */
    private var pendingDeleteResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DELETE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteTrack" -> {
                        val path = call.argument<String>("path")
                        val id = (call.argument<Number>("id") ?: -1).toLong()
                        if (path == null && id <= 0) {
                            result.success(false)
                        } else if (Build.VERSION.SDK_INT >= 30) {
                            // ФИКС (High): раньше result.success(true) отправлялся
                            // СРАЗУ после запуска системного диалога, поэтому Dart
                            // убирал трек из библиотеки/очереди даже при «Отмена».
                            // Теперь ответ уходит только из onActivityResult.
                            onDeleteRequested(id, path, result)
                        } else {
                            result.success(deleteImmediately(id, path))
                        }
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
                        positionMs = (call.argument<Number>("positionMs") ?: 0).toInt(),
                        durationMs = (call.argument<Number>("durationMs") ?: 0).toInt(),
                        artBytes = call.argument<ByteArray>("artBytes"),
                    )
                    WidgetState.pushAll(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WAVE_CHANNEL)
            .setStreamHandler(AudioVisualizerBridge())
    }

    /** Android 11+ (API 30+): системный диалог; ответ придёт в onActivityResult. */
    private fun onDeleteRequested(id: Long, path: String?, result: MethodChannel.Result) {
        val uri = getMediaUri(id, path)
        if (uri == null) {
            result.success(false)
            return
        }
        if (pendingDeleteResult != null) {
            // Уже открыт один диалог — второй запрос не поддерживаем.
            result.success(false)
            return
        }
        try {
            pendingDeleteResult = result
            val pendingIntent = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
            startIntentSenderForResult(
                pendingIntent.intentSender,
                DELETE_REQUEST_CODE,
                null,
                0,
                0,
                0,
            )
        } catch (e: Exception) {
            pendingDeleteResult = null
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DELETE_REQUEST_CODE) {
            val pending = pendingDeleteResult
            pendingDeleteResult = null
            pending?.success(resultCode == android.app.Activity.RESULT_OK)
        }
    }

    /** Android 10 и ниже: удаляем сразу, диалога нет. */
    private fun deleteImmediately(id: Long, path: String?): Boolean {
        return try {
            val uri = getMediaUri(id, path)
            uri != null && contentResolver.delete(uri, null, null) > 0
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Uri записи в MediaStore. Сначала по `_ID`: `id` трека от on_audio_query —
     * это и есть MediaStore `_ID`, самый надёжный способ. Путь (колонка DATA)
     * используется только как фолбэк: она deprecated, и на части устройств
     * Android 11+ запись по DATA не находится.
     */
    private fun getMediaUri(id: Long, path: String?): android.net.Uri? {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val selection: String
        val args: Array<String>
        if (id > 0) {
            selection = "${MediaStore.MediaColumns._ID}=?"
            args = arrayOf(id.toString())
        } else if (!path.isNullOrEmpty()) {
            selection = "${MediaStore.MediaColumns.DATA}=?"
            args = arrayOf(path)
        } else {
            return null
        }
        return try {
            contentResolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns._ID),
                selection,
                args,
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
        private const val WAVE_CHANNEL = "neonwave/wave"
        private const val DELETE_REQUEST_CODE = 4831
    }
}
