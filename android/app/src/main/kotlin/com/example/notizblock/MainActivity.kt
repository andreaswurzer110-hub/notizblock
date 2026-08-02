package com.example.notizblock

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "notizblock/deeplink"
    private var initialNoteId: String? = null
    private var initialFolder: String? = null
    // Per „Teilen" aus einer anderen App geschickter Text (+ optionaler Betreff,
    // den z.B. Browser als Seitentitel mitschicken). Wird von Flutter beim Start
    // und bei jedem Resume abgeholt (getSharedText) und dabei zurückgesetzt.
    private var sharedText: String? = null
    private var sharedSubject: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        // „Teilen" aus einer anderen App (ACTION_SEND, text/plain). Nur merken –
        // Flutter holt den Text ab (wie beim Ordner-Widget ist ein sofortiges
        // invokeMethod beim Warm-Resume unzuverlässig).
        if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!text.isNullOrEmpty()) {
                sharedText = text
                sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
            }
            return
        }

        val data = intent.data ?: return
        if (data.scheme != "notizblock") return
        when (data.host) {
            "edit_note" -> {
                val noteId = data.getQueryParameter("id")
                if (noteId != null) {
                    initialNoteId = noteId
                    // Wenn Flutter Engine bereits läuft, sende Nachricht
                    flutterEngine?.dartExecutor?.let {
                        MethodChannel(it.binaryMessenger, CHANNEL)
                            .invokeMethod("openNote", noteId)
                    }
                }
            }
            "open_folder" -> {
                // Ordner-Widget: den gewählten Ordner nur vormerken (leer = Alle).
                // KEIN sofortiges invokeMethod: beim Warm-Resume aus dem Hintergrund
                // ist die Zustellung unzuverlässig (erst der 2. Tap kam an). Flutter
                // fragt den Ordner stattdessen bei JEDEM Resume via getInitialFolder
                // ab (siehe _checkPendingFolder) – das greift auch beim 1. Tap.
                initialFolder = data.getQueryParameter("name") ?: ""
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialNoteId" -> {
                    result.success(initialNoteId)
                    initialNoteId = null // Reset nach Abruf
                }
                "getInitialFolder" -> {
                    result.success(initialFolder)
                    initialFolder = null // Reset nach Abruf
                }
                "getSharedText" -> {
                    val text = sharedText
                    if (text == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf("text" to text, "subject" to (sharedSubject ?: ""))
                        )
                    }
                    // Genau einmal ausliefern (sonst käme der Text bei jedem
                    // Resume erneut).
                    sharedText = null
                    sharedSubject = null
                }
                else -> result.notImplemented()
            }
        }
    }
}
