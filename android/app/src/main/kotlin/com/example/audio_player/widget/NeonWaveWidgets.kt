package com.example.audio_player.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import com.example.audio_player.R
import io.flutter.plugin.common.MethodChannel

/// Мост к Dart-движку: если приложение живо — действия уходят мгновенно,
/// иначе виджет открывает приложение.
object WidgetBridge {
    @Volatile var channel: MethodChannel? = null

    fun dispatch(context: Context, action: String) {
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("widgetAction", action, object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, message: String?, details: Any?) {
                    openApp(context)
                }
                override fun notImplemented() { openApp(context) }
            })
        } else {
            openApp(context)
        }
    }

    private fun openApp(context: Context) {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launch)
        }
    }
}

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetBridge.dispatch(context, intent.action ?: "")
    }
}

object WidgetState {
    @Volatile var title: String = "NeonWave"
    @Volatile var artist: String = "Откройте плеер"
    @Volatile var playing: Boolean = false
    @Volatile var favorite: Boolean = false
    @Volatile var shuffle: Boolean = false
    @Volatile var repeat: Int = 0 // 0 off, 1 all, 2 one
    @Volatile var artBytes: ByteArray? = null
    @Volatile private var roundedArt: Bitmap? = null

    fun update(
        title: String, artist: String, playing: Boolean,
        favorite: Boolean, shuffle: Boolean, repeat: Int,
        artBytes: ByteArray?,
    ) {
        this.title = title
        this.artist = artist
        this.playing = playing
        this.favorite = favorite
        this.shuffle = shuffle
        this.repeat = repeat
        if (artBytes != null && !artBytes.contentEquals(this.artBytes)) {
            this.artBytes = artBytes
            this.roundedArt = null
        }
    }

    private fun pi(context: Context, code: Int, setup: (Intent) -> Unit): PendingIntent {
        val intent = Intent()
        setup(intent)
        val flags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(context, code, intent, flags)
    }

    private fun mediaButton(context: Context, keyCode: Int): PendingIntent = pi(context, keyCode) {
        it.action = Intent.ACTION_MEDIA_BUTTON
        it.component = ComponentName(
            context.packageName,
            "com.ryanheise.audioservice.MediaButtonReceiver"
        )
        it.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
    }

    private fun action(context: Context, name: String): PendingIntent = pi(context, name.hashCode()) {
        it.action = name
        it.component = ComponentName(context.packageName, WidgetActionReceiver::class.java.name)
    }

    fun openApp(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        val flags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(context, 100, launch, flags)
    }

    private fun artBitmap(context: Context): Bitmap? {
        roundedArt?.let { return it }
        val bytes = artBytes ?: return null
        val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val size = minOf(src.width, src.height)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val radius = size * 0.18f
        val path = Path().apply {
            addRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), radius, radius, Path.Direction.CW)
        }
        canvas.clipPath(path)
        val scaled = if (src.width != size || src.height != size) {
            Bitmap.createScaledBitmap(src, size, size, true)
        } else src
        canvas.drawBitmap(scaled, 0f, 0f, null)
        roundedArt = bmp
        return bmp
    }

    private fun fill(context: Context, views: RemoteViews, fullControls: Boolean) {
        views.setTextViewText(R.id.w_title, title)
        views.setTextViewText(R.id.w_artist, artist)

        views.setOnClickPendingIntent(R.id.w_root, openApp(context))
        views.setOnClickPendingIntent(R.id.w_play,
            mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        views.setOnClickPendingIntent(R.id.w_next,
            mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT))
        views.setOnClickPendingIntent(R.id.w_fav, action(context, "neonwave.widget.FAVORITE"))
        if (fullControls) {
            views.setOnClickPendingIntent(R.id.w_prev,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
            views.setOnClickPendingIntent(R.id.w_shuffle, action(context, "neonwave.widget.SHUFFLE"))
            views.setOnClickPendingIntent(R.id.w_repeat, action(context, "neonwave.widget.REPEAT"))
        }

        val bmp = artBitmap(context)
        if (bmp != null) {
            views.setImageViewBitmap(R.id.w_art, bmp)
        } else {
            views.setImageViewResource(R.id.w_art, R.drawable.ic_action_favorite_off)
        }

        views.setImageViewResource(
            R.id.w_play,
            if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )
        views.setImageViewResource(
            R.id.w_fav,
            if (favorite) R.drawable.ic_action_favorite else R.drawable.ic_action_favorite_off
        )
        views.setImageViewResource(
            R.id.w_shuffle,
            if (shuffle) R.drawable.ic_action_shuffle else R.drawable.ic_action_shuffle_off
        )
        views.setImageViewResource(
            R.id.w_repeat,
            when (repeat) {
                1 -> R.drawable.ic_action_repeat
                2 -> R.drawable.ic_action_repeat_one
                else -> R.drawable.ic_action_repeat_off
            }
        )
    }

    fun pushAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val pkg = context.packageName

        val small = RemoteViews(pkg, R.layout.widget_small).also { fill(context, it, false) }
        val large = RemoteViews(pkg, R.layout.widget_large).also { fill(context, it, true) }

        for (id in mgr.getAppWidgetIds(ComponentName(context, SmallWidgetProvider::class.java))) {
            mgr.updateAppWidget(id, small)
        }
        for (id in mgr.getAppWidgetIds(ComponentName(context, LargeWidgetProvider::class.java))) {
            mgr.updateAppWidget(id, large)
        }
    }
}

class SmallWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        WidgetState.pushAll(context)
    }
}

class LargeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        WidgetState.pushAll(context)
    }
}
