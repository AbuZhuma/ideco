import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../models/settings.dart';
import '../services/speech_service.dart';
import '../services/text_processor.dart';
import '../widgets/dictation_text_controller.dart';
import '../widgets/mic_button.dart';
import 'notebooks_screen.dart' show confirm;
import 'settings_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;
  final bool startDictation;

  const NoteEditorScreen({
    super.key,
    required this.noteId,
    this.startDictation = false,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final AppState _state;
  late final TextEditingController _title;
  late final DictationTextController _body;
  final _bodyFocus = FocusNode();
  final _speech = SpeechService();

  String _before = '';
  String _committed = '';
  String _after = '';
  String _preview = '';
  bool _programmatic = false;
  late TextProcessor _processor;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    final note = _state.noteById(widget.noteId);
    _title = TextEditingController(text: note?.title ?? '');
    _body = DictationTextController(text: note?.text ?? '');
    _body.addListener(_onBodyControllerChanged);
    _speech.onPartial = _onPartial;
    _speech.onFinal = _onFinal;
    _speech.addListener(_onSpeechChanged);
    if (widget.startDictation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleDictation());
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _speech.removeListener(_onSpeechChanged);
    _speech.dispose();
    _body.removeListener(_onBodyControllerChanged);
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    final note = _state.noteById(widget.noteId);
    if (note != null && note.isEmpty) {
      _state.deleteNote(widget.noteId);
    }
    _state.flush();
    super.dispose();
  }

  DictationSettings get _settings => _state.settings;

  Future<void> _toggleDictation() async {
    if (_speech.isListening) {
      await _stopDictation();
      return;
    }
    _processor = TextProcessor(_settings);
    _anchorAtCursor();
    _bodyFocus.requestFocus();
    await WakelockPlus.enable();
    await _speech.start(
      localeId: _settings.localeId,
      continuous: _settings.continuous,
    );
    if (_speech.error != null && mounted) {
      await WakelockPlus.disable();
      setState(() {});
    }
  }

  Future<void> _stopDictation() async {
    await _speech.stop();
    await WakelockPlus.disable();
    _preview = '';
    _body.clearPreview();
    if (mounted) setState(() {});
  }

  void _anchorAtCursor() {
    final text = _body.text;
    var pos = _body.selection.isValid ? _body.selection.end : text.length;
    pos = pos.clamp(0, text.length);
    _before = text.substring(0, pos);
    _after = text.substring(pos);
    if (RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(_after)) {
      _after = ' $_after';
    }
    _committed = '';
    _preview = '';
  }

  void _onPartial(String text) {
    if (!_speech.isListening) return;
    _preview = text;
    final ctx = _before + _committed;
    final full = _preview.isEmpty
        ? ctx
        : _processor.append(ctx, _preview, afterPause: _committed.isNotEmpty);
    _setBody(full, previewFrom: _commonPrefix(ctx, full));
  }

  void _onFinal(String text) {
    _preview = '';
    _commitSegment(text);
  }

  void _commitSegment(String text) {
    final ctx = _before + _committed;
    final full = _processor.append(
      ctx,
      text,
      afterPause: _committed.isNotEmpty,
    );
    _committed = full.length >= _before.length && full.startsWith(_before)
        ? full.substring(_before.length)
        : (() {
            _before = full;
            return '';
          })();
    _setBody(full, previewFrom: null);
  }

  void _setBody(String inserted, {required int? previewFrom}) {
    final full = inserted + _after;
    _programmatic = true;
    _body.previewStart = previewFrom;
    _body.previewEnd = previewFrom == null ? null : inserted.length;
    _body.value = TextEditingValue(
      text: full,
      selection: TextSelection.collapsed(offset: inserted.length),
    );
    _programmatic = false;
    _state.updateNote(widget.noteId, text: full);
  }

  void _onBodyControllerChanged() {
    if (_programmatic || !_speech.isListening) return;
    final expected = (_before + _committed).length;
    final sel = _body.selection;
    final textChanged = _body.text != _before + _committed + _after;
    final cursorMoved = sel.isValid && sel.isCollapsed && sel.end != expected;
    if (!textChanged && !cursorMoved) return;
    if (_preview.isNotEmpty) {
      if (textChanged) _stopDictation();
      return;
    }
    _anchorAtCursor();
  }

  static int _commonPrefix(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  void _onSpeechChanged() {
    if (!mounted) return;
    if (!_speech.isListening) {
      _preview = '';
      _body.clearPreview();
      WakelockPlus.disable();
    }
    setState(() {});
  }

  Future<void> _share() async {
    final title = _title.text.trim();
    final text = _body.text.trim();
    if (title.isEmpty && text.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        text: title.isEmpty ? text : '$title\n\n$text',
        subject: title.isEmpty ? null : title,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Удалить заметку?',
      message: 'Это действие нельзя отменить.',
    );
    if (!ok || !mounted) return;
    await _speech.stop();
    _state.deleteNote(widget.noteId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _move() async {
    final note = _state.noteById(widget.noteId);
    if (note == null) return;
    final others = _state.notebooks
        .where((n) => n.id != note.notebookId)
        .toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Нет других блокнотов')));
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Переместить в…'),
        children: [
          for (final nb in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(nb.id),
              child: Text(nb.title),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    _state.moveNote(note.id, target);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final listening = _speech.isListening;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметка'),
        actions: [
          IconButton(
            tooltip: 'Поделиться',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'move') _move();
              if (v == 'delete') _delete();
              if (v == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'move',
                child: Text('Переместить в блокнот'),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text('Настройки диктовки'),
              ),
              PopupMenuItem(value: 'delete', child: Text('Удалить заметку')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Заголовок',
                    isDense: true,
                  ),
                  onChanged: (v) => _state.updateNote(widget.noteId, title: v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _body,
                  focusNode: _bodyFocus,
                  maxLines: null,
                  minLines: 12,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 17, height: 1.45),
                  decoration: const InputDecoration(
                    hintText: 'Начните печатать или нажмите микрофон…',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    if (!_programmatic) {
                      _state.updateNote(widget.noteId, text: v);
                    }
                  },
                ),
              ],
            ),
          ),
          _DictationBar(
            listening: listening,
            sessionActive: _speech.sessionActive,
            level: _speech.level,
            error: _speech.error,
            hasPreview: _preview.isNotEmpty,
            onMic: _toggleDictation,
            onHelp: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            color: cs,
          ),
        ],
      ),
    );
  }
}

class _DictationBar extends StatelessWidget {
  final bool listening;
  final bool sessionActive;
  final double level;
  final String? error;
  final bool hasPreview;
  final VoidCallback onMic;
  final VoidCallback onHelp;
  final ColorScheme color;

  const _DictationBar({
    required this.listening,
    required this.sessionActive,
    required this.level,
    required this.error,
    required this.hasPreview,
    required this.onMic,
    required this.onHelp,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final String status;
    final Color statusColor;
    if (error != null) {
      status = error!;
      statusColor = color.error;
    } else if (listening) {
      status = hasPreview
          ? 'Распознаю…'
          : (sessionActive ? 'Слушаю — говорите' : 'Пауза, продолжаю слушать…');
      statusColor = color.primary;
    } else {
      status =
          'Нажмите микрофон и говорите. «Точка», «запятая», «новая строка» — '
          'команды.';
      statusColor = color.outline;
    }

    return Material(
      color: color.surfaceContainerLow,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: statusColor, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Команды и настройки',
                    icon: const Icon(Icons.help_outline),
                    onPressed: onHelp,
                  ),
                  MicButton(
                    listening: listening,
                    active: sessionActive,
                    level: level,
                    onPressed: onMic,
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
