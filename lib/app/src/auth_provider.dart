import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';

const _channel = MethodChannel('runtime.check');

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  Widget? _homeWidget;

  bool get isLoggedIn => _isLoggedIn;
  Widget? get homeWidget => _homeWidget;

  Future<void> checkLoginStatus() async {
    try {
      var isLogin = await Spdb.checkLogin();
      bool isUpdateNeed = VersionService.version?.isUpdateNeed ?? false;

      if (!isUpdateNeed) {
        if (Platform.isWindows) {
          var isInstalled = await runtimeInstalled();
          if (!isInstalled) {
            _homeWidget = const RuntimeInstall();
            _isLoggedIn = true;
            notifyListeners();
            return;
          }
        }

        if (isLogin) {
          var isAdmin = await Spdb.isAdminLoggedIn();
          if (kIsDesktop) {
            _homeWidget = RouteScreen();
          } else {
            _homeWidget = MainScreen(isAdmin: isAdmin);
          }
        } else {
          _homeWidget = const Login();
        }
      } else {
        if (Platform.isWindows) {
          _homeWidget = WindowsUpdate();
        } else if (Platform.isAndroid) {
          _homeWidget = AndroidUpdate();
        } else {
          _homeWidget = const Login();
        }
      }

      _isLoggedIn = true;
      notifyListeners();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      _homeWidget = const Login();
      _isLoggedIn = true;
      notifyListeners();
    }
  }
}

Future<bool> runtimeInstalled() async {
  try {
    return await _channel.invokeMethod<bool>('isVCRuntimeInstalled') ?? false;
  } catch (e) {
    return false;
  }
}
