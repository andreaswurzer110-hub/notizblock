package com.example.notizblock

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "notizblock/deeplink"

    // GENAU EIN offener Auftrag aus einem Widget-Tipp: "note" (Wert = Notiz-Id)
    // oder "folder" (Wert = Ordnername, leer = Alle Notizen). Bewusst ein
    // einzelner Slot statt zweier unabhängiger Felder – sonst bleibt z.B. eine
    // nie abgeholte Notiz-Id liegen und überholt später den Ordner-Tipp
    // („Ordner-Widget öffnet die vorher offene Notiz").
    private var pendingAction: String? = null
    private var pendingValue: String? = null
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
                if (!noteId.isNullOrEmpty()) setPending("note", noteId)
            }
            "open_folder" -> {
                // Ordner-Widget: leerer Name = „Alle Notizen" (gültiger Wert!).
                setPending("folder", data.getQueryParameter("name") ?: "")
            }
        }
    }

    /// Auftrag vormerken und die laufende Engine anstupsen. Der Anstupser trägt
    /// KEINE Daten – Flutter holt den Auftrag selbst ab (getPendingAction) und
    /// tut das zusätzlich bei jedem Resume. Ein verlorener Anstupser kostet also
    /// nichts; das direkte Durchreichen war beim Warm-Resume unzuverlässig (kam
    /// erst beim 2. Tipp an).
    private fun setPending(action: String, value: String) {
        pendingAction = action
        pendingValue = value
        flutterEngine?.dartExecutor?.let {
            MethodChannel(it.binaryMessenger, CHANNEL).invokeMethod("checkPending", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingAction" -> {
                    val action = pendingAction
                    if (action == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf("action" to action, "value" to (pendingValue ?: ""))
                        )
                    }
                    // Genau einmal ausliefern (sonst käme er bei jedem Resume erneut).
                    pendingAction = null
                    pendingValue = null
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
