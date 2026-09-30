import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/notebook.dart';
import '../utils/format.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';

class NotebooksScreen extends StatelessWidget {
  const NotebooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notebooks = state.notebooks;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/icon/logo.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text('Ideco'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: notebooks.isEmpty
          ? const _Empty(
              icon: Icons.menu_book_outlined,
              text: 'Создайте первый блокнот',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notebooks.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final nb = notebooks[i];
                final count = state.noteCount(nb.id);
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 4),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.book_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    nb.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${plural(count, 'заметка', 'заметки', 'заметок')} · '
                    '${formatDate(nb.updatedAt)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Меню',
                    onSelected: (v) => _onMenu(context, v, nb),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Переименовать'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotesScreen(notebookId: nb.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final title = await promptText(
            context,
            title: 'Новый блокнот',
            hint: 'Название',
          );
          if (title == null || !context.mounted) return;
          final nb = context.read<AppState>().createNotebook(title);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotesScreen(notebookId: nb.id)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Блокнот'),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String action, Notebook nb) async {
    final state = context.read<AppState>();
    if (action == 'rename') {
      final title = await promptText(
        context,
        title: 'Переименовать',
        hint: 'Название',
        initial: nb.title,
      );
      if (title != null) state.renameNotebook(nb.id, title);
    } else if (action == 'delete') {
      final count = state.noteCount(nb.id);
      final ok = await confirm(
        context,
        title: 'Удалить блокнот?',
        message: count == 0
            ? '«${nb.title}» будет удалён.'
            : 'Вместе с блокнотом «${nb.title}» будут удалены '
                  '${plural(count, 'заметка', 'заметки', 'заметок')}.',
      );
      if (ok) state.deleteNotebook(nb.id);
    }
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: cs.outline, fontSize: 16)),
        ],
      ),
    );
  }
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Готово'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.trim().isEmpty) return null;
  return result.trim();
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Удалить',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
