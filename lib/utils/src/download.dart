import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:leadcapture/models/src/download_model.dart';
import 'package:path/path.dart' as path;
import '/services/services.dart' show ErrorService, Spdb;
import '/theme/theme.dart';
import '/views/views.dart';
import '/utils/utils.dart';

// Conditional import: on web → dart:html blob download.
//                    on native → dart:io filesystem save.
import 'download_io.dart'
    if (dart.library.html) 'download_web.dart' show saveFileToDownloads, runNativeUrlDownload;

class Download {
  // ── URL download ──────────────────────────────────────────────────────────
  static Future<void> downloadFromUrl(
    BuildContext context,
    String url,
    String? name,
  ) async {
    if (kIsWeb) {
      await _webDownloadFromUrl(context, url, name);
    } else {
      await _nativeDownloadFromUrl(context, url, name);
    }
  }

  // Web: fetch via Dio bytes + trigger browser download
  static Future<void> _webDownloadFromUrl(
    BuildContext context,
    String url,
    String? name,
  ) async {
    final String fileName = name != null && name.isNotEmpty
        ? path.basename(name)
        : path.basename(url);
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null) {
        final bytes = Uint8List.fromList(response.data!);
        await saveFileToDownloads(bytes, fileName: fileName);
      }
      await FirebaseFirestore.instance.collection('download_history').add(
            DownloadHistoryModel(
              fileName: fileName,
              filePath: url,
              url: url,
              fileSize: response.data?.length ?? 0,
              downloadedAt: DateTime.now(),
              isSuccess: true,
              userId: await Spdb.getUid() ?? '',
            ).toMap(),
          );
      if (context.mounted) {
        FlushBar.show(context, "Download Completed", isSuccess: true);
      }
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      if (context.mounted) {
        FlushBar.show(context, "Download Failed",
            isSuccess: false, error: e, stackTrace: st);
      }
    }
  }

  // Native: Dio HTTP download → save to filesystem → open
  static Future<void> _nativeDownloadFromUrl(
    BuildContext context,
    String url,
    String? name,
  ) async {
    await _NativeUrlDownloader.run(context, url, name);
  }

  // ── Asset download ────────────────────────────────────────────────────────
  static Future<void> downloadFromAsset(
    BuildContext context,
    String assetPath,
    String fileName,
  ) async {
    int progress = 0;
    final overlayState = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _DownloadProgressIndicator(progress: progress),
        ),
      ),
    );
    overlayState.insert(overlayEntry);

    try {
      final ByteData data = await rootBundle.load(assetPath);
      progress = 50;
      overlayEntry.markNeedsBuild();

      final Uint8List bytes = data.buffer.asUint8List();
      // saveFileToDownloads is resolved by the conditional import above:
      //   web    → dart:html blob download (returns fileName as pseudo-path)
      //   native → writes to filesystem (returns real file path)
      final String savePath =
          await saveFileToDownloads(bytes, fileName: fileName);

      progress = 100;
      overlayEntry.markNeedsBuild();

      await FirebaseFirestore.instance.collection('download_history').add(
            DownloadHistoryModel(
              fileName: fileName,
              filePath: savePath,
              url: assetPath,
              fileSize: bytes.length,
              downloadedAt: DateTime.now(),
              isSuccess: true,
              userId: await Spdb.getUid() ?? '',
            ).toMap(),
          );

      overlayEntry.remove();
      if (context.mounted) {
        FlushBar.show(context, "Download Completed", isSuccess: true);
        // On native, open the saved file; on web the browser already downloaded it.
        if (!kIsWeb) openfile(savePath, context);
      }
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      overlayEntry.remove();
      if (context.mounted) {
        FlushBar.show(context, "Download Failed",
            isSuccess: false, error: e, stackTrace: st);
      }
    }
  }
}

// ─── Progress indicator widget (unchanged) ────────────────────────────────────
class _DownloadProgressIndicator extends StatelessWidget {
  final int progress;
  const _DownloadProgressIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress / 100),
            const SizedBox(width: 10),
            Text(
              'Downloading... $progress%',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Native URL downloader (private — only instantiated under !kIsWeb) ────────
// Kept as a private class so dart:io imports stay in download_io.dart only.
// This class itself does NOT import dart:io — it delegates to download_io.dart.
class _NativeUrlDownloader {
  static Future<void> run(
      BuildContext context, String url, String? name) async {
    await runNativeUrlDownload(context, url, name);
  }
}

// Forward declaration resolved by the conditional import at the top of this file.
// download_io.dart   exports `_runNativeUrlDownload` for native.
// download_web.dart  exports a no-op for web (never called due to kIsWeb check).
