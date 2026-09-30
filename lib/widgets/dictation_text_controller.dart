import 'package:flutter/material.dart';

class DictationTextController extends TextEditingController {
  int? previewStart;
  int? previewEnd;

  DictationTextController({super.text});

  void clearPreview() {
    previewStart = null;
    previewEnd = null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final s = previewStart, e = previewEnd;
    if (s == null || e == null || s >= e || e > text.length || s < 0) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final previewStyle = (style ?? const TextStyle()).copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, s)),
        TextSpan(text: text.substring(s, e), style: previewStyle),
        TextSpan(text: text.substring(e)),
      ],
    );
  }
}
