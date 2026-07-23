package com.example.notizblock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import java.io.File

/// Homescreen-Widget für einen Ordner: zeigt Ordnername + Notizanzahl, ein Tipp
/// öffnet die App direkt in diesem Ordner (Deep Link notizblock://open_folder).
/// Aufbau analog zum NoteWidgetProvider (pro Widget-Id ein „folder_name_<id>" in
/// widget_prefs, gewählt über die FolderWidgetConfigureActivity).
class FolderWidgetProvider : AppWidgetProvider() {

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
            editor.remove("folder_name_$appWidgetId")
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
            val folderName = prefs.getString("folder_name_$appWidgetId", null)

            val views = RemoteViews(context.packageName, R.layout.folder_widget)

            val displayName = if (folderName.isNullOrEmpty())
                context.getString(R.string.all_notes) else folderName
            views.setTextViewText(R.id.folder_widget_name, displayName)

            // Notizanzahl aus folders.json (leer lassen, wenn unbekannt).
            val count = loadFolderCount(context, folderName)
            views.setTextViewText(
                R.id.folder_widget_count,
                if (count >= 0) count.toString() else ""
            )

            // Deep Link: öffnet die App direkt im gewählten Ordner.
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse(
                    "notizblock://open_folder?name=" + Uri.encode(folderName ?: "")
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.folder_widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // Notizanzahl eines Ordners aus app_flutter/folders.json (-1 = unbekannt).
        private fun loadFolderCount(context: Context, folderName: String?): Int {
            if (folderName.isNullOrEmpty()) return -1
            return try {
                val f = File(context.filesDir.parentFile, "app_flutter/folders.json")
                if (!f.exists()) return -1
                val arr = JSONArray(f.readText())
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    if (o.optString("name") == folderName) {
                        return o.optInt("count", -1)
                    }
                }
                -1
            } catch (e: Exception) {
                -1
            }
        }

        // Alle Ordnernamen aus app_flutter/folders.json (für die Configure-Activity).
        fun loadAllFolders(context: Context): List<String> {
            return try {
                val f = File(context.filesDir.parentFile, "app_flutter/folders.json")
                if (!f.exists()) return emptyList()
                val arr = JSONArray(f.readText())
                (0 until arr.length()).mapNotNull {
                    val name = arr.getJSONObject(it).optString("name", "")
                    if (name.isEmpty()) null else name
                }
            } catch (e: Exception) {
                emptyList()
            }
        }
    }
}
