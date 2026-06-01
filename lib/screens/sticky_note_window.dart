import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class StickyNoteWindow extends StatefulWidget {
  final String windowArgs;

  const StickyNoteWindow({super.key, required this.windowArgs});

  @override
  State<StickyNoteWindow> createState() => _StickyNoteWindowState();
}

class _StickyNoteWindowState extends State<StickyNoteWindow> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _noteId;
  late String _color;
  bool _isLoading = true;
  Note? _note;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _loadNote();
  }

  Future<void> _loadNote() async {
    try {
      final args = jsonDecode(widget.windowArgs) as Map<String, dynamic>;
      _noteId = args['noteId'] as String;
      _color = args['color'] as String? ?? '#FFFDE7';

      _note = await DatabaseService.instance.getNoteById(_noteId);
      
      if (_note != null) {
        _titleController.text = _note!.title;
        _contentController.text = _note!.content;
        _color = _note!.color;
      } else {
        _titleController.text = args['title'] as String? ?? '';
        _contentController.text = args['content'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Notiz: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _saveNote();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_note == null) return;

    final updatedNote = _note!.copyWith(
      title: _titleController.text,
      content: _contentController.text,
    );

    await DatabaseService.instance.updateNote(updatedNote);
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final backgroundColor = _parseColor(_color);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Titel',
                  hintStyle: TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _saveNote(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Notiz schreiben...',
                    hintStyle: TextStyle(color: Colors.black38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => _saveNote(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}