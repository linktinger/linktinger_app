import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _cooldown = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Timeago English messages (usually set once per app)
    timeago.setLocaleMessages('en', timeago.EnMessages());
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());

    // Ask for notification permission (iOS + Android 13+)
    final granted = await ensureNotifications(context);
    if (!mounted) return;

    if (!granted) {
      _showSnackBar(
        'Notifications are disabled. You can enable them in Settings.',
      );
    }

    // iOS-only: configure foreground presentation
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _fetchNotifications();

    // Foreground messages
    _onMessageSub = FirebaseMessaging.onMessage.listen((
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

      // Throttle refresh calls
      if (!_cooldown) {
        _cooldown = true;
        await _fetchNotifications();
        Future.delayed(const Duration(seconds: 2), () => _cooldown = false);
      }
    });

    // Opened from background
    _onOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNavigateFromMessage,
    );

    // Opened from terminated
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNavigateFromMessage(initial);
  }

  // Helpers
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
      '🔔 FCM open -> type=$type, data=${msg.data}, postId=$postId, senderId=$senderId',
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
        // Unknown types: no-op
        break;
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final data = await NotificationService.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data;
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

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty
        ? const Center(child: Text("No notifications yet."))
        : RefreshIndicator(
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
      body: body,
    );
  }
}

class NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final Function(int senderId)? onAcceptFollow;
  final Function(int senderId)? onRejectFollow;

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

    final icon = switch (n.type) {
      'like' => Icons.favorite,
      'comment' => Icons.comment,
      'follow' => Icons.person_add,
      _ => Icons.notifications,
    };

    final isPendingFollow = n.type == 'follow' && n.followStatus == 'pending';

    DateTime? created;
    try {
      created = DateTime.parse(n.createdAt).toLocal();
    } catch (_) {}

    final timeText = timeago.format(created ?? DateTime.now(), locale: 'en');

    final ImageProvider imageProvider = (n.senderImage.isNotEmpty)
        ? NetworkImage("https://linktinger.xyz/linktinger-api/${n.senderImage}")
        : const AssetImage("assets/images/user1.jpg");

    void _goToProfile() {
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
        onTap: _goToProfile,
        child: CircleAvatar(radius: 24, backgroundImage: imageProvider),
      ),
      title: GestureDetector(
        onTap: _goToProfile,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
            _goToProfile();
            break;
          default:
            break;
        }
      },
    );
  }
}
