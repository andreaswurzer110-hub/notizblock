package com.example.notizblock

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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

    // Autopool-Scanner „Foto“/„Galerie“: offene Antwort an Flutter und die Datei, in die
    // das Bild kommt (cache/scan/). Immer nur ein Auftrag zugleich.
    private var photoResult: MethodChannel.Result? = null
    private var photoFile: File? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CODES_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "photoCodes" -> photoCodes(call.argument<String>("source") == "camera", result)
                else -> result.notImplemented()
            }
        }
    }

    // ------------------------------------------------------- Autopool-Scanner: Foto

    // Kleine oder hell auf dunkel gelaserte Codes liest der Live-Scanner (mobile_scanner)
    // nicht. Dafür ein richtiges Foto: von der Kamera-App (volle Auflösung) oder aus der
    // Galerie. Antwort an Flutter: null = abgebrochen, {"codes": [...]} oder
    // {"error": "camera"|"unreadable"}.
    private fun photoCodes(camera: Boolean, result: MethodChannel.Result) {
        if (photoResult != null) {
            result.error("busy", null, null)
            return
        }
        val dir = File(cacheDir, "scan").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() } // nur das jeweils letzte Foto aufheben
        val file = File(dir, "foto_${System.currentTimeMillis()}.jpg")
        val intent = if (camera) {
            val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.scanfiles", file)
            Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                .putExtra(MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else if (Build.VERSION.SDK_INT >= 33) {
            // Androids Fotoauswahl – ohne Speicherrecht.
            Intent(MediaStore.ACTION_PICK_IMAGES)
        } else {
            Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE)
        }
        photoResult = result
        photoFile = file
        try {
            startActivityForResult(intent, if (camera) REQ_PHOTO else REQ_GALLERY)
        } catch (e: Exception) {
            // Keine Kamera-App, oder das Kamera-Recht fehlt (die App führt es im Manifest,
            // dann verlangt Android es auch für fremde Kamera-Apps).
            photoResult = null
            result.success(mapOf("error" to "camera"))
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PHOTO && requestCode != REQ_GALLERY) return
        val r = photoResult ?: return
        photoResult = null
        val file = photoFile
        if (resultCode != RESULT_OK || file == null) {
            r.success(null)
            return
        }
        val picked = data?.data
        // Lesen und Suchen dauert ein paar Sekunden – nicht im Haupt-Thread.
        Thread {
            val answer: Map<String, Any> = try {
                if (requestCode == REQ_GALLERY) {
                    contentResolver.openInputStream(picked!!)!!.use { input ->
                        file.outputStream().use { input.copyTo(it) }
                    }
                }
                if (!file.exists() || file.length() == 0L) {
                    mapOf("error" to "unreadable")
                } else {
                    mapOf("codes" to findCodes(file.path))
                }
            } catch (e: Exception) {
                mapOf("error" to "unreadable")
            } catch (e: OutOfMemoryError) {
                mapOf("error" to "unreadable")
            }
            runOnUiThread { r.success(answer) }
        }.start()
    }

    private fun findCodes(path: String): List<Map<String, Any>> {
        val bitmap = loadUpright(path)
        try {
            return CodeFinder(path, bitmap).find().map { mapOf("value" to it.value, "format" to it.format) }
        } finally {
            bitmap.recycle()
        }
    }

    // Foto laden, nach EXIF aufrichten und auf höchstens SCAN_MAX_SIDE Punkte bringen – wie
    // in den A-Seiten. Die feinen Stellen liest CodeFinder danach aus der vollen Datei.
    private fun loadUpright(path: String): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= SCAN_MAX_SIDE) sample *= 2
        val raw = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IllegalArgumentException("Bild nicht lesbar")
        val m = Matrix()
        val scale = minOf(1f, SCAN_MAX_SIDE.toFloat() / maxOf(raw.width, raw.height))
        m.postScale(scale, scale)
        val orientation = try {
            ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        } catch (e: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(-90f); m.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
        }
        if (m.isIdentity) return raw
        val upright = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
        if (upright !== raw) raw.recycle()
        return upright
    }

    private companion object {
        const val CODES_CHANNEL = "notizblock/codes"
        const val REQ_PHOTO = 4711
        const val REQ_GALLERY = 4712
        const val SCAN_MAX_SIDE = 2560
    }
}
