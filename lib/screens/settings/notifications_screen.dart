import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool pushNotifications = true;
  bool messageNotifications = true;
  bool commentNotifications = true;
  bool followerNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const Text(
            'Notification Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: pushNotifications,
            title: const Text('Enable Push Notifications'),
            onChanged: (value) {
              setState(() => pushNotifications = value);
            },
          ),
          SwitchListTile(
            value: messageNotifications,
            title: const Text('Message Notifications'),
            onChanged: (value) {
              setState(() => messageNotifications = value);
            },
          ),
          SwitchListTile(
            value: commentNotifications,
            title: const Text('Comment Notifications'),
            onChanged: (value) {
              setState(() => commentNotifications = value);
            },
          ),
          SwitchListTile(
            value: followerNotifications,
            title: const Text('New Followers'),
            onChanged: (value) {
              setState(() => followerNotifications = value);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'You can manage what kind of notifications you want to receive. These settings won’t affect system notifications.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
