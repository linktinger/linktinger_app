import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:linktinger_app/models/notification_model.dart';
import 'package:linktinger_app/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      Fluttertoast.showToast(
        msg: message.notification?.body ?? '📩 New Notification',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
      );

      await _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    final data = await NotificationService.fetchNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = data;
      _isLoading = false;
    });
  }

  Future<void> _handleAccept(int senderId) async {
    final result = await NotificationService.acceptFollow(senderId);
    if (!mounted) return;

    final msg = result['status'] == 'success'
        ? '✅ The request has been accepted.'
        : result['message'] ?? 'An error occurred.';
    _showSnackBar(msg);

    if (result['status'] == 'success') {
      await _fetchNotifications();
    }
  }

  Future<void> _handleReject(int senderId) async {
    final result = await NotificationService.rejectFollow(senderId);
    if (!mounted) return;

    final msg = result['status'] == 'success'
        ? '❌ The request has been rejected.'
        : result['message'] ?? 'Failed to reject.';
    _showSnackBar(msg);

    if (result['status'] == 'success') {
      await _fetchNotifications();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text("There are no notifications currently."))
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return NotificationTile(
                    notification: notif,
                    onAcceptFollow: _handleAccept,
                    onRejectFollow: _handleReject,
                  );
                },
              ),
            ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final Function(int senderId)? onAcceptFollow;
  final Function(int senderId)? onRejectFollow;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onAcceptFollow,
    this.onRejectFollow,
  });

  void _goToProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/profile',
      arguments: {'userId': notification.senderId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (notification.type) {
      'like' => Icons.favorite,
      'comment' => Icons.comment,
      'follow' => Icons.person_add,
      _ => Icons.notifications,
    };

    final isPendingFollow =
        notification.type == 'follow' && notification.followStatus == 'pending';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: () => _goToProfile(context),
        child: CircleAvatar(
          backgroundImage: notification.senderImage.isNotEmpty
              ? NetworkImage(
                  "https://linktinger.xyz/linktinger-api/${notification.senderImage}",
                )
              : const AssetImage("assets/images/user1.jpg") as ImageProvider,
          radius: 24,
        ),
      ),
      title: GestureDetector(
        onTap: () => _goToProfile(context),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: notification.senderUsername,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' '),
              TextSpan(text: notification.message),
            ],
          ),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeago.format(
              DateTime.tryParse(notification.createdAt) ?? DateTime.now(),
              locale: 'ar',
            ),
            style: const TextStyle(fontSize: 12),
          ),
          if (isPendingFollow)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        onAcceptFollow?.call(notification.senderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      'قبول',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        onRejectFollow?.call(notification.senderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'رفض',
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
        final id = notification.postId ?? notification.tweetId;

        switch (notification.type) {
          case 'like':
          case 'comment':
            if (id != null) {
              Navigator.pushNamed(
                context,
                '/post',
                arguments: {'postId': id}, // استخدم postId في كل الحالات
              );
            }
            break;

          case 'follow':
            _goToProfile(context);
            break;
        }
      },
    );
  }
}
