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
import org.json.JSONObject

class NoteWidgetConfigureActivity : Activity() {

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

        // Layout programmatisch erstellen
        val scrollView = ScrollView(this)
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            setBackgroundColor(Color.WHITE)
        }

        // Titel
        val title = TextView(this).apply {
            text = getString(R.string.select_note)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setTextColor(Color.parseColor("#333333"))
            setPadding(0, 0, 0, 32)
        }
        container.addView(title)

        // Notizen laden und anzeigen
        val notes = NoteWidgetProvider.loadAllNotes(this)
        
        if (notes.isEmpty()) {
            val emptyText = TextView(this).apply {
                text = getString(R.string.no_notes)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(Color.parseColor("#666666"))
                gravity = Gravity.CENTER
                setPadding(0, 64, 0, 64)
            }
            container.addView(emptyText)
        } else {
            for (note in notes) {
                val noteView = createNoteView(note)
                container.addView(noteView)
            }
        }

        scrollView.addView(container)
        setContentView(scrollView)
    }

    private fun createNoteView(note: JSONObject): LinearLayout {
        val noteTitle = note.optString("title", "")
        val noteContent = note.optString("content", "")
        val noteColor = note.optString("color", "#FFFDE7")

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
            
            try {
                setBackgroundColor(Color.parseColor(noteColor))
            } catch (e: Exception) {
                setBackgroundColor(Color.parseColor("#FFFDE7"))
            }

            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.setMargins(0, 0, 0, 16)
            layoutParams = params

            // Titel
            val titleView = TextView(context).apply {
                text = if (noteTitle.isNotEmpty()) noteTitle else getString(R.string.empty_note)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(Color.parseColor("#333333"))
                maxLines = 1
            }
            addView(titleView)

            // Vorschau
            if (noteContent.isNotEmpty()) {
                val contentView = TextView(context).apply {
                    text = noteContent
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                    setTextColor(Color.parseColor("#666666"))
                    maxLines = 2
                    setPadding(0, 8, 0, 0)
                }
                addView(contentView)
            }

            // Klick-Listener
            setOnClickListener {
                saveNoteSelection(note)
            }
        }
    }

    private fun saveNoteSelection(note: JSONObject) {
        val noteId = note.getString("id")
        
        val prefs = getSharedPreferences("widget_prefs", MODE_PRIVATE)
        prefs.edit().putString("note_id_$appWidgetId", noteId).apply()

        val appWidgetManager = AppWidgetManager.getInstance(this)
        NoteWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId)

        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)
        finish()
    }
}