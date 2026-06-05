package com.example.notizblock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import android.net.Uri
import org.json.JSONObject
import java.io.File

class NoteWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (appWidgetId in appWidgetIds) {
            editor.remove("note_id_$appWidgetId")
        }
        editor.apply()
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val noteId = prefs.getString("note_id_$appWidgetId", null)

            val views = RemoteViews(context.packageName, R.layout.note_widget)

            if (noteId != null) {
                val note = loadNote(context, noteId)
                if (note != null) {
                    val title = note.optString("title", "")
                    val content = note.optString("content", "")

                    views.setTextViewText(R.id.widget_title,
                        if (title.isNotEmpty()) title else context.getString(R.string.empty_note))
                    views.setTextViewText(R.id.widget_content, content)
                    views.setTextViewText(R.id.widget_time,
                        formatTime(note.optString("modifiedAt", "")))

                    // Notizfarbe auf den Hintergrund übernehmen
                    val bgColor = parseColor(note.optString("color", "#FFFDE7"))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        // Tintet das abgerundete Hintergrund-Drawable -> Ecken bleiben
                        views.setColorStateList(
                            R.id.widget_container,
                            "setBackgroundTintList",
                            ColorStateList.valueOf(bgColor)
                        )
                    } else {
                        views.setInt(R.id.widget_container, "setBackgroundColor", bgColor)
                    }

                    // Textfarbe nach Helligkeit wählen (dunkler Text auf hellem
                    // Grund). Auf hellem Grund kräftiges Schwarz wie im Hauptmenü
                    // (black87), nicht blasses Grau.
                    val luminance = 0.299 * Color.red(bgColor) +
                        0.587 * Color.green(bgColor) +
                        0.114 * Color.blue(bgColor)
                    val dark = luminance < 140
                    views.setTextColor(R.id.widget_title,
                        if (dark) Color.WHITE else Color.parseColor("#DD000000"))
                    views.setTextColor(R.id.widget_content,
                        if (dark) Color.parseColor("#E6FFFFFF") else Color.parseColor("#DD000000"))
                    // Zeit etwas dezenter (black54 / white70), aber an die Helligkeit
                    // angepasst – sonst auf dunklen Farben unsichtbar.
                    views.setTextColor(R.id.widget_time,
                        if (dark) Color.parseColor("#B3FFFFFF") else Color.parseColor("#8A000000"))
                    // Haus-Symbol (ImageView) per Color-Filter an die Helligkeit
                    // anpassen (setColorFilter ist @RemotableViewMethod).
                    views.setInt(R.id.widget_menu, "setColorFilter",
                        if (dark) Color.parseColor("#CCFFFFFF") else Color.parseColor("#99000000"))
                }
            }

            // Deep Link Intent - öffnet direkt die Notiz zum Bearbeiten
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("notizblock://edit_note?id=$noteId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Menü-Button: öffnet die App frisch in der Hauptansicht (Notizliste).
            val menuIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val menuPendingIntent = PendingIntent.getActivity(
                context, appWidgetId + 1000000, menuIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_menu, menuPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // ISO-Zeitstempel ("2026-05-31T14:23:45.123") -> "31.05. 14:23"
        // Bewusst per Substring, um java.time/Desugaring zu vermeiden.
        private fun formatTime(iso: String): String {
            return try {
                if (iso.length < 16) return ""
                val day = iso.substring(8, 10)
                val month = iso.substring(5, 7)
                val time = iso.substring(11, 16)
                "$day.$month. $time"
            } catch (e: Exception) {
                ""
            }
        }

        private fun parseColor(hex: String): Int {
            return try {
                Color.parseColor(hex)
            } catch (e: Exception) {
                Color.parseColor("#FFFDE7")
            }
        }

        private fun loadNote(context: Context, noteId: String): JSONObject? {
            return try {
                val notesFile = File(context.filesDir.parentFile, "app_flutter/notes.json")
                if (notesFile.exists()) {
                    val json = notesFile.readText()
                    val notes = org.json.JSONArray(json)
                    for (i in 0 until notes.length()) {
                        val note = notes.getJSONObject(i)
                        if (note.getString("id") == noteId) {
                            return note
                        }
                    }
                }
                null
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }

        fun loadAllNotes(context: Context): List<JSONObject> {
            return try {
                val notesFile = File(context.filesDir.parentFile, "app_flutter/notes.json")
                if (notesFile.exists()) {
                    val json = notesFile.readText()
                    val notes = org.json.JSONArray(json)
                    (0 until notes.length()).map { notes.getJSONObject(it) }
                } else {
                    emptyList()
                }
            } catch (e: Exception) {
                e.printStackTrace()
                emptyList()
            }
        }
    }
}