package com.example.audio_player

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/// Мост к android.media.audiofx.Visualizer: транслирует РЕАЛЬНУЮ форму волны
/// аудио-микса в Dart, чтобы эквалайзер в плеере был живым, а не «гифкой».
///
/// Требует разрешение RECORD_AUDIO. Если устройство/ром не даёт доступ,
/// поток отдаёт ошибку — Dart переключается на синтетическую анимацию.
class AudioVisualizerBridge : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var visualizer: Visualizer? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        start()
    }

    override fun onCancel(arguments: Any?) {
        stop()
        sink = null
    }

    private fun start() {
        stop()
        try {
            val viz = Visualizer(0)
            val range = Visualizer.getCaptureSizeRange()
            val size = if (range.isNotEmpty()) range[0] else 128
            viz.captureSize = size
            viz.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        v: Visualizer?,
                        waveform: ByteArray?,
                        samplingRate: Int,
                    ) {
                        val w = waveform ?: return
                        main.post { sink?.success(w) }
                    }

                    override fun onFftDataCapture(
                        v: Visualizer?,
                        fft: ByteArray?,
                        samplingRate: Int,
                    ) = Unit
                },
                Visualizer.getMaxCaptureRate(),
                true,
                false,
            )
            viz.enabled = true
            visualizer = viz
        } catch (t: Throwable) {
            main.post { sink?.error("viz_unavailable", t.message, null) }
        }
    }

    private fun stop() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: Throwable) {
        }
        visualizer = null
    }
}
