package com.example.notizblock

import androidx.core.content.FileProvider

/**
 * Gibt der Kamera-App die Zieldatei für „Foto“ im Autopool-Scanner frei (nur `cache/scan/`).
 * Eigene Unterklasse statt androidx.core.content.FileProvider: Zwei Einträge mit demselben
 * Klassennamen (etwa aus einem Plugin) würde der Manifest-Merger zusammenlegen.
 */
class ScanFileProvider : FileProvider()
