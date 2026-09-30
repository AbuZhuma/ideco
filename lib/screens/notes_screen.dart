import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/note.dart';
import '../utils/format.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  final String notebookId;
  const NotesScreen({super.key, required this.notebookId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notebook = state.notebookById(widget.notebookId);
    if (notebook == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold();
    }

    var notes = state.notesOf(widget.notebookId);
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      notes = notes
          .where(
            (n) =>
                n.title.toLowerCase().contains(q) ||
                n.text.toLowerCase().contains(q),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск по заметкам',
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(notebook.title),
        actions: [
          IconButton(
            tooltip: _searching ? 'Закрыть поиск' : 'Поиск',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query = '';
                _searchController.clear();
              }
            }),
          ),
        ],
      ),
      body: notes.isEmpty
          ? Center(
              child: Text(
                q.isEmpty
                    ? 'Пока пусто. Нажмите «Заметка» и диктуйте.'
                    : 'Ничего не найдено',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, i) => _NoteTile(
                note: notes[i],
                onTap: () => _openEditor(notes[i].id),
                onDelete: () => _deleteNote(notes[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final note = context.read<AppState>().createNote(widget.notebookId);
          _openEditor(note.id, startDictation: true);
        },
        icon: const Icon(Icons.mic),
        label: const Text('Заметка'),
      ),
    );
  }

  void _openEditor(String noteId, {bool startDictation = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NoteEditorScreen(noteId: noteId, startDictation: startDictation),
      ),
    );
  }

  void _deleteNote(Note note) {
    final state = context.read<AppState>();
    state.deleteNote(note.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Заметка удалена'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () => state.restoreNote(note),
          ),
        ),
      );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final snippet = note.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final showSnippet = note.title.trim().isNotEmpty && snippet.isNotEmpty;

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: cs.onError),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        title: Text(
          note.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          showSnippet
              ? '$snippet\n${formatDate(note.updatedAt)}'
              : formatDate(note.updatedAt),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: showSnippet,
        onTap: onTap,
      ),
    );
  }
}
