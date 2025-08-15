import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Ask for camera permission
Future<bool> ensureCamera(BuildContext context) async {
  final status = await Permission.camera.status;
  if (status.isGranted) return true;

  final req = await Permission.camera.request();
  if (req.isGranted) return true;

  // On iOS, after the first denial the prompt won’t show again.
  if (req.isPermanentlyDenied || (Platform.isIOS && req.isDenied)) {
    await _openSettingsDialog(context, 'Camera');
  }
  return false;
}

/// Ask for notifications permission:
/// - iOS: use FirebaseMessaging.requestPermission() to trigger the iOS system prompt.
///         This is what makes the "Notifications" section appear in Settings for your app.
/// - Android 13+: uses runtime POST_NOTIFICATIONS via permission_handler.
Future<bool> ensureNotifications(BuildContext context) async {
  if (Platform.isIOS) {
    // Check current status via FCM
    final current = await FirebaseMessaging.instance.getNotificationSettings();
    if (current.authorizationStatus == AuthorizationStatus.authorized ||
        current.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }

    // Request iOS authorization (alert/badge/sound)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false, // set to true if you want "Deliver Quietly"
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // (Optional) Ensure APNs registration; FCM usually handles this automatically.
      await FirebaseMessaging.instance.getAPNSToken();
      return true;
    }

    // User denied → open App Settings so they can enable it manually
    await _openSettingsDialog(context, 'Notifications');
    return false;
  } else {
    // ANDROID path
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final req = await Permission.notification.request();
    if (req.isGranted) return true;

    if (req.isPermanentlyDenied || req.isDenied) {
      await _openSettingsDialog(context, 'Notifications');
    }
    return false;
  }
}

/// Ask for microphone permission (voice messages / recording)
Future<bool> ensureMic(BuildContext context) async {
  final status = await Permission.microphone.status;
  if (status.isGranted) return true;

  final req = await Permission.microphone.request();
  if (req.isGranted) return true;

  if (req.isPermanentlyDenied || (Platform.isIOS && req.isDenied)) {
    await _openSettingsDialog(context, 'Microphone');
  }
  return false;
}

/// Ask for photos/gallery access
/// iOS: Permission.photos (may be 'limited' or 'granted').
/// Android: Permission.storage (plugin maps to READ_MEDIA_IMAGES on 13+).
Future<bool> ensurePhotos(BuildContext context) async {
  if (Platform.isIOS) {
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;

    final req = await Permission.photos.request();
    if (req.isGranted || req.isLimited) return true;

    if (req.isPermanentlyDenied || req.isDenied || req.isRestricted) {
      await _openSettingsDialog(context, 'Photos');
    }
    return false;
  } else {
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final req = await Permission.storage.request();
    if (req.isGranted) return true;

    if (req.isPermanentlyDenied || req.isDenied) {
      await _openSettingsDialog(context, 'Photos/Storage');
    }
    return false;
  }
}

Future<void> _openSettingsDialog(BuildContext context, String title) async {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Permission required'),
      content: Text('Please enable $title from App Settings to continue.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}
