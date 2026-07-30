// ─────────────────────────────────────────────────────────────────────────────
// app.dart
// CHANGED:
//   • Removed `import 'dart:io'`  (crashes on web)
//   • Removed `import 'package:flutter_window_close/flutter_window_close.dart'`
//   • Added conditional import for setupWindowClose() via stub / native files
//   • Replaced `Platform.isWindows` with `kIsWindows` (from platform.dart)
//   • Web now also gets PopScope (back-button guard), just like mobile
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:minicrm/views/components/src/show_dialog.dart';
import 'package:provider/provider.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/app/app.dart';

// Conditional import: on web the stub is used (does nothing).
// On native the real flutter_window_close wrapper is used.
import '/utils/src/window_close_stub.dart'
    if (dart.library.io) '/utils/src/window_close_native.dart';

// Conditional import for the system tray (Windows/macOS/Linux only).
// setupTray() puts Mini CRM in the tray; minimizeToTrayOnClose() is what the
// close (X) handler below calls so the app keeps running — and keeps
// receiving reminder / "Event Started" notifications via the Firestore
// listener in windows_notification_service.dart — after the window is
// closed. Actually quitting only happens from the tray's "Exit" item.
import '/utils/src/tray_stub.dart'
    if (dart.library.io) '/utils/src/tray_native.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ShowDialogs showDialogs = ShowDialogs();

  @override
  void initState() {
    super.initState();

    // Register Windows close handler + system tray only on native Windows.
    // setupWindowClose()/setupTray() are no-ops on web / other platforms.
    //
    // Clicking X now hides the window to the tray instead of exiting the
    // process outright — this is what keeps the Firestore notification
    // listener (windows_notification_service.dart) alive so reminder /
    // "Event Started" pushes still arrive after the window is closed.
    // Actually quitting is only available from the tray icon's "Exit" item
    // (see tray_native.dart), which calls exit(0) directly.
    if (!kIsWeb && kIsWindows) {
      setupTray();
      setupWindowClose(() => minimizeToTrayOnClose());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider()..checkLoginStatus(),
        ),
        ChangeNotifierProvider(create: (context) => MessageProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, child) {
          Widget home = authProvider.homeWidget ?? const Splash();

          // On Windows native: no PopScope (window_close handles it).
          // On web AND mobile: wrap with PopScope for back-button / browser
          // back navigation guard.
          if (!kIsWindows) {
            home = PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                final ctx = navigatorKey.currentContext;
                if (ctx == null) return;
                await showDialogs.showExitConfirmationDialog(ctx);
              },
              child: home,
            );
          }

          return MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: messengerKey,
            debugShowCheckedModeBanner: false,
            title: "Mini CRM",
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            home: authProvider.isLoggedIn ? home : const Splash(),
          );
        },
      ),
    );
  }
}