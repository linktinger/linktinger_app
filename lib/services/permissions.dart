import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// طلب إذن الكاميرا
Future<bool> ensureCamera(BuildContext context) async {
  final st = await Permission.camera.request();
  if (st.isGranted) return true;

  // iOS بعد الرفض الأول لن يظهر الـ prompt ثانية
  if (st.isPermanentlyDenied || (Platform.isIOS && st.isDenied)) {
    await _openSettingsDialog(context, "Camera permission");
  }
  return false;
}

/// طلب إذن التنبيهات (يغطي Android 13+ و iOS) + FCM على iOS
Future<bool> ensureNotifications(BuildContext context) async {
  final st = await Permission.notification.request();
  if (st.isGranted) {
    // على iOS نطلب أيضًا صلاحيات FCM لعرض التنبيهات
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }
    return true;
  }

  if (st.isPermanentlyDenied || (Platform.isIOS && st.isDenied)) {
    await _openSettingsDialog(context, "Notification permission");
  }
  return false;
}

/// طلب إذن الميكروفون لتسجيل الصوت
Future<bool> ensureMic(BuildContext context) async {
  final st = await Permission.microphone.request();
  if (st.isGranted) return true;

  if (st.isPermanentlyDenied || (Platform.isIOS && st.isDenied)) {
    await _openSettingsDialog(context, "Microphone permission");
  }
  return false;
}

/// طلب إذن الوصول للصور/المعرض
/// iOS: Permission.photos (قد يعود limited أو granted)
/// Android: Permission.storage (والـ plugin يتكفّل بترجمة READ_MEDIA_IMAGES على 13+)
Future<bool> ensurePhotos(BuildContext context) async {
  PermissionStatus st;

  if (Platform.isIOS) {
    st = await Permission.photos.request();
    if (st.isGranted || st.isLimited) return true;

    if (st.isPermanentlyDenied || st.isDenied) {
      await _openSettingsDialog(context, "Photos permission");
    }
  } else {
    // Android
    st = await Permission.storage.request();
    if (st.isGranted) return true;

    if (st.isPermanentlyDenied || st.isDenied) {
      await _openSettingsDialog(context, "Photos/Storage permission");
    }
  }
  return false;
}

/// Dialog عام لفتح الإعدادات عند الرفض الدائم
Future<void> _openSettingsDialog(BuildContext context, String title) async {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Permission required"),
      content: Text("Please grant $title from app settings to continue."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings();
          },
          child: const Text("Open Settings"),
        ),
      ],
    ),
  );
}
