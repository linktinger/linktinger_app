import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart'; // ← مهم: يولّده flutterfire configure

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forget_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/messenger/chat_screen.dart';
import 'screens/messenger/hat_list_screen.dart';
import 'screens/profile/user_profile_screen.dart';
import 'screens/reset_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

/// ---- FCM background handler (Android/iOS) ----
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // يمكنك إضافة لوجيك هنا إن أردت
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase init باستخدام خيارات المنصّة
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2) ربط background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3) تهيئة flutter_local_notifications حسب المنصّة
  if (Platform.isAndroid) {
    const androidChannel = AndroidNotificationChannel(
      'linktinger_channel',
      'Linktinger Notifications',
      description: 'General notifications for Linktinger',
      importance: Importance.max,
    );
    await flnp
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  } else if (Platform.isIOS) {
    // iOS: طلب الإذن + عرض الإشعارات في المقدّمة
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(iOS: iosInit);
    await flnp.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  // 4) التعامل مع الحالة: فتح إشعار والتطبيق "مغلق" (terminated)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleMessageNavigation(initialMessage.data);
  }

  runApp(const LinktingerApp());

  // 5) Listeners بعد تشغيل التطبيق
  _setupFcmListeners();
}

/// عند الضغط على إشعار محلي (show) نقرأ payload ونوجّه
void _onLocalNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final data = Uri.splitQueryString(payload);
  _handleMessageNavigation(data);
}

/// توحيد التنقّل من أي مصدر (Push مباشر أو Local)
void _handleMessageNavigation(Map<String, dynamic> data) {
  // اجلب القيم بأمان
  final cur =
      int.tryParse('${data['currentUserId'] ?? data['currentUserID'] ?? 0}') ??
      0;
  final tgt = int.tryParse('${data['targetUserId'] ?? 0}') ?? 0;
  final name = '${data['targetUsername'] ?? ''}';
  final img = '${data['profile_image_url'] ?? ''}';

  if (cur > 0 && tgt > 0) {
    navigatorKey.currentState?.pushNamed(
      '/chat',
      arguments: {
        'currentUserId': cur,
        'targetUserId': tgt,
        'targetUsername': name,
        'targetProfileImage': img,
      },
    );
  }
}

/// مستمعو الرسائل (foreground + when opened from background)
void _setupFcmListeners() {
  // Foreground: نعرض Local notification (Android) أو iOS سيعرض حسب setForegroundNotificationPresentationOptions
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final n = message.notification;
    final d = message.data;

    // على Android نحتاج show لنعرض تنبيه داخل التطبيق
    if (n != null && Platform.isAndroid) {
      final payload = Uri.encodeFull(
        'currentUserId=${d['currentUserId'] ?? d['currentUserID'] ?? ''}'
        '&targetUserId=${d['targetUserId'] ?? ''}'
        '&targetUsername=${d['targetUsername'] ?? ''}'
        '&profile_image_url=${d['profile_image_url'] ?? ''}',
      );

      await flnp.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'linktinger_channel',
            'Linktinger Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    }

    // على iOS يكفي setForegroundNotificationPresentationOptions ليظهر Banner/Sound/Badge
  });

  // عندما يفتح المستخدم الإشعار والتطبيق بالخلفية
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleMessageNavigation(message.data);
  });
}

class LinktingerApp extends StatelessWidget {
  const LinktingerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linktinger',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        if (uri.path == '/reset-password' &&
            uri.queryParameters.containsKey('token')) {
          final token = uri.queryParameters['token']!;
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
          );
        }

        final routeBuilder = appRoutes[uri.path];
        if (routeBuilder != null) {
          return MaterialPageRoute(builder: routeBuilder);
        }

        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('404 - Page Not Found'))),
        );
      },
    );
  }
}

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/register': (context) => const RegisterScreen(),
  '/login': (context) => const LoginScreen(),
  '/forget': (context) => const ForgetPasswordScreen(),
  '/home': (context) => const MainScreen(),
  '/messages': (context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userId = args?['userId'] is int ? args!['userId'] : 0;
    return MessagesListScreen(userId: userId);
  },
  '/chat': (context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return ChatScreen(
      currentUserId: args?['currentUserId'] ?? 0,
      targetUserId: args?['targetUserId'] ?? 0,
      targetUsername: args?['targetUsername'] ?? '',
      targetProfileImage: args?['targetProfileImage'] ?? '',
    );
  },
  '/profile': (context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userId = args?['userId'] ?? 0;
    return UserProfileScreen(userId: userId);
  },
};
