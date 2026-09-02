import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/localization_channel.dart';

import '../services/server_requests/language_http.dart';

class LanguageProvider with ChangeNotifier {
  /// [fetcher] is the i18n loader; it defaults to the real HTTP call and is
  /// injectable so tests can supply canned responses (mirrors the DI-by-function
  /// pattern used elsewhere, e.g. `AadhaarReverificationProvider`).
  LanguageProvider({Future<Response?> Function(String lang)? fetcher})
      : _fetcher =
            fetcher ?? ((lang) => LanguageHttp.getLocalizationData(lang: lang));

  final Future<Response?> Function(String lang) _fetcher;

  Map<String, dynamic> _messages = {};
  String? error;

  String? _currentLanguageCode;

  /// The language code whose i18n messages are currently loaded, or null before
  /// the first successful [fetchMessages]. Used by
  /// [LanguageChannel.reconcilePendingLanguage] to skip a redundant reload when
  /// the KMP-persisted pending language already matches what's loaded.
  String? get currentLanguageCode => _currentLanguageCode;

  Future<void> fetchMessages(String languagePreference) async {
    Response? response = await _fetcher(languagePreference);
    // Logger().i("RESPONSE Language: ${response?.data['help']}");
    // Logger().i(response?.data.toString());
    if (response != null && response.statusCode == 200) {
      error = null;
      _messages = await response.data ?? {};
      _currentLanguageCode = languagePreference;
      _publishToKmp(languagePreference);
    } else {
      error = "Something went wrong - ${response?.statusCode}";
    }
    notifyListeners();
  }

  /// Mirror the freshly-fetched i18n map into the KMP `shared` module (Expert
  /// App 2.0 Compose surfaces) via [LocalizationChannel]. Best-effort — a bridge
  /// hiccup must never disturb the Flutter language flow. [fetchMessages] is the
  /// single choke point for every language-change path (cold-start restore, the
  /// Flutter + native CMP selection screens, onboarding), so this one call covers
  /// them all. Ungated: the push is inert until a KMP surface consumes the store,
  /// and the first consumer will carry its own feature flag.
  void _publishToKmp(String language) {
    LocalizationChannel.pushMessages(
      language: language,
      messagesJson: jsonEncode(_messages),
    );
  }

  // void setLanguage(String language) {
  //   _selectedLanguage = language;
  //   fetchMessages();
  // }

  String getMessage(String key, String defaultEnMsg) {
    ////_messages

    return _messages[key] ?? defaultEnMsg;
  }

  String getFormattedMessage(
      String key, String defaultEnMsg, Map<String, dynamic>? values) {
    String message = getMessage(key, defaultEnMsg);
    if (values == null) {
      return message;
    }
    values.forEach((paramKey, paramValue) {
      message = message.replaceAll("{{$paramKey}}", "$paramValue");
    });

    return message;
  }

  Map getMessages() {
    ///All Messages

    return _messages;
  }

  String getFormattedMessage2(
      String key, String defaultEnMsg, Map<String, dynamic>? values) {
    String message = getMessage(key, defaultEnMsg);
    if (values == null) {
      return message;
    }
    values.forEach((paramKey, paramValue) {
      message = message.replaceAll("{{$paramKey}}", "{{$paramValue}}");
    });

    return message;
  }
}
