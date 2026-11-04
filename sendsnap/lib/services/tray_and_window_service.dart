import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Service managing desktop system tray icon, window close interception,
/// and Windows autostart configuration.
class TrayAndWindowService with TrayListener, WindowListener {
  static final TrayAndWindowService instance = TrayAndWindowService._();
  TrayAndWindowService._();

  bool _initialized = false;
  bool _isAutostart = false;

  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<void> init({required bool isAutostartLaunch}) async {
    if (!isDesktop || _initialized) return;
    _initialized = true;
    _isAutostart = isAutostartLaunch;

    try {
      // 1. Initialize Window Manager
      await windowManager.ensureInitialized();
      windowManager.addListener(this);

      // 2. Setup Launch at Startup
      launchAtStartup.setup(
        appName: 'SendSnap',
        appPath: Platform.resolvedExecutable,
        args: ['--autostart'],
      );

      // 3. Configure Window Options
      const windowOptions = WindowOptions(
        size: Size(1000, 680),
        minimumSize: Size(720, 520),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'SendSnap - Fast Nearby File Share',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true);
        if (!_isAutostart) {
          await windowManager.show();
          await windowManager.focus();
        } else {
          // Started on boot — sit silently in the system tray
          await windowManager.hide();
        }
      });

      // 4. Initialize System Tray
      trayManager.addListener(this);
      await _setupTray();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Initialization error: $e');
    }
  }

  Future<void> _setupTray() async {
    try {
      final iconPath = Platform.isWindows
          ? 'assets/icon/app_icon.ico'
          : 'assets/icon/app_icon.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('SendSnap - Ready to share');
      await updateContextMenu();
    } catch (e) {
      debugPrint('[TrayAndWindowService] Tray setup error: $e');
    }
  }

  Future<void> updateContextMenu() async {
    try {
      final autostartEnabled = await isAutostartEnabled();
      final menu = Menu(
        items: [
          MenuItem(
            key: 'open_app',
            label: 'Open SendSnap',
          ),
          MenuItem.separator(),
          MenuItem.checkbox(
            key: 'toggle_autostart',
            label: 'Launch on Windows Startup',
            checked: autostartEnabled,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit SendSnap',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('[TrayAndWindowService] updateContextMenu error: $e');
    }
  }

  Future<bool> isAutostartEnabled() async {
    if (!isDesktop) return false;
    try {
      return await launchAtStartup.isEnabled();
    } catch (e) {
      debugPrint('[TrayAndWindowService] isAutostartEnabled error: $e');
      return false;
    }
  }

  Future<bool> setAutostart(bool enable) async {
    if (!isDesktop) return false;
    try {
      final success = enable
          ? await launchAtStartup.enable()
          : await launchAtStartup.disable();
      await updateContextMenu();
      return success;
    } catch (e) {
      debugPrint('[TrayAndWindowService] setAutostart error: $e');
      return false;
    }
  }

  Future<void> showWindow() async {
    if (!isDesktop) return;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> hideWindow() async {
    if (!isDesktop) return;
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  Future<void> exitApp() async {
    if (!isDesktop) {
      exit(0);
    }
    try {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      await trayManager.destroy();
      await windowManager.destroy();
    } catch (_) {
      exit(0);
    }
  }

  // --- TrayListener Callbacks ---

  @override
  void onTrayIconMouseDown() async {
    try {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } catch (_) {
      await showWindow();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    try {
      await trayManager.popUpContextMenu();
    } catch (_) {}
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'open_app':
        await showWindow();
        break;
      case 'toggle_autostart':
        final current = await isAutostartEnabled();
        await setAutostart(!current);
        break;
      case 'exit_app':
        await exitApp();
        break;
    }
  }

  // --- WindowListener Callbacks ---

  @override
  void onWindowClose() async {
    // Intercept "X" button -> minimize to system tray instead of terminating
    try {
      final isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        await windowManager.hide();
      }
    } catch (_) {}
  }
}
