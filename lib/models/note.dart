import 'package:uuid/uuid.dart';

class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime modifiedAt;
  String color;
  bool isPinned;
  bool isArchived;
  // Notiz-Typ: 'text' (Standard), 'autopool' (Tabellen-Notiz) oder 'shopping'
  // (Einkaufsliste). Bei 'autopool'/'shopping' steht die strukturierte Form in
  // `autopoolData` (JSON); `content` enthält zusätzlich eine lesbare Textfassung
  // (für Liste/Suche/Widget/Sticky-Anzeige und für ältere App-Versionen).
  final String type;
  // Generisches Struktur-Datenfeld (JSON). Historisch für 'autopool' eingeführt,
  // wird auch von 'shopping' (Einkaufsliste) genutzt – bewusst dasselbe DB-/
  // Sync-Feld, damit ältere Versionen, die einen Typ nicht rendern, die Daten
  // beim Sync-Round-Trip nicht verlieren (der Feldname bleibt aus Kompatibilität).
  String autopoolData;
  // Ordner/Kategorie (z.B. "Privat", "Arbeit"); leer = kein Ordner. Wird MIT der
  // Notiz synchronisiert. Die Ordner-Liste selbst (Reihenfolge/leere Ordner) liegt
  // lokal in den Einstellungen; im Drawer erscheint ein Ordner ohnehin, sobald
  // eine synchronisierte Notiz ihn referenziert.
  String folder;

  Note({
    String? id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.color = '#FFFDE7', // Standard: Hellgelb (Post-it Farbe)
    this.isPinned = false,
    this.isArchived = false,
    this.type = 'text',
    this.autopoolData = '',
    this.folder = '',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  bool get isAutopool => type == 'autopool';
  bool get isShopping => type == 'shopping';

  // Kopie mit Änderungen erstellen
  Note copyWith({
    String? title,
    String? content,
    DateTime? modifiedAt,
    String? color,
    bool? isPinned,
    bool? isArchived,
    String? type,
    String? autopoolData,
    String? folder,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      type: type ?? this.type,
      autopoolData: autopoolData ?? this.autopoolData,
      folder: folder ?? this.folder,
    );
  }

  // Für SQLite Datenbank
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'color': color,
      'isPinned': isPinned ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'type': type,
      'autopoolData': autopoolData,
      'folder': folder,
    };
  }

  // Aus SQLite Datenbank
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      modifiedAt: DateTime.parse(map['modifiedAt'] as String),
      color: map['color'] as String,
      isPinned: (map['isPinned'] as int) == 1,
      isArchived: (map['isArchived'] as int) == 1,
      type: (map['type'] as String?) ?? 'text',
      autopoolData: (map['autopoolData'] as String?) ?? '',
      folder: (map['folder'] as String?) ?? '',
    );
  }

  // Für JSON (Google Drive Sync)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'color': color,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'type': type,
      'autopoolData': autopoolData,
      'folder': folder,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      color: json['color'] as String,
      isPinned: json['isPinned'] as bool,
      isArchived: json['isArchived'] as bool,
      type: (json['type'] as String?) ?? 'text',
      autopoolData: (json['autopoolData'] as String?) ?? '',
      folder: (json['folder'] as String?) ?? '',
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, isPinned: $isPinned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Vordefinierte Farben für Notizen
class NoteColors {
  // Pastell (hell)
  static const String yellow = '#FFFDE7';
  static const String orange = '#FFF3E0';
  static const String pink = '#FCE4EC';
  static const String purple = '#F3E5F5';
  static const String blue = '#E3F2FD';
  static const String cyan = '#E0F7FA';
  static const String green = '#E8F5E9';
  static const String grey = '#FAFAFA';

  // Kräftiger (Material 200–300) – Text wird je nach Helligkeit automatisch
  // dunkel/hell gewählt, daher auch auf den dunkleren gut lesbar.
  static const String yellowStrong = '#FFF176';
  static const String amber = '#FFD54F';
  static const String orangeStrong = '#FFB74D';
  static const String deepOrange = '#FF8A65';
  static const String red = '#E57373';
  static const String pinkStrong = '#F06292';
  static const String purpleStrong = '#BA68C8';
  static const String deepPurple = '#9575CD';
  static const String indigo = '#7986CB';
  static const String blueStrong = '#64B5F6';
  static const String cyanStrong = '#4DD0E1';
  static const String teal = '#4DB6AC';
  static const String greenStrong = '#81C784';
  static const String lightGreen = '#AED581';
  static const String lime = '#DCE775';
  static const String brown = '#A1887F';
  static const String blueGrey = '#90A4AE';

  static List<String> get all => [
        // Pastell
        yellow,
        orange,
        pink,
        purple,
        blue,
        cyan,
        green,
        grey,
        // Kräftig
        yellowStrong,
        amber,
        orangeStrong,
        deepOrange,
        red,
        pinkStrong,
        purpleStrong,
        deepPurple,
        indigo,
        blueStrong,
        cyanStrong,
        teal,
        greenStrong,
        lightGreen,
        lime,
        brown,
        blueGrey,
      ];

  static String getName(String color, String locale) {
    final names = {
      'de': {
        yellow: 'Gelb',
        orange: 'Orange',
        pink: 'Rosa',
        purple: 'Lila',
        blue: 'Blau',
        cyan: 'Türkis',
        green: 'Grün',
        grey: 'Grau',
      },
      'en': {
        yellow: 'Yellow',
        orange: 'Orange',
        pink: 'Pink',
        purple: 'Purple',
        blue: 'Blue',
        cyan: 'Cyan',
        green: 'Green',
        grey: 'Grey',
      },
    };
    return names[locale]?[color] ?? color;
  }
}
