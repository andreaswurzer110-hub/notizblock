package com.example.notizblock

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "notizblock/deeplink"
    private var initialNoteId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data
        if (data != null && data.scheme == "notizblock" && data.host == "edit_note") {
            val noteId = data.getQueryParameter("id")
            if (noteId != null) {
                initialNoteId = noteId
                // Wenn Flutter Engine bereits läuft, sende Nachricht
                flutterEngine?.dartExecutor?.let {
                    MethodChannel(it.binaryMessenger, CHANNEL).invokeMethod("openNote", noteId)
                }
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
                else -> result.notImplemented()
            }
        }
    }
}