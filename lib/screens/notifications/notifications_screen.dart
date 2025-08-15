import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:linktinger_app/models/notification_model.dart';
import 'package:linktinger_app/services/notification_service.dart';
import 'package:linktinger_app/services/permissions.dart'; // ensureNotifications()

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // نهيّئ timeago مرة واحدة فقط
  static bool _timeagoInitialized = false;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _cooldown = false;
  bool _showEnableBanner = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // تهيئة timeago (إنجليزية هنا — بدّل لـ ar لو تحب)
    if (!_timeagoInitialized) {
      timeago.setLocaleMessages('en', timeago.EnMessages());
      timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
      _timeagoInitialized = true;
    }

    // ------ منطق الأذونات بدون "إزعاج" متكرر ------
    bool granted = false;

    if (Platform.isIOS) {
      final current = await _messaging.getNotificationSettings();
      final status = current.authorizationStatus;

      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        granted = true;
      } else if (status == AuthorizationStatus.notDetermined) {
        // أول مرة فقط نطلب الإذن (prompt النظام)
        granted = await ensureNotifications(context);
      } else {
        // denied → لا نطلب تلقائيًا، نُظهر Banner للتفعيل
        granted = false;
      }

      if (granted) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } else {
      // Android 13+ يحتاج POST_NOTIFICATIONS
      final st = await Permission.notification.status;
      if (st.isGranted) {
        granted = true;
      } else if (!st.isPermanentlyDenied) {
        final req = await Permission.notification.request();
        granted = req.isGranted;
      } else {
        granted = false;
      }
    }

    if (!mounted) return;
    setState(() => _showEnableBanner = !granted);

    // (اختياري) اطبع الـ Token للتجارب
    try {
      final token = await _messaging.getToken();
      debugPrint('🔑 FCM token: $token');
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }

    // حمّل الإشعارات
    await _fetchNotifications();

    // رسائل أثناء المقدّمة
    _onMessageSub ??= FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) async {
      final body =
          message.notification?.body ??
          message.data['body'] ??
          '📩 New notification';
      Fluttertoast.showToast(
        msg: body,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
      );

      if (!_cooldown) {
        _cooldown = true;
        await _fetchNotifications();
        Future.delayed(const Duration(seconds: 2), () => _cooldown = false);
      }
    });

    // فُتح من الخلفية
    _onOpenedAppSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNavigateFromMessage,
    );

    // فُتح من الإغلاق التام
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNavigateFromMessage(initial);
  }

  // --- Helpers ---------------------------------------------------------------

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  String _normalizeType(RemoteMessage msg) {
    final rawType = msg.data['type'] ?? msg.notification?.title ?? '';
    return '$rawType'.toLowerCase().trim();
  }

  void _handleNavigateFromMessage(RemoteMessage msg) {
    if (!mounted) return;

    final type = _normalizeType(msg);
    final postId = msg.data['post_id'] ?? msg.data['postId'];
    final senderId = _asInt(
      msg.data['sender_id'] ??
          msg.data['senderId'] ??
          msg.data['user_id'] ??
          msg.data['userId'],
    );

    debugPrint(
      '🔔 Opened from FCM -> type=$type, data=${msg.data}, postId=$postId, senderId=$senderId',
    );

    switch (type) {
      case 'like':
      case 'comment':
        if (postId != null && '$postId'.isNotEmpty) {
          Navigator.pushNamed(context, '/post', arguments: {'postId': postId});
        } else {
          _showSnackBar('Unable to open post: postId missing');
        }
        break;

      case 'follow':
      case 'friend_request':
      case 'follow_request':
        if (senderId != null && senderId > 0) {
          Navigator.pushNamed(
            context,
            '/profile',
            arguments: {'user_id': senderId},
          );
          debugPrint('➡️ Navigate /profile user_id=$senderId');
        } else {
          _showSnackBar('Unable to open profile: sender user_id missing');
        }
        break;

      default:
        break;
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final list = await NotificationService.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load notifications. Please try again.');
    }
  }

  Future<void> _handleAccept(int senderId) async {
    final result = await NotificationService.acceptFollow(senderId);
    if (!mounted) return;
    final ok = result['status'] == 'success';
    _showSnackBar(
      ok
          ? '✅ Request accepted.'
          : (result['message'] ?? 'Something went wrong.'),
    );
    if (ok) await _fetchNotifications();
  }

  Future<void> _handleReject(int senderId) async {
    final result = await NotificationService.rejectFollow(senderId);
    if (!mounted) return;
    final ok = result['status'] == 'success';
    _showSnackBar(
      ok ? '❌ Request rejected.' : (result['message'] ?? 'Failed to reject.'),
    );
    if (ok) await _fetchNotifications();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onOpenedAppSub?.cancel();
    super.dispose();
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final banner = !_showEnableBanner
        ? const SizedBox.shrink()
        : MaterialBanner(
            backgroundColor: Colors.amber.shade50,
            leading: const Icon(Icons.notifications_off_outlined),
            content: const Text('Notifications are turned off. Turn them on to stay updated.'),
            actions: [
              TextButton(
                onPressed: () async {
                  // عند ضغط "تفعيل" نطلب الإذن أو نفتح الإعدادات
                  final ok = await ensureNotifications(context);
                  if (!mounted) return;
                  if (ok) {
                    setState(() => _showEnableBanner = false);
                    if (Platform.isIOS) {
                      await _messaging
                          .setForegroundNotificationPresentationOptions(
                            alert: true,
                            badge: true,
                            sound: true,
                          );
                    }
                  }
                },
                child: const Text('Activation'),
              ),
            ],
          );

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty
        ? Column(
            children: [
              banner,
              const Expanded(
                child: Center(child: Text('There are no notifications.')),
              ),
            ],
          )
        : Column(
            children: [
              banner,
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return NotificationTile(
                        key: ValueKey(
                          'notif_${notif.type}_${notif.senderId}_${notif.postId ?? notif.tweetId ?? 'na'}_${notif.createdAt}',
                        ),
                        notification: notif,
                        onAcceptFollow: _handleAccept,
                        onRejectFollow: _handleReject,
                      );
                    },
                  ),
                ),
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: content,
    );
  }
}

class NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final Future<void> Function(int senderId)? onAcceptFollow;
  final Future<void> Function(int senderId)? onRejectFollow;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onAcceptFollow,
    this.onRejectFollow,
  });

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  bool _actionBusy = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;

    final IconData icon = switch (n.type) {
      'like' => Icons.favorite,
      'comment' => Icons.comment,
      'follow' => Icons.person_add,
      _ => Icons.notifications,
    };

    final bool isPendingFollow =
        n.type == 'follow' && n.followStatus == 'pending';

    DateTime? created;
    try {
      created = DateTime.parse(n.createdAt).toLocal();
    } catch (_) {}

    final timeText = timeago.format(created ?? DateTime.now(), locale: 'en');

    final ImageProvider<Object> imageProvider = (n.senderImage.isNotEmpty)
        ? NetworkImage('https://linktinger.xyz/linktinger-api/${n.senderImage}')
        : const AssetImage('assets/images/user1.jpg');

    void goToProfile() {
      final id = n.senderId;
      if (id is int && id > 0) {
        Navigator.pushNamed(context, '/profile', arguments: {'user_id': id});
        debugPrint('➡️ Navigate /profile user_id=$id (from tile)');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid user id')));
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: goToProfile,
        child: CircleAvatar(radius: 24, backgroundImage: imageProvider),
      ),
      title: GestureDetector(
        onTap: goToProfile,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: n.senderUsername,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' '),
              TextSpan(text: n.message),
            ],
          ),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeText, style: const TextStyle(fontSize: 12)),
          if (isPendingFollow)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _actionBusy
                        ? null
                        : () async {
                            setState(() => _actionBusy = true);
                            await widget.onAcceptFollow?.call(n.senderId);
                            if (mounted) setState(() => _actionBusy = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _actionBusy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Accept',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _actionBusy
                        ? null
                        : () async {
                            setState(() => _actionBusy = true);
                            await widget.onRejectFollow?.call(n.senderId);
                            if (mounted) setState(() => _actionBusy = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: _actionBusy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Reject',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: !isPendingFollow ? Icon(icon, color: Colors.black54) : null,
      onTap: () {
        final id = n.postId ?? n.tweetId;
        switch (n.type) {
          case 'like':
          case 'comment':
            if (id != null) {
              Navigator.pushNamed(context, '/post', arguments: {'postId': id});
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to open post: postId missing'),
                ),
              );
            }
            break;
          case 'follow':
            goToProfile();
            break;
          default:
            break;
        }
      },
    );
  }
}
