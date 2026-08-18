package com.app.callerai

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView

class OverlayService : Service() {
    private var overlayView: View? = null
    private lateinit var windowManager: WindowManager

    inner class LocalBinder : Binder() {
        fun getService(): OverlayService = this@OverlayService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    fun showOverlay(callerNumber: String, callerName: String, spamScore: Int) {
        if (overlayView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 100

        // In production: inflate a custom XML layout with caller ID details
        val view = TextView(applicationContext).apply {
            text = if (spamScore > 70) "⚠️ SPAM: $callerNumber" else "📞 $callerName\n$callerNumber"
            setBackgroundColor(if (spamScore > 70) 0xFFEF4444.toInt() else 0xFF1F6C92.toInt())
            setTextColor(0xFFFFFFFF.toInt())
            setPadding(24, 12, 24, 12)
            textSize = 14f
        }

        overlayView = view
        windowManager.addView(view, params)
    }

    fun hideOverlay() {
        overlayView?.let {
            windowManager.removeView(it)
            overlayView = null
        }
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }
}
