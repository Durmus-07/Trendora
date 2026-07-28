import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechInputStartResult { started, permissionDenied, unavailable, failed }

typedef SpeechTranscriptCallback = void Function(String text, bool isFinal);
typedef SpeechListeningCallback = void Function(bool isListening);
typedef SpeechFailureCallback = void Function(SpeechInputStartResult failure);

abstract interface class SpeechInputService {
  bool get isListening;

  Future<SpeechInputStartResult> start({
    required SpeechTranscriptCallback onTranscript,
    required SpeechListeningCallback onListeningChanged,
    required SpeechFailureCallback onFailure,
  });

  Future<void> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceSpeechInputService implements SpeechInputService {
  DeviceSpeechInputService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _disposed = false;
  String? _turkishLocaleId;
  SpeechTranscriptCallback? _onTranscript;
  SpeechListeningCallback? _onListeningChanged;
  SpeechFailureCallback? _onFailure;

  @override
  bool get isListening => !_disposed && _speech.isListening;

  @override
  Future<SpeechInputStartResult> start({
    required SpeechTranscriptCallback onTranscript,
    required SpeechListeningCallback onListeningChanged,
    required SpeechFailureCallback onFailure,
  }) async {
    if (_disposed) return SpeechInputStartResult.failed;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return SpeechInputStartResult.unavailable;
    }
    if (_speech.isListening) return SpeechInputStartResult.started;

    _onTranscript = onTranscript;
    _onListeningChanged = onListeningChanged;
    _onFailure = onFailure;
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onStatus: _handleStatus,
          onError: _handleError,
          debugLogging: false,
          options: [SpeechToText.androidNoBluetooth],
        );
        if (!_initialized) {
          final permitted = await _speech.hasPermission;
          return permitted
              ? SpeechInputStartResult.unavailable
              : SpeechInputStartResult.permissionDenied;
        }
        _turkishLocaleId = await _findTurkishLocale();
      }
      if (_disposed) return SpeechInputStartResult.failed;
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: ListenMode.confirmation,
          localeId: _turkishLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      if (_disposed) {
        await _speech.cancel();
        return SpeechInputStartResult.failed;
      }
      _onListeningChanged?.call(true);
      return SpeechInputStartResult.started;
    } catch (_) {
      if (!_disposed) _onFailure?.call(SpeechInputStartResult.failed);
      return SpeechInputStartResult.failed;
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed || !_initialized) return;
    try {
      await _speech.stop();
    } catch (_) {}
    if (!_disposed) _onListeningChanged?.call(false);
  }

  @override
  Future<void> cancel() async {
    if (_disposed || !_initialized) return;
    try {
      await _speech.cancel();
    } catch (_) {}
    if (!_disposed) _onListeningChanged?.call(false);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_initialized) {
      try {
        await _speech.cancel();
      } catch (_) {}
    }
    _disposed = true;
    _onTranscript = null;
    _onListeningChanged = null;
    _onFailure = null;
  }

  Future<String?> _findTurkishLocale() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('tr')) {
          return locale.localeId;
        }
      }
    } catch (_) {}
    return null;
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (_disposed) return;
    _onTranscript?.call(result.recognizedWords, result.finalResult);
  }

  void _handleStatus(String status) {
    if (_disposed) return;
    if (status == SpeechToText.listeningStatus) {
      _onListeningChanged?.call(true);
    } else if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _onListeningChanged?.call(false);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (_disposed) return;
    final permissionDenied = error.errorMsg.toLowerCase().contains(
      'permission',
    );
    _onFailure?.call(
      permissionDenied
          ? SpeechInputStartResult.permissionDenied
          : SpeechInputStartResult.failed,
    );
    _onListeningChanged?.call(false);
  }
}
