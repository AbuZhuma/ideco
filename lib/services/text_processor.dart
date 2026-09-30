import '../models/settings.dart';

class TextProcessor {
  final DictationSettings settings;

  const TextProcessor(this.settings);

  static const _capMarker = '\u0001';

  static final _deleteCmd = RegExp(
    r'(?<![а-яё])(удали(?:ть)?|убери|убрать|сотри|стереть)\s+последнее\s+слово(?![а-яё])',
    caseSensitive: false,
  );

  static final _protected = <String, String>{
    'точка зрения': '\u0002',
    'точки зрения': '\u0003',
  };

  static final List<MapEntry<RegExp, String>> _commands = [
    _cmd(r'точка с запятой', ';'),
    _cmd(r'вопросительный знак|знак вопроса', '?'),
    _cmd(r'восклицательный знак', '!'),
    _cmd(r'двоеточие', ':'),
    _cmd(r'многоточие', '…'),
    _cmd(r'(?:длинное\s+)?тире', '—'),
    _cmd(r'новый абзац|с нового абзаца|абзац', '\n\n'),
    _cmd(r'новая строка|с новой строки|перенос строки|перевод строки', '\n'),
    _cmd(r'открыть (?:круглую\s+)?скобк[уи]|открывающая скобка', '('),
    _cmd(r'закрыть (?:круглую\s+)?скобк[уи]|закрывающая скобка', ')'),
    _cmd(r'открыть кавычк[иу]|открывающие кавычки', '«'),
    _cmd(r'закрыть кавычк[иу]|закрывающие кавычки', '»'),
    _cmd(
      r'с большой буквы|с заглавной буквы|заглавная буква|большая буква',
      _capMarker,
    ),
    _cmd(r'запятая', ','),
    _cmd(r'точка', '.'),
  ];

  static MapEntry<RegExp, String> _cmd(String pattern, String repl) => MapEntry(
    RegExp('(?<![а-яё])(?:$pattern)(?![а-яё])', caseSensitive: false),
    repl,
  );

  String append(String context, String segment, {bool afterPause = false}) {
    var seg = _collapseWs(segment);
    if (seg.isEmpty) return context;

    var result = context;
    var insertionStart = context.length;

    if (settings.voiceCommands) {
      final parts = <String>[];
      final deletes = <bool>[];
      var last = 0;
      for (final m in _deleteCmd.allMatches(seg)) {
        parts.add(seg.substring(last, m.start));
        deletes.add(true);
        last = m.end;
      }
      parts.add(seg.substring(last));
      deletes.add(false);

      var first = true;
      for (var i = 0; i < parts.length; i++) {
        final piece = _collapseWs(parts[i]);
        if (piece.isNotEmpty) {
          final joined = _join(
            result,
            _prepare(piece),
            afterPause: afterPause && first,
          );
          insertionStart = insertionStart.clamp(0, joined.length);
          result = joined;
          first = false;
        }
        if (deletes[i]) {
          result = _deleteLastWord(result);
          if (insertionStart > result.length) insertionStart = result.length;
          first = false;
        }
      }
    } else {
      result = _join(result, _prepare(seg), afterPause: afterPause);
    }

    if (settings.autoCapitalize) {
      result = _capitalize(result, from: _commonPrefix(context, result));
    } else {
      result = result.replaceAll(_capMarker, '');
    }
    return result;
  }

  static String _collapseWs(String s) =>
      s.replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ').trim();

  String _prepare(String seg) {
    var s = seg;
    if (settings.voiceCommands) {
      _protected.forEach((phrase, ph) {
        s = s.replaceAll(
          RegExp('(?<![а-яё])$phrase(?![а-яё])', caseSensitive: false),
          ph,
        );
      });
      for (final c in _commands) {
        s = s.replaceAll(c.key, c.value);
      }
      _protected.forEach((phrase, ph) => s = s.replaceAll(ph, phrase));
    }
    return _fixSpacing(s);
  }

  static String _fixSpacing(String input) {
    var s = input;
    s = s.replaceAllMapped(RegExp(r'[ ]*([.,!?;:…])[ ]*'), (m) => '${m[1]} ');
    s = s.replaceAllMapped(RegExp(r'[ ]*([)»])'), (m) => '${m[1]}');
    s = s.replaceAllMapped(
      RegExp(r'([)»])(?=[^\s.,!?;:…)»])'),
      (m) => '${m[1]} ',
    );
    s = s.replaceAllMapped(RegExp(r'([(«])[ ]*'), (m) => '${m[1]}');
    s = s.replaceAllMapped(RegExp(r'(?<=[^\s(«])([(«])'), (m) => ' ${m[1]}');
    s = s.replaceAll(RegExp(r'[ ]*—[ ]*'), ' — ');
    s = s.replaceAll(RegExp('$_capMarker[ ]*'), _capMarker);
    s = s.replaceAll(RegExp(r'[ ]*\n[ ]*'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    s = s.replaceAll(RegExp(r' {2,}'), ' ');
    return s.trim();
  }

  static const _closers = '.,!?;:…)»';
  static const _sentenceEnd = '.!?…';

  String _join(String ctx, String seg, {required bool afterPause}) {
    if (seg.isEmpty) return ctx;
    if (ctx.isEmpty) return seg;

    final trailing = RegExp(r'\s+$').firstMatch(ctx)?.group(0) ?? '';
    if (trailing.contains('\n')) {
      return ctx.trimRight() + trailing.replaceAll(' ', '') + seg;
    }
    final base = ctx.trimRight();
    final last = base[base.length - 1];
    final first = seg[0];

    if (first == '\n') return base + seg;
    if (_closers.contains(first)) return base + seg;
    if (first == _capMarker && seg.length > 1 && _closers.contains(seg[1])) {
      return base + seg;
    }
    if (last == '(' || last == '«') return base + seg;
    if (last == '—' || _sentenceEnd.contains(last)) return '$base $seg';
    if (',;:'.contains(last)) return '$base $seg';
    if (afterPause && settings.autoPeriod && _isWordChar(last)) {
      return '$base. $seg';
    }
    return '$base $seg';
  }

  static bool _isWordChar(String c) =>
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c);

  static String _deleteLastWord(String s) {
    final trimmed = s.trimRight();
    if (trimmed.isEmpty) return '';
    final m = RegExp(
      r'[\p{L}\p{N}\-]+[.,!?;:…»)]*$',
      unicode: true,
    ).firstMatch(trimmed);
    if (m == null) {
      return trimmed.substring(0, trimmed.length - 1).trimRight();
    }
    return trimmed.substring(0, m.start).trimRight();
  }

  static int _commonPrefix(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  static String _capitalize(String text, {required int from}) {
    final buf = StringBuffer();
    var forceNext = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == _capMarker) {
        forceNext = true;
        continue;
      }
      if (i >= from &&
          _isLetter(ch) &&
          (forceNext || _startsSentence(text, i))) {
        buf.write(ch.toUpperCase());
        forceNext = false;
      } else {
        if (_isLetter(ch)) forceNext = false;
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static bool _isLetter(String c) =>
      RegExp(r'\p{L}', unicode: true).hasMatch(c);

  static bool _startsSentence(String text, int i) {
    var j = i - 1;
    while (j >= 0) {
      final c = text[j];
      if (c == ' ' || c == '«' || c == '(' || c == '"' || c == '\u0001') {
        j--;
        continue;
      }
      if (c == '\n') return true;
      return _sentenceEnd.contains(c);
    }
    return true;
  }
}
