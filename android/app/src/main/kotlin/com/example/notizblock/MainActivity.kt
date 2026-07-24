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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data ?: return
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
                else -> result.notImplemented()
            }
        }
    }
}
