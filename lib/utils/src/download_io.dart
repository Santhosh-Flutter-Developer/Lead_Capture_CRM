// download_io.dart — native filesystem implementation
// Only compiled on non-web (conditional import in download.dart).
// Freely uses dart:io since web never loads this file.
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:minicrm/models/src/download_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '/services/services.dart' show ErrorService, Spdb;
import '/theme/theme.dart';
import '/views/views.dart';
import '/utils/utils.dart';

/// Saves [bytes] to the platform Downloads folder and returns the file path.
Future<String> saveFileToDownloads(Uint8List bytes, {String? fileName}) async {
  Directory? dir;

  if (Platform.isAndroid) {
    final baseDir = await getExternalStorageDirectory();
    if (baseDir == null) throw Exception('Could not get external storage directory.');
    dir = Directory('${baseDir.path}/Download');
    if (!await dir.exists()) await dir.create(recursive: true);
  } else if (Platform.isIOS) {
    dir = await getApplicationDocumentsDirectory();
  } else if (Platform.isWindows) {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } else if (Platform.isMacOS || Platform.isLinux) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      dir = downloads;
    } else {
      final home = Platform.environment['HOME'];
      dir = home != null
          ? Directory('$home/Downloads')
          : await getApplicationDocumentsDirectory();
    }
  } else {
    dir = await getApplicationDocumentsDirectory();
  }

  final safeFileName =
      (fileName == null || fileName.isEmpty) ? const Uuid().v4() : fileName;
  final file = File('${dir!.path}/$safeFileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Performs an HTTP download, saves to filesystem, opens the file.
/// Called only from _NativeUrlDownloader.run() under !kIsWeb.
Future<void> runNativeUrlDownload(
    BuildContext context, String url, String? name) async {
  final dio = Dio();
  int progress = 0;

  Directory directory = await getApplicationDocumentsDirectory();
  if (Platform.isWindows) {
    directory = (await getDownloadsDirectory())!;
  }

  final String fileName = name != null && name.isNotEmpty
      ? path.basename(name)
      : path.basename(url);
  final String savePath = path.join(directory.path, fileName);

  final overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _NativeProgressWidget(progress: progress),
      ),
    ),
  );
  overlayState.insert(overlayEntry);

  try {
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          progress = (received / total * 100).toInt();
          overlayEntry.markNeedsBuild();
        }
      },
    );

    final fileSize = await File(savePath).length();
    await FirebaseFirestore.instance.collection('download_history').add(
          DownloadHistoryModel(
            fileName: fileName,
            filePath: savePath,
            url: url,
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
            isSuccess: true,
            userId: await Spdb.getUid() ?? '',
          ).toMap(),
        );
    overlayEntry.remove();
    if (context.mounted) {
      FlushBar.show(context, "Download Completed", isSuccess: true);
      openfile(savePath, context);
    }
  } catch (e, st) {
    debugPrint("${e.toString()}, ${st.toString()}");
    await ErrorService.recordError(e, st);
    await FirebaseFirestore.instance.collection('download_history').add(
          DownloadHistoryModel(
            fileName: fileName,
            filePath: '',
            url: url,
            fileSize: 0,
            downloadedAt: DateTime.now(),
            isSuccess: false,
            userId: await Spdb.getUid() ?? '',
          ).toMap(),
        );
    overlayEntry.remove();
    if (context.mounted) {
      FlushBar.show(context, "Download Failed",
          isSuccess: false, error: e, stackTrace: st);
    }
  }
}

class _NativeProgressWidget extends StatelessWidget {
  final int progress;
  const _NativeProgressWidget({required this.progress});
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
