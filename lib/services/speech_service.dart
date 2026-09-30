import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool _wantListening = false;
  bool _sessionActive = false;
  bool _continuous = true;
  String _localeId = 'ru_RU';
  String? _error;
  double _level = 0;
  Timer? _restartTimer;
  int _consecutiveErrors = 0;

  String _lastPartial = '';
  bool _finalDelivered = false;

  void Function(String text)? onPartial;
  void Function(String text)? onFinal;

  bool get isAvailable => _available;
  bool get isListening => _wantListening;
  bool get sessionActive => _sessionActive;
  String? get error => _error;
  double get level => _level;

  Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        finalTimeout: const Duration(milliseconds: 500),
      );
    } catch (e) {
      _available = false;
      _error = 'Распознавание недоступно: $e';
    }
    if (!_available && _error == null) {
      _error =
          'Распознавание речи недоступно. Проверьте разрешение на микрофон '
          'и наличие сервиса распознавания (Google) на устройстве.';
    }
    notifyListeners();
    return _available;
  }

  Future<List<LocaleName>> locales() async {
    if (!await init()) return const [];
    return _speech.locales();
  }

  Future<void> start({
    required String localeId,
    required bool continuous,
  }) async {
    if (!await init()) return;
    _localeId = localeId;
    _continuous = continuous;
    _wantListening = true;
    _error = null;
    _consecutiveErrors = 0;
    notifyListeners();
    await _listen();
  }

  Future<void> stop() async {
    _wantListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    if (_speech.isListening) {
      await _speech.stop();
      final deadline = DateTime.now().add(const Duration(milliseconds: 1500));
      while (!_finalDelivered &&
          _lastPartial.isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      _flushPartial();
    }
    _sessionActive = false;
    _level = 0;
    notifyListeners();
  }

  Future<void> _listen() async {
    if (!_wantListening || _speech.isListening) return;
    _lastPartial = '';
    _finalDelivered = false;
    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          autoPunctuation: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(minutes: 5),
        ),
      );
      _sessionActive = true;
      notifyListeners();
    } catch (e) {
      _error = 'Не удалось начать запись: $e';
      _wantListening = false;
      _sessionActive = false;
      notifyListeners();
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    final text = r.recognizedWords;
    if (r.finalResult) {
      if (_finalDelivered) return;
      _finalDelivered = true;
      _lastPartial = '';
      _consecutiveErrors = 0;
      if (text.trim().isNotEmpty) onFinal?.call(text);
      onPartial?.call('');
    } else {
      _lastPartial = text;
      onPartial?.call(text);
    }
  }

  void _flushPartial() {
    if (_finalDelivered) return;
    final text = _lastPartial;
    _finalDelivered = true;
    _lastPartial = '';
    if (text.trim().isNotEmpty) onFinal?.call(text);
    onPartial?.call('');
  }

  void _onLevel(double db) {
    final v = ((db + 2) / 12).clamp(0.0, 1.0);
    if ((v - _level).abs() > 0.03) {
      _level = v;
      notifyListeners();
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _sessionActive = true;
      notifyListeners();
    } else if (status == 'done' || status == 'notListening') {
      _sessionActive = false;
      _level = 0;
      if (status == 'done') _flushPartial();
      notifyListeners();
      if (status == 'done') _scheduleRestart(const Duration(milliseconds: 250));
    }
  }

  void _onError(SpeechRecognitionError e) {
    final msg = e.errorMsg;
    const benign = {
      'error_no_match',
      'error_speech_timeout',
      'error_client',
      'error_busy',
    };
    if (benign.contains(msg)) {
      _consecutiveErrors++;
      if (_consecutiveErrors > 8) {
        _fail('Распознаватель не отвечает. Попробуйте ещё раз.');
        return;
      }
      _scheduleRestart(
        msg == 'error_busy'
            ? const Duration(seconds: 1)
            : const Duration(milliseconds: 400),
      );
      return;
    }
    if (msg == 'error_network' || msg == 'error_network_timeout') {
      _fail(
        'Нет связи с сервисом распознавания. Проверьте интернет или '
        'скачайте офлайн-пакет русского языка в настройках Google.',
      );
      return;
    }
    if (msg.contains('permission')) {
      _fail('Нет разрешения на микрофон. Разрешите доступ в настройках.');
      return;
    }
    if (msg == 'error_language_not_supported' ||
        msg == 'error_language_unavailable') {
      _fail('Выбранный язык недоступен на этом устройстве.');
      return;
    }
    if (e.permanent) {
      _fail('Ошибка распознавания: $msg');
    } else {
      _scheduleRestart(const Duration(milliseconds: 600));
    }
  }

  void _fail(String message) {
    _flushPartial();
    _error = message;
    _wantListening = false;
    _sessionActive = false;
    _restartTimer?.cancel();
    notifyListeners();
  }

  void _scheduleRestart(Duration delay) {
    if (!_wantListening || !_continuous) {
      if (!_continuous && _wantListening) {
        _wantListening = false;
        notifyListeners();
      }
      return;
    }
    if (_restartTimer?.isActive ?? false) return;
    _restartTimer = Timer(delay, () {
      _restartTimer = null;
      if (_wantListening && !_speech.isListening) _listen();
    });
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }
}
