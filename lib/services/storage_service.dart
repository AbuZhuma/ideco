import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note.dart';
import '../models/notebook.dart';
import '../models/settings.dart';

class AppData {
  final List<Notebook> notebooks;
  final List<Note> notes;
  final DictationSettings settings;

  AppData({
    required this.notebooks,
    required this.notes,
    required this.settings,
  });

  factory AppData.empty() =>
      AppData(notebooks: [], notes: [], settings: DictationSettings());

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    notebooks: (j['notebooks'] as List? ?? [])
        .map((e) => Notebook.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: (j['notes'] as List? ?? [])
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList(),
    settings: j['settings'] == null
        ? DictationSettings()
        : DictationSettings.fromJson(j['settings'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'notebooks': notebooks.map((e) => e.toJson()).toList(),
    'notes': notes.map((e) => e.toJson()).toList(),
    'settings': settings.toJson(),
  };
}

class StorageService {
  static const _fileName = 'voice_notes.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<AppData> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return AppData.empty();
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return AppData.empty();
      return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppData.empty();
    }
  }

  Future<void> save(AppData data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await tmp.rename(f.path);
  }
}
