import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../services/speech_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки диктовки')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Голосовые команды'),
            subtitle: const Text('«точка», «запятая», «новая строка» и др.'),
            value: s.voiceCommands,
            onChanged: (v) => state.updateSettings((s) => s.voiceCommands = v),
          ),
          SwitchListTile(
            title: const Text('Заглавные буквы'),
            subtitle: const Text('Начинать предложения с большой буквы'),
            value: s.autoCapitalize,
            onChanged: (v) => state.updateSettings((s) => s.autoCapitalize = v),
          ),
          SwitchListTile(
            title: const Text('Точка между фразами'),
            subtitle: const Text(
              'Ставить точку, если вы сделали паузу и продолжили без знака',
            ),
            value: s.autoPeriod,
            onChanged: (v) => state.updateSettings((s) => s.autoPeriod = v),
          ),
          SwitchListTile(
            title: const Text('Непрерывная запись'),
            subtitle: const Text(
              'Продолжать слушать после пауз, пока вы не нажмёте «стоп»',
            ),
            value: s.continuous,
            onChanged: (v) => state.updateSettings((s) => s.continuous = v),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Язык распознавания'),
            subtitle: Text(s.localeId),
            onTap: () => _pickLocale(context),
          ),
          const Divider(),
          const _Section('Голосовые команды'),
          const _CommandsTable(),
          const Divider(),
          const _Section('Как получить максимальную точность'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              '• Говорите чётко, обычным темпом, ближе к микрофону.\n'
              '• Распознавание выполняет сервис Google (Android) или Apple (iOS): '
              'при подключении к интернету точность выше.\n'
              '• Для офлайн-работы на Android скачайте русский пакет: '
              'Настройки → Google → Голосовой ввод → Офлайн-распознавание.\n'
              '• Незнакомые имена и термины проверяйте и правьте вручную — '
              'текст редактируется в любой момент.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLocale(BuildContext context) async {
    final state = context.read<AppState>();
    final speech = SpeechService();
    List<LocaleName> locales = await speech.locales();
    speech.dispose();
    if (!context.mounted) return;
    if (locales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Список языков недоступен. Используется ru_RU.'),
        ),
      );
      return;
    }
    locales = [...locales]
      ..sort((a, b) {
        final ar = a.localeId.startsWith('ru') ? 0 : 1;
        final br = b.localeId.startsWith('ru') ? 0 : 1;
        return ar != br ? ar - br : a.name.compareTo(b.name);
      });
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Язык распознавания'),
        children: [
          for (final l in locales)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(l.localeId),
              child: Text(
                l.name,
                style: l.localeId == state.settings.localeId
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
            ),
        ],
      ),
    );
    if (chosen != null) state.updateSettings((s) => s.localeId = chosen);
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _CommandsTable extends StatelessWidget {
  const _CommandsTable();

  static const _rows = [
    ('точка', '.'),
    ('запятая', ','),
    ('вопросительный знак', '?'),
    ('восклицательный знак', '!'),
    ('двоеточие', ':'),
    ('точка с запятой', ';'),
    ('тире', '—'),
    ('многоточие', '…'),
    ('новая строка', 'перенос строки'),
    ('абзац', 'пустая строка'),
    ('открыть / закрыть кавычки', '« »'),
    ('открыть / закрыть скобку', '( )'),
    ('с большой буквы', 'следующее слово с заглавной'),
    ('удалить последнее слово', 'убирает последнее слово'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final r in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '«${r.$1}»',
                      style: TextStyle(color: cs.primary),
                    ),
                  ),
                  Expanded(child: Text(r.$2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
