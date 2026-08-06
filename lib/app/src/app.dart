// ─────────────────────────────────────────────────────────────────────────────
// app.dart
// CHANGED:
//   • Removed `import 'dart:io'`  (crashes on web)
//   • Removed `import 'package:flutter_window_close/flutter_window_close.dart'`
//   • Added conditional import for setupWindowClose() via stub / native files
//   • Replaced `Platform.isWindows` with `kIsWindows` (from platform.dart)
//   • Web now also gets PopScope (back-button guard), just like mobile
// ─────────────────────────────────────────────────────────────────────────────
// import 'dart:io' show exit; // `exit()` is still needed on Windows — safe
// because it is only called inside !kIsWeb branch.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leadcapture/views/components/src/show_dialog.dart';
import 'package:provider/provider.dart';
// import '../../utils/src/tray_stub.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/app/app.dart';

// Conditional import: on web the stub is used (does nothing).
// On native the real flutter_window_close wrapper is used.
import '/utils/src/window_close_stub.dart'
    if (dart.library.io) '/utils/src/window_close_native.dart';

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

    // Register Windows close handler only on native Windows.
    // The setupWindowClose() call is a no-op on web / other platforms.
    if (!kIsWeb && kIsWindows) {
      setupTray();
      setupWindowClose(() async {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return true;

        bool? shouldExit = await showDialogs.showExitConfirmationDialog(ctx);

        if (shouldExit == true) {
          // exit(0);
          minimizeToTrayOnClose();
        }
        
        return false;
      });
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
            title: "Lead Capture",
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
