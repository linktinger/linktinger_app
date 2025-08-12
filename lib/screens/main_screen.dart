import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'home_screen.dart';
import 'profile/my_profile_screen.dart';
import 'search_screen.dart';
import 'create_post_screen.dart';
import 'notifications/notifications_screen.dart';
import '../services/notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? profileImage;
  bool hasUnreadNotifications = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    CreatePostScreen(),
    NotificationsScreen(),
    MyProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    loadUserData();
    checkUnreadNotifications();

    FirebaseMessaging.onMessage.listen((message) {
      checkUnreadNotifications();
    });
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profileImage = prefs.getString('profileImage');
    });
  }

  Future<void> checkUnreadNotifications() async {
    final notifs = await NotificationService.fetchNotifications();
    final unread = notifs.any((n) => !n.isRead);
    if (!mounted) return;
    setState(() {
      hasUnreadNotifications = unread;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 3) {
        hasUnreadNotifications = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF142B63),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavIcon(Icons.home_outlined, 0),
            _buildNavIcon(Icons.search_outlined, 1),
            _buildPostButton(),
            _buildNavIcon(
              Icons.favorite_border,
              3,
              showBadge: hasUnreadNotifications,
            ),
            _buildProfileIcon(4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool showBadge = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _onItemTapped(index),
          child: Icon(
            icon,
            size: 28,
            color: _selectedIndex == index ? Colors.white : Colors.white70,
          ),
        ),
        if (showBadge)
          const Positioned(
            right: -4,
            top: -4,
            child: CircleAvatar(radius: 5, backgroundColor: Colors.red),
          ),
      ],
    );
  }

  Widget _buildPostButton() {
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Icon(Icons.add, color: Color(0xFF142B63), size: 32),
      ),
    );
  }

  Widget _buildProfileIcon(int index) {
    String imageUrl;

    if (profileImage != null && profileImage!.isNotEmpty) {
      imageUrl = profileImage!.startsWith('http')
          ? profileImage!
          : 'https://linktinger.xyz/linktinger-api/$profileImage';
    } else {
      imageUrl = '';
    }

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedIndex == index ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundImage: imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : const AssetImage('assets/images/user1.jpg') as ImageProvider,
        ),
      ),
    );
  }
}
