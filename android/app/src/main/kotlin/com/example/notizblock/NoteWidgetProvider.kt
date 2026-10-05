package com.example.notizblock

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.text.Spannable
import android.text.SpannableString
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.io.File

class NoteWidgetProvider : AppWidgetProvider() {

    // Eigene Aktionen des Widgets (explizite Intents, daher ohne Intent-Filter).
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            // Tipp auf die Zeit: Ladekreis SOFORT zeigen, dann erst den
            // Dart-Abgleich anstoßen. Der Hintergrund-Isolate braucht ein, zwei
            // Sekunden zum Hochfahren – ohne den sofortigen Kreis sah man in der
            // Zeit nichts und tippte womöglich mehrmals.
            ACTION_SYNC_NOW -> {
                HomeWidgetPlugin.getData(context).edit()
                    .putString(SYNC_SINCE_KEY, System.currentTimeMillis().toString())
                    .commit()
                updateAll(context)
                try {
                    HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("notizblock://sync_now")
                    ).send()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            // Sicherung: Kreis nach SYNC_MAX_MS ausblenden, falls das Ende des
            // Abgleichs nie gemeldet wurde (z.B. Prozess beendet).
            ACTION_SYNC_TIMEOUT -> updateAll(context)
            else -> super.onReceive(context, intent)
        }
    }

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
        private const val ACTION_SYNC_NOW = "at.aw.notizblock.widget.SYNC_NOW"
        private const val ACTION_SYNC_TIMEOUT = "at.aw.notizblock.widget.SYNC_TIMEOUT"

        // Beginn des per Tipp gestarteten Abgleichs (Millisekunden als Text,
        // "" = keiner) in den home_widget-Einstellungen. Gesetzt NUR hier beim
        // Tipp, beendet vom Dart-Callback (WidgetService.setSyncRunning(false)).
        // Bewusst NICHT bei automatischen Abgleichen (1.31.11 tat das: der
        // Kreis erschien dann alle paar Minuten). Text statt Zahl, weil
        // home_widget kleine Dart-ints als Int, große als Long ablegt.
        private const val SYNC_SINCE_KEY = "widget_sync_since"

        // Länger läuft kein normaler Abgleich; danach gilt der Kreis als hängen
        // geblieben (wie beim Kalender-Widget).
        private const val SYNC_MAX_MS = 90_000L

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, NoteWidgetProvider::class.java)
            )
            for (id in ids) updateAppWidget(context, manager, id)
        }

        // Restlaufzeit des Ladekreises in ms, 0 = kein Abgleich (mehr).
        private fun syncRemainingMs(context: Context): Long {
            val since = HomeWidgetPlugin.getData(context)
                .getString(SYNC_SINCE_KEY, "")?.toLongOrNull() ?: return 0
            val elapsed = System.currentTimeMillis() - since
            return if (elapsed in 0 until SYNC_MAX_MS) SYNC_MAX_MS - elapsed else 0
        }

        private fun scheduleSyncTimeout(context: Context, remainingMs: Long) {
            val intent = Intent(context, NoteWidgetProvider::class.java)
                .setAction(ACTION_SYNC_TIMEOUT)
            val pending = PendingIntent.getBroadcast(
                context, 2000001, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Ungenauer Wecker reicht (braucht keine Berechtigung); ersetzt
            // dank gleichem PendingIntent einen schon gestellten.
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + remainingMs + 500,
                pending
            )
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val noteId = prefs.getString("note_id_$appWidgetId", null)

            val views = RemoteViews(context.packageName, R.layout.note_widget)
            // Dunkle Notizfarbe? Bestimmt auch die Farbe des Ladekreises.
            var dark = false

            if (noteId != null) {
                val note = loadNote(context, noteId)
                if (note != null) {
                    val title = note.optString("title", "")
                    val content = note.optString("content", "")

                    views.setTextViewText(R.id.widget_title,
                        if (title.isNotEmpty()) title else context.getString(R.string.empty_note))
                    views.setTextViewText(R.id.widget_content, content)
                    // Zeit/Datum durchstreichen, wenn nicht bei Drive angemeldet
                    // (Login-Status aus drive_state.json) – macht den abgemeldeten
                    // Zustand sichtbar, da der Sync-Klick sonst kein Feedback gibt.
                    val timeStr = formatTime(note.optString("modifiedAt", ""))
                    if (isDriveSignedIn(context)) {
                        views.setTextViewText(R.id.widget_time, timeStr)
                    } else {
                        val struck = SpannableString(timeStr)
                        struck.setSpan(
                            StrikethroughSpan(), 0, timeStr.length,
                            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                        views.setTextViewText(R.id.widget_time, struck)
                    }

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
                    dark = luminance < 140
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
                    // Aktualisieren-Pfeil dezent wie die Zeit.
                    views.setInt(R.id.widget_refresh, "setColorFilter",
                        if (dark) Color.parseColor("#B3FFFFFF") else Color.parseColor("#8A000000"))
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

            // Zeit-Anzeige = "Jetzt synchronisieren"-Button. Geht zuerst an diesen
            // Provider (ACTION_SYNC_NOW: Ladekreis an), der dann über home_widget
            // den Hintergrund-Callback (Dart: widgetBackgroundCallback) auslöst,
            // der ohne App-Öffnen von Drive synct. Receiver/Service sind im
            // AndroidManifest registriert; der Callback-Handle wird beim App-Start
            // via WidgetService.initialize() persistiert.
            val syncIntent = Intent(context, NoteWidgetProvider::class.java)
                .setAction(ACTION_SYNC_NOW)
            val syncPendingIntent = PendingIntent.getBroadcast(
                context, 2000000, syncIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_sync_area, syncPendingIntent)

            // Ladekreis statt Pfeil, solange ein per Tipp gestarteter Abgleich
            // läuft (wie bei Wetter AW). Immer beides setzen: der Launcher
            // spielt Änderungen auf die alte Ansicht.
            val remaining = syncRemainingMs(context)
            val running = remaining > 0
            views.setViewVisibility(R.id.widget_refresh,
                if (running) View.INVISIBLE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_sync_progress_dark,
                if (running && !dark) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_sync_progress_light,
                if (running && dark) View.VISIBLE else View.GONE)
            if (running) scheduleSyncTimeout(context, remaining)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // ISO-Zeitstempel ("2026-05-31T14:23:45.123") -> heute "14:23", sonst
        // "31.05." (wie die Notizliste der App: heute Uhrzeit, sonst Tag). Seit
        // dem Aktualisieren-Pfeil (1.31.12) ist es im Kopf zu eng für Datum UND
        // Uhrzeit – auf der kleinsten Widget-Größe brach sonst der Titel mitten
        // im Wort um. Bewusst per Substring + Calendar statt java.time
        // (Desugaring).
        private fun formatTime(iso: String): String {
            return try {
                if (iso.length < 16) return ""
                val now = java.util.Calendar.getInstance()
                val today = String.format(
                    java.util.Locale.ROOT, "%04d-%02d-%02d",
                    now.get(java.util.Calendar.YEAR),
                    now.get(java.util.Calendar.MONTH) + 1,
                    now.get(java.util.Calendar.DAY_OF_MONTH)
                )
                if (iso.startsWith(today)) iso.substring(11, 16)
                else "${iso.substring(8, 10)}.${iso.substring(5, 7)}."
            } catch (e: Exception) {
                ""
            }
        }

        // Liest den Drive-Login-Status aus app_flutter/drive_state.json (von
        // WidgetService._writeDriveSignInState geschrieben). Fehlt die Datei
        // (z.B. frische Installation), gilt "nicht angemeldet".
        private fun isDriveSignedIn(context: Context): Boolean {
            return try {
                val f = File(context.filesDir.parentFile, "app_flutter/drive_state.json")
                if (f.exists()) JSONObject(f.readText()).optBoolean("signedIn", false)
                else false
            } catch (e: Exception) {
                false
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