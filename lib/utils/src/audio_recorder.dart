// ─────────────────────────────────────────────────────────────────────────────
// audio_recorder.dart
// CHANGED:
//   • On web: MethodChannel 'com.srisoftwarez.audio_recorder' does not exist.
//     Replaced with conditional import that uses dart:html MediaRecorder API.
//   • permission_handler also does not work on web — replaced with browser
//     getUserMedia permission check on web.
//   • On native: all existing MethodChannel / permission_handler code is kept.
// ─────────────────────────────────────────────────────────────────────────────
import '/services/services.dart';

import 'audio_recorder_io.dart'
    if (dart.library.html) 'audio_recorder_web.dart';

class AudioRecorder {
  /// Requests microphone permission.
  /// On web: uses browser getUserMedia prompt.
  /// On native: uses permission_handler.
  static Future<bool> requestMicPermission() async {
    return requestMicPermissionImpl();
  }

  /// Starts audio recording.
  static Future<void> startRecording() async {
    try {
      await startRecordingImpl();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// Stops recording and returns a path (native) or blob URL (web).
  static Future<String?> stopRecording() async {
    try {
      return await stopRecordingImpl();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }
}
