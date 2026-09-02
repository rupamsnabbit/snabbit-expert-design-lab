import 'package:flutter_tts/flutter_tts.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Speaks a web-supplied string through the platform TTS engine.
///
/// The WebView has no `window.speechSynthesis` — the Web Speech API is a
/// Chrome-for-Android feature that the WebView component does not implement —
/// so web TTS (Saathi's spoken replies) has no engine of its own. This routes
/// it to the same `flutter_tts` the job flows already use.
///
/// Fire-and-forget: the web only needs the words spoken, and awaiting the
/// engine would hold the bridge open for the length of the utterance.
class SpeakHandler implements BifrostHandler {
  SpeakHandler({FlutterTts? tts, this.logger = const MonitoringBifrostLogger()})
    : _tts = tts ?? FlutterTts();

  /// Longest utterance we will read out. Saathi replies are short; a runaway
  /// string would otherwise hold the engine for minutes with no way to stop it
  /// from the web side.
  static const int _maxChars = 1000;

  final FlutterTts _tts;
  final BifrostLogger logger;

  /// Silence whatever is speaking. Called when the webview closes: the engine
  /// outlives the page, so without this a long reply keeps talking over
  /// whatever screen the runner lands on next.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      logger.logError('webview_speak_stop_failed', {'error': e.toString()});
    }
  }

  @override
  String get actionName => WebViewConstants.eventSpeak;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final text = data['text'];
    if (text is! String || text.trim().isEmpty) {
      logger.logError('webview_speak_invalid_data', {'data': data.toString()});
      return const BifrostResult.empty();
    }

    final languageTag = data['languageTag'];
    try {
      // An explicit tap means "read THIS now" — drop whatever is mid-sentence.
      await _tts.stop();
      if (languageTag is String && languageTag.isNotEmpty) {
        // Unavailable languages fall back to the engine default rather than
        // failing the utterance: better the wrong accent than silence.
        await _tts.setLanguage(languageTag);
      }
      await _tts.speak(text.length > _maxChars ? text.substring(0, _maxChars) : text);
    } catch (e) {
      logger.logError('webview_speak_failed', {'error': e.toString()});
    }
    return const BifrostResult.empty();
  }
}
