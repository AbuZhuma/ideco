import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'models/note.dart';
import 'models/notebook.dart';
import 'models/settings.dart';
import 'services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  AppData _data = AppData.empty();
  bool _loaded = false;
  Timer? _saveTimer;

  AppState(this._storage);

  bool get loaded => _loaded;
  DictationSettings get settings => _data.settings;

  List<Notebook> get notebooks {
    final list = [..._data.notebooks];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<Note> notesOf(String notebookId) {
    final list = _data.notes.where((n) => n.notebookId == notebookId).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  int noteCount(String notebookId) =>
      _data.notes.where((n) => n.notebookId == notebookId).length;

  Notebook? notebookById(String id) =>
      _data.notebooks.where((n) => n.id == id).firstOrNull;

  Note? noteById(String id) => _data.notes.where((n) => n.id == id).firstOrNull;

  Future<void> load() async {
    _data = await _storage.load();
    if (_data.notebooks.isEmpty && _data.notes.isEmpty) {
      final now = DateTime.now();
      _data.notebooks.add(
        Notebook(
          id: _uuid.v4(),
          title: 'Мои заметки',
          createdAt: now,
          updatedAt: now,
        ),
      );
      _scheduleSave();
    }
    _loaded = true;
    notifyListeners();
  }

  Notebook createNotebook(String title) {
    final now = DateTime.now();
    final nb = Notebook(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Новый блокнот' : title.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _data.notebooks.add(nb);
    _changed();
    return nb;
  }

  void renameNotebook(String id, String title) {
    final nb = notebookById(id);
    if (nb == null || title.trim().isEmpty) return;
    nb.title = title.trim();
    nb.updatedAt = DateTime.now();
    _changed();
  }

  void deleteNotebook(String id) {
    _data.notebooks.removeWhere((n) => n.id == id);
    _data.notes.removeWhere((n) => n.notebookId == id);
    _changed();
  }

  Note createNote(String notebookId) {
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      notebookId: notebookId,
      createdAt: now,
      updatedAt: now,
    );
    _data.notes.add(note);
    _touchNotebook(notebookId);
    _changed();
    return note;
  }

  void updateNote(String id, {String? title, String? text}) {
    final note = noteById(id);
    if (note == null) return;
    var dirty = false;
    if (title != null && title != note.title) {
      note.title = title;
      dirty = true;
    }
    if (text != null && text != note.text) {
      note.text = text;
      dirty = true;
    }
    if (!dirty) return;
    note.updatedAt = DateTime.now();
    _touchNotebook(note.notebookId);
    _changed();
  }

  void deleteNote(String id) {
    final note = noteById(id);
    if (note == null) return;
    _data.notes.remove(note);
    _changed();
  }

  void restoreNote(Note note) {
    if (noteById(note.id) != null) return;
    _data.notes.add(note);
    _changed();
  }

  void moveNote(String id, String toNotebookId) {
    final note = noteById(id);
    if (note == null || note.notebookId == toNotebookId) return;
    _data.notes.remove(note);
    _data.notes.add(
      Note(
        id: note.id,
        notebookId: toNotebookId,
        title: note.title,
        text: note.text,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    _touchNotebook(toNotebookId);
    _changed();
  }

  void updateSettings(void Function(DictationSettings s) edit) {
    edit(_data.settings);
    _changed();
  }

  void _touchNotebook(String id) {
    notebookById(id)?.updatedAt = DateTime.now();
  }

  void _changed() {
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      await _storage.save(_data);
    } catch (e) {
      debugPrint('save failed: $e');
    }
  }
}
