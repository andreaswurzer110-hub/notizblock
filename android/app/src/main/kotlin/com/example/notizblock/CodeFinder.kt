package com.example.notizblock

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.media.ExifInterface
import android.os.Build
import android.os.SystemClock
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * Codes auf einem Foto finden – auch die, an denen ML Kit im ersten Anlauf scheitert (seit 1.34.0):
 *  1. das Bild, so wie es angezeigt wird, und dasselbe als Negativ (hell auf dunkel gelaserte
 *     oder gedruckte Codes auf Typenschildern und Gehäuseböden liest ML Kit sonst nicht);
 *  2. das Foto in voller Auflösung, in Kacheln: Große Bilder verkleinert ML Kit vor dem Suchen,
 *     dabei gehen kleine Codes verloren (QR mit 3 Bildpunkten je Modul erst so gefunden);
 *  3. Stellen, an denen ML Kit einen Code vermutet, ihn aber nicht lesen konnte: ausgeschnitten
 *     und auf die Arten aus [WAYS] noch einmal – auch geglättet, denn an der körnigen
 *     Oberfläche gelaserter Codes scheitert die Erkennung sonst.
 * [shown] ist das aufgerichtete, verkleinerte Bild; [path] das Foto, aus dem es stammt. Die
 * Rahmen sind in Bildpunkten von [shown]. Blockiert – nur im Hintergrund aufrufen.
 * Gleiche Datei wie CodeFinder.kt in den A-Seiten und in der Tastatur von Phone-Connect AW
 * (nur das Paket anders). Hier für „Foto“/„Galerie“ im Autopool-Scanner (MainActivity.findCodes).
 */
class CodeFinder(private val path: String, private val shown: Bitmap) {

    class Found(val value: String, val format: Int, val box: Rect)

    private val scanner: BarcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            // Auch Vermutungen ohne Inhalt melden: Die schauen wir uns in Schritt 3 näher an.
            .enableAllPotentialBarcodes()
            .build(),
    )

    private var deadline = 0L
    private var sharp: Sharp? = null

    fun find(): List<Found> = try {
        deadline = SystemClock.uptimeMillis() + BUDGET_MS
        sharp = Sharp.open(path, shown.width)
        search()
    } finally {
        sharp?.decoder?.recycle()
        scanner.close()
    }

    private fun timeUp() = SystemClock.uptimeMillis() > deadline

    private fun search(): List<Found> {
        val found = ArrayList<Found>()
        val guesses = ArrayList<Rect>()
        fun take(list: List<Barcode>, toShown: Matrix?) {
            for (b in list) {
                val box = b.boundingBox?.let { if (toShown == null) it else mapped(it, toShown) } ?: continue
                val value = b.rawValue ?: b.displayValue
                if (value.isNullOrEmpty()) guesses += box else add(found, Found(value, b.format, box))
            }
        }
        val looked = ArrayList<Rect>()
        // Was schon gelesen oder schon näher angesehen ist, braucht keinen zweiten Blick. Die
        // größten Vermutungen zuerst – kleine sind oft nur Muster im Hintergrund.
        fun examine() {
            val open = merge(guesses.filter { g -> (found.map { it.box } + looked).none { Rect.intersects(it, g) } })
                .sortedByDescending { it.width() * it.height() }
                .take((MAX_GUESSES - looked.size).coerceAtLeast(0))
            guesses.clear()
            for (g in open) {
                if (timeUp()) break
                looked += g
                closer(g)?.let { add(found, it) }
            }
        }
        take(scan(shown), null)
        val negative = negative(shown)
        try {
            take(scan(negative), null)
        } finally {
            negative.recycle()
        }
        // Erst die Stellen, die ML Kit schon vermutet (kurz), dann die Kacheln (lang) und was
        // dort neu vermutet wurde.
        examine()
        sharp?.let { s -> tiles(s) { list, toShown -> take(list, toShown) } }
        examine()
        return found
    }

    private fun add(list: MutableList<Found>, f: Found) {
        if (list.any { it.value == f.value && Rect.intersects(it.box, f.box) }) return
        list += f
    }

    private fun scan(bitmap: Bitmap): List<Barcode> =
        Tasks.await(scanner.process(InputImage.fromBitmap(bitmap, 0)))

    private fun mapped(box: Rect, m: Matrix): Rect {
        val r = RectF(box).also { m.mapRect(it) }
        return Rect(floor(r.left).toInt(), floor(r.top).toInt(), ceil(r.right).toInt(), ceil(r.bottom).toInt())
    }

    // Überlappende Vermutungen (normal, Negativ, Nachbarkacheln) zu einer zusammenfassen.
    private fun merge(boxes: List<Rect>): List<Rect> {
        val out = ArrayList<Rect>()
        for (b in boxes) {
            val same = out.firstOrNull { Rect.intersects(it, b) }
            if (same != null) same.union(b) else out += Rect(b)
        }
        return out
    }

    // Das Foto in voller Auflösung in überlappenden Kacheln absuchen. Die Kacheln bleiben, wie
    // sie in der Datei liegen (evtl. gedreht) – ML Kit liest Codes in jeder Lage. Sehr große Fotos
    // (50 Megapixel) halb oder viertel aufgelöst, damit es höchstens MAX_TILES Kacheln werden.
    private fun tiles(s: Sharp, take: (List<Barcode>, Matrix) -> Unit) {
        var sample = 1
        while (sample < 8 && starts(s.rawW / sample).size * starts(s.rawH / sample).size > MAX_TILES) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        for (y in starts(s.rawH / sample)) {
            for (x in starts(s.rawW / sample)) {
                if (timeUp()) return
                val r = Rect(x * sample, y * sample, minOf(s.rawW, (x + TILE) * sample), minOf(s.rawH, (y + TILE) * sample))
                val part = try {
                    s.decoder.decodeRegion(r, options)
                } catch (e: Exception) {
                    null
                } ?: continue
                try {
                    val toShown = Matrix().apply {
                        setScale(r.width().toFloat() / part.width, r.height().toFloat() / part.height)
                        postTranslate(r.left.toFloat(), r.top.toFloat())
                        postConcat(s.rawToShown)
                    }
                    take(scan(part), toShown)
                } finally {
                    part.recycle()
                }
            }
        }
    }

    // Anfänge der Kacheln entlang einer Seite, gleichmäßig verteilt. Benachbarte überlappen um
    // mindestens TILE_OVERLAP: So liegt jeder Code bis zu dieser Größe ganz in einer Kachel –
    // größere findet schon die Suche im angezeigten Bild.
    private fun starts(length: Int): List<Int> {
        if (length <= TILE) return listOf(0)
        val n = ceil((length - TILE).toFloat() / (TILE - TILE_OVERLAP)).toInt() + 1
        return List(n) { i -> ((length - TILE).toLong() * i / (n - 1)).toInt() }
    }

    // Die vermutete Stelle mit Rand ausschneiden und auf die Arten aus WAYS noch einmal versuchen,
    // bis eine klappt oder die Zeit um ist.
    private fun closer(guess: Rect): Found? {
        val pad = maxOf(guess.width(), guess.height()) * 0.3f + 8f
        val area = RectF(guess).apply { inset(-pad, -pad) }
        if (!area.intersect(0f, 0f, shown.width.toFloat(), shown.height.toFloat())) return null
        val (crop, toShown) = cut(area) ?: return null
        try {
            for (way in WAYS) {
                if (timeUp()) break
                val f = way.side.toFloat() / maxOf(crop.width, crop.height)
                val sized = if (f in 0.95f..1.05f) {
                    crop
                } else {
                    Bitmap.createScaledBitmap(
                        crop,
                        (crop.width * f).roundToInt().coerceAtLeast(1),
                        (crop.height * f).roundToInt().coerceAtLeast(1),
                        true,
                    )
                }
                val image = when {
                    way.blur > 0 -> smooth(sized, way.blur, way.invert)
                    way.invert -> negative(sized)
                    else -> sized
                }
                try {
                    for (b in scan(image)) {
                        val value = b.rawValue ?: b.displayValue
                        val box = b.boundingBox
                        if (value.isNullOrEmpty() || box == null) continue
                        val back = sized.width.toFloat() / crop.width
                        val m = Matrix().apply {
                            setScale(1f / back, 1f / back)
                            postConcat(toShown)
                        }
                        return Found(value, b.format, mapped(box, m))
                    }
                } finally {
                    if (image !== sized) image.recycle()
                    if (sized !== crop) sized.recycle()
                }
            }
        } finally {
            crop.recycle()
        }
        return null
    }

    // Ausschnitt [area] (Punkte von shown) als eigenes Bild, dazu die Umrechnung seiner
    // Bildpunkte zurück nach shown. Am liebsten aus dem Foto in voller Auflösung.
    private fun cut(area: RectF): Pair<Bitmap, Matrix>? {
        val s = sharp
        if (s != null) {
            try {
                cutSharp(s, area)?.let { return it }
            } catch (e: Exception) {
            } catch (e: OutOfMemoryError) {
            }
        }
        val r = Rect(
            floor(area.left).toInt(), floor(area.top).toInt(),
            ceil(area.right).toInt().coerceAtMost(shown.width),
            ceil(area.bottom).toInt().coerceAtMost(shown.height),
        )
        if (r.width() < 2 || r.height() < 2) return null
        var part = Bitmap.createBitmap(shown, r.left, r.top, r.width(), r.height())
        // Ganzes Bild: createBitmap gibt shown selbst zurück – das darf nicht recycelt werden.
        if (part === shown) part = shown.copy(Bitmap.Config.ARGB_8888, false)
        return part to Matrix().apply { setTranslate(r.left.toFloat(), r.top.toFloat()) }
    }

    // Nur den Ausschnitt aus der Datei lesen und aufrichten – das ganze Foto in voller Größe
    // bräuchte bei 50 Megapixeln 200 MB Speicher.
    private fun cutSharp(s: Sharp, area: RectF): Pair<Bitmap, Matrix>? {
        val raw = RectF(area).also { s.shownToRaw.mapRect(it) }
        val region = Rect(floor(raw.left).toInt(), floor(raw.top).toInt(), ceil(raw.right).toInt(), ceil(raw.bottom).toInt())
        if (!region.intersect(0, 0, s.rawW, s.rawH) || region.width() < 2 || region.height() < 2) return null
        var sample = 1
        while (maxOf(region.width(), region.height()) / (sample * 2) >= CROP_SIDE) sample *= 2
        val part = s.decoder.decodeRegion(region, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: return null
        // Bildpunkt des Ausschnitts → Datei → shown.
        val partToShown = Matrix().apply {
            setScale(region.width().toFloat() / part.width, region.height().toFloat() / part.height)
            postTranslate(region.left.toFloat(), region.top.toFloat())
            postConcat(s.rawToShown)
        }
        if (s.turn.isIdentity) return part to partToShown
        // Aufrichten wie das angezeigte Bild; die Umrechnung geht dann rückwärts durch die Drehung.
        val upright = Bitmap.createBitmap(part, 0, 0, part.width, part.height, s.turn, true)
        val partToUpright = Matrix(s.turn).apply {
            val b = RectF(0f, 0f, part.width.toFloat(), part.height.toFloat()).also { s.turn.mapRect(it) }
            postTranslate(-b.left, -b.top)
        }
        val toShown = Matrix().also { partToUpright.invert(it) }.apply { postConcat(partToShown) }
        if (upright !== part) part.recycle()
        return upright to toShown
    }

    // Geglättet und auf vollen Kontrast gezogen, in Grau. Gelaserte oder geprägte Codes haben
    // eine körnige Oberfläche, an der ML Kit scheitert; ein weicher Schleier (zweimal
    // Kastenfilter) lässt nur die Module übrig.
    private fun smooth(bitmap: Bitmap, radius: Int, invert: Boolean): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        val px = IntArray(w * h)
        bitmap.getPixels(px, 0, w, 0, 0, w, h)
        var gray = IntArray(w * h) { i ->
            val c = px[i]
            ((c shr 16 and 255) * 77 + (c shr 8 and 255) * 150 + (c and 255) * 29) shr 8
        }
        repeat(2) { gray = boxBlur(gray, w, h, radius) }
        // Die dunkelsten und hellsten 2 % werden schwarz bzw. weiß.
        val hist = IntArray(256)
        for (g in gray) hist[g]++
        val cut = gray.size / 50
        var lo = 0
        var sum = 0
        while (lo < 255 && sum + hist[lo] <= cut) sum += hist[lo++]
        var hi = 255
        sum = 0
        while (hi > lo && sum + hist[hi] <= cut) sum += hist[hi--]
        val span = maxOf(1, hi - lo)
        for (i in px.indices) {
            var v = ((gray[i] - lo) * 255 / span).coerceIn(0, 255)
            if (invert) v = 255 - v
            px[i] = (0xFF shl 24) or (v shl 16) or (v shl 8) or v
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    // Kastenfilter mit gleitender Summe, waagrecht und senkrecht; am Rand wird der Randpunkt
    // wiederholt.
    private fun boxBlur(src: IntArray, w: Int, h: Int, r: Int): IntArray {
        val n = 2 * r + 1
        val tmp = IntArray(src.size)
        for (y in 0 until h) {
            val row = y * w
            var acc = 0
            for (k in -r..r) acc += src[row + k.coerceIn(0, w - 1)]
            for (x in 0 until w) {
                tmp[row + x] = acc / n
                acc += src[row + (x + r + 1).coerceAtMost(w - 1)] - src[row + (x - r).coerceAtLeast(0)]
            }
        }
        val out = IntArray(src.size)
        for (x in 0 until w) {
            var acc = 0
            for (k in -r..r) acc += tmp[k.coerceIn(0, h - 1) * w + x]
            for (y in 0 until h) {
                out[y * w + x] = acc / n
                acc += tmp[(y + r + 1).coerceAtMost(h - 1) * w + x] - tmp[(y - r).coerceAtLeast(0) * w + x]
            }
        }
        return out
    }

    private fun negative(bitmap: Bitmap): Bitmap {
        val out = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val paint = Paint().apply {
            colorFilter = ColorMatrixColorFilter(
                ColorMatrix(
                    floatArrayOf(
                        -1f, 0f, 0f, 0f, 255f,
                        0f, -1f, 0f, 0f, 255f,
                        0f, 0f, -1f, 0f, 255f,
                        0f, 0f, 0f, 1f, 0f,
                    ),
                ),
            )
        }
        Canvas(out).drawBitmap(bitmap, 0f, 0f, paint)
        return out
    }

    /**
     * Das Foto in voller Auflösung: liest Ausschnitte direkt aus der Datei. [turn] dreht bzw.
     * spiegelt laut EXIF wie MainActivity.loadUpright (ohne Verkleinern).
     */
    private class Sharp(val decoder: BitmapRegionDecoder, val turn: Matrix, shownWidth: Int) {
        val rawW = decoder.width
        val rawH = decoder.height
        val rawToShown: Matrix
        val shownToRaw = Matrix()

        /** Bildpunkte des Fotos je Bildpunkt von shown. */
        val k: Float

        init {
            // Datei → aufrecht: Drehung/Spiegelung, danach zurück in den positiven Bereich.
            val b = RectF(0f, 0f, rawW.toFloat(), rawH.toFloat()).also { turn.mapRect(it) }
            k = b.width() / shownWidth
            rawToShown = Matrix(turn).apply {
                postTranslate(-b.left, -b.top)
                postScale(1f / k, 1f / k)
            }
            rawToShown.invert(shownToRaw)
        }

        companion object {
            // null, wenn die Datei sich nicht stückweise lesen lässt oder kaum größer ist als
            // shown – dann gibt es nichts zu gewinnen.
            fun open(path: String, shownWidth: Int): Sharp? {
                val decoder = try {
                    if (Build.VERSION.SDK_INT >= 31) {
                        BitmapRegionDecoder.newInstance(path)
                    } else {
                        @Suppress("DEPRECATION")
                        BitmapRegionDecoder.newInstance(path, false)
                    }
                } catch (e: Exception) {
                    null
                } ?: return null
                val s = Sharp(decoder, orientation(path), shownWidth)
                if (s.k >= 1.2f) return s
                decoder.recycle()
                return null
            }

            private fun orientation(path: String): Matrix {
                val m = Matrix()
                val o = try {
                    ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                } catch (e: Exception) {
                    ExifInterface.ORIENTATION_NORMAL
                }
                when (o) {
                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
                    ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
                    ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
                    ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(-90f); m.postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
                }
                return m
            }
        }
    }

    // Eine Art, den Ausschnitt noch einmal zu zeigen: lange Seite in Bildpunkten, Glättung
    // (0 = keine), als Negativ.
    private class Way(val side: Int, val blur: Int, val invert: Boolean)

    private companion object {
        // Höchstens so viele vermutete Codes näher ansehen.
        const val MAX_GUESSES = 4
        // Nach so vielen Millisekunden keine neuen Anläufe mehr – lieber ohne Code als ewig warten.
        const val BUDGET_MS = 5000L
        // Kachelgröße für die Suche in voller Auflösung. Ganze Fotos (4096) und auch 2560er
        // Bilder verkleinert ML Kit so stark, dass ein QR-Code mit 3 Bildpunkten je Modul
        // verschwindet; in 1600er Kacheln wurde er gefunden.
        const val TILE = 1600
        const val TILE_OVERLAP = 128
        // 12 Megapixel (4000 × 3000) ergeben 2 × 3 Kacheln.
        const val MAX_TILES = 9
        // Lange Seite, auf die ein Ausschnitt aus dem Foto höchstens gelesen wird.
        const val CROP_SIDE = 960

        // Reihenfolge der Versuche an einer vermuteten Stelle. Erst so, wie der Code ist (zu
        // kleine werden dabei vergrößert), dann geglättet. Größe und Glättung im Emulator an einem
        // gelaserten Data-Matrix-Code ausprobiert (Typenschild eines Docks, hell auf dunkel):
        // ML Kit las ihn nur geglättet und nur als Negativ, am sichersten bei 640 Bildpunkten mit
        // Glättung 3–5; bei 960 und 1280 nur vereinzelt.
        val WAYS = listOf(
            Way(960, 0, false),
            Way(960, 0, true),
            Way(640, 4, true),
            Way(640, 4, false),
            Way(480, 2, true),
            Way(480, 2, false),
            Way(640, 3, true),
            Way(640, 3, false),
        )
    }
}
