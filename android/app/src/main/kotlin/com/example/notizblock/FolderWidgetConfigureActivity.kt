package com.example.notizblock

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.graphics.Color
import android.view.Gravity
import android.util.TypedValue

/// Konfigurations-Bildschirm beim Anlegen eines Ordner-Widgets: zeigt die
/// vorhandenen Ordner (aus folders.json), die Auswahl wird pro Widget-Id in
/// widget_prefs gespeichert. Aufbau programmatisch wie NoteWidgetConfigureActivity.
class FolderWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val scrollView = ScrollView(this)
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            setBackgroundColor(Color.WHITE)
        }

        val title = TextView(this).apply {
            text = getString(R.string.select_folder)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setTextColor(Color.parseColor("#333333"))
            setPadding(0, 0, 0, 32)
        }
        container.addView(title)

        val folders = FolderWidgetProvider.loadAllFolders(this)

        if (folders.isEmpty()) {
            val emptyText = TextView(this).apply {
                text = getString(R.string.no_folders)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                setPadding(0, 64, 0, 64)
            }
            container.addView(emptyText)
        } else {
            for (folder in folders) {
                container.addView(createFolderView(folder))
            }
        }

        scrollView.addView(container)
        setContentView(scrollView)
    }

    private fun createFolderView(folder: String): TextView {
        return TextView(this).apply {
            text = folder
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(Color.parseColor("#333333"))
            setPadding(28, 28, 28, 28)
            setBackgroundColor(Color.parseColor("#F2F2F2"))

            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.setMargins(0, 0, 0, 16)
            layoutParams = params

            setOnClickListener { saveSelection(folder) }
        }
    }

    private fun saveSelection(folder: String) {
        val prefs = getSharedPreferences("widget_prefs", MODE_PRIVATE)
        prefs.edit().putString("folder_name_$appWidgetId", folder).apply()

        val appWidgetManager = AppWidgetManager.getInstance(this)
        FolderWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId)

        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)
        finish()
    }
}
