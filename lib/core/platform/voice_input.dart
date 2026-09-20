import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice-search boundary.
///
/// WEB PORT: speech_to_text has no browser implementation — initialize()
/// throws MissingPluginException on web, turning the mic button into a
/// silent no-op with an unhandled exception. The web adapter reports the
/// engine as unavailable so the search screen takes its existing
/// "microphone access is needed" path. Mobile delegates to the real engine.
class VoiceInput {
  VoiceInput();

  final SpeechToText _speech = SpeechToText();

  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
  }) async {
    if (kIsWeb) {
      return false;
    }
    return _speech.initialize(onError: onError, onStatus: onStatus);
  }

  Future<void> listen({
    required SpeechResultListener onResult,
    SpeechListenOptions? listenOptions,
  }) async {
    if (kIsWeb) {
      return;
    }
    await _speech.listen(onResult: onResult, listenOptions: listenOptions);
  }

  Future<void> stop() async {
    if (kIsWeb) {
      return;
    }
    await _speech.stop();
  }
}
