package com.example.audio_player.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import com.example.audio_player.R

object WidgetState {
    @Volatile var title: String = "NeonWave"
    @Volatile var artist: String = "Откройте плеер"
    @Volatile var playing: Boolean = false
    @Volatile var artBytes: ByteArray? = null

    fun mediaButton(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
        intent.component = ComponentName(
            context.packageName,
            "com.ryanheise.audioservice.MediaButtonReceiver"
        )
        intent.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        val flags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(context, keyCode, intent, flags)
    }

    fun openApp(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        val flags = if (Build.VERSION.SDK_INT >= 23)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(context, 100, launch, flags)
    }

    private fun fill(context: Context, views: RemoteViews, withPrev: Boolean) {
        views.setTextViewText(R.id.w_title, title)
        views.setTextViewText(R.id.w_artist, artist)

        views.setOnClickPendingIntent(R.id.w_root, openApp(context))
        views.setOnClickPendingIntent(R.id.w_play,
            mediaButton(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        views.setOnClickPendingIntent(R.id.w_next,
            mediaButton(context, KeyEvent.KEYCODE_MEDIA_NEXT))

        val bytes = artBytes
        if (bytes != null) {
            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            views.setImageViewBitmap(R.id.w_art, bmp)
        } else {
            views.setImageViewResource(R.id.w_art, R.drawable.ic_action_favorite_off)
        }
        views.setImageViewResource(
            R.id.w_play,
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        )
    }

    fun pushAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val pkg = context.packageName

        val small = RemoteViews(pkg, R.layout.widget_small).also { fill(context, it, false) }
        val large = RemoteViews(pkg, R.layout.widget_large).also {
            fill(context, it, true)
            it.setOnClickPendingIntent(R.id.w_prev,
                mediaButton(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        }

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
