package com.example.habit_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.widget.RemoteViews

class HabitWidget2x2Provider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateWidget(context, manager, it, wide = false) }
    }
}

class HabitWidget4x2Provider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateWidget(context, manager, it, wide = true) }
    }
}

private fun updateWidget(context: Context, manager: AppWidgetManager, id: Int, wide: Boolean) {
    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val completed = prefs.getInt("completed", 0)
    val total = prefs.getInt("total", 1)
    val habit1 = prefs.getString("habit1_name", "") ?: ""
    val habit2 = prefs.getString("habit2_name", "") ?: ""
    val habit3 = prefs.getString("habit3_name", "") ?: ""

    val pct = if (total > 0) completed.toFloat() / total.toFloat() else 0f
    val layoutId = if (wide) R.layout.habit_widget_4x2 else R.layout.habit_widget_2x2
    val views = RemoteViews(context.packageName, layoutId)

    val bitmap = if (wide) createWideBitmap(pct, habit1, habit2, habit3) else createCircleBitmap(pct)
    views.setImageViewBitmap(R.id.widget_image, bitmap)

    val intent = Intent(context, MainActivity::class.java)
    val pi = PendingIntent.getActivity(
        context, 0, intent,
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )
    views.setOnClickPendingIntent(R.id.widget_root, pi)
    manager.updateAppWidget(id, views)
}

private fun progressColor(pct: Float): Int = when {
    pct >= 0.70f -> Color.parseColor("#4CAF50")
    pct >= 0.40f -> Color.parseColor("#FFC107")
    else -> Color.parseColor("#F44336")
}

private fun createCircleBitmap(pct: Float): Bitmap {
    val size = 300
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)

    val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1E1E2E")
        style = Paint.Style.FILL
    }
    canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), 32f, 32f, bgPaint)

    val cx = size / 2f
    val cy = size / 2f
    val radius = size * 0.36f
    val strokeW = size * 0.09f

    val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#2A2A3E")
        style = Paint.Style.STROKE
        strokeWidth = strokeW
    }
    canvas.drawCircle(cx, cy, radius, trackPaint)

    val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = progressColor(pct)
        style = Paint.Style.STROKE
        strokeWidth = strokeW
        strokeCap = Paint.Cap.ROUND
    }
    val oval = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
    canvas.drawArc(oval, -90f, pct * 360f, false, arcPaint)

    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = size * 0.20f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    val pctText = "${(pct * 100).toInt()}%"
    val textY = cy - (textPaint.descent() + textPaint.ascent()) / 2
    canvas.drawText(pctText, cx, textY, textPaint)

    return bmp
}

private fun createWideBitmap(pct: Float, habit1: String, habit2: String, habit3: String): Bitmap {
    val w = 600
    val h = 300
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bmp)

    val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1E1E2E")
        style = Paint.Style.FILL
    }
    canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), 32f, 32f, bgPaint)

    // Left: circle progress
    val cx = h / 2f
    val cy = h / 2f
    val radius = h * 0.36f
    val strokeW = h * 0.09f

    val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#2A2A3E")
        style = Paint.Style.STROKE
        strokeWidth = strokeW
    }
    canvas.drawCircle(cx, cy, radius, trackPaint)

    val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = progressColor(pct)
        style = Paint.Style.STROKE
        strokeWidth = strokeW
        strokeCap = Paint.Cap.ROUND
    }
    val oval = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
    canvas.drawArc(oval, -90f, pct * 360f, false, arcPaint)

    val pctTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = h * 0.20f
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    val pctText = "${(pct * 100).toInt()}%"
    val pctTextY = cy - (pctTextPaint.descent() + pctTextPaint.ascent()) / 2
    canvas.drawText(pctText, cx, pctTextY, pctTextPaint)

    // Divider
    val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#2A2A3E")
        strokeWidth = 2f
        style = Paint.Style.STROKE
    }
    val divX = h.toFloat() + 20f
    canvas.drawLine(divX, 32f, divX, h - 32f, dividerPaint)

    // Right: pending habits
    val listX = divX + 32f
    val habits = listOf(habit1, habit2, habit3).filter { it.isNotEmpty() }

    val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#888888")
        textSize = 28f
        textAlign = Paint.Align.LEFT
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
    }
    val habitPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 34f
        textAlign = Paint.Align.LEFT
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    if (habits.isEmpty()) {
        val donePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#4CAF50")
            textSize = 36f
            textAlign = Paint.Align.LEFT
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        canvas.drawText("¡Todo completado!", listX, cy - 18f, donePaint)
        val subPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#888888")
            textSize = 26f
            textAlign = Paint.Align.LEFT
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        }
        canvas.drawText("Gran trabajo hoy 🎉", listX, cy + 26f, subPaint)
    } else {
        canvas.drawText("Pendientes hoy:", listX, 56f, labelPaint)
        val spacing = (h - 80f) / (habits.size + 1)
        habits.forEachIndexed { i, name ->
            val y = 80f + spacing * (i + 1)
            val maxChars = 16
            val displayName = if (name.length > maxChars) name.substring(0, maxChars) + "…" else name
            canvas.drawText("• $displayName", listX, y, habitPaint)
        }
    }

    return bmp
}
