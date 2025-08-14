import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'home_screen.dart';
import 'profile/my_profile_screen.dart';
import 'search_screen.dart';
import 'create_post_screen.dart';
import 'notifications/notifications_screen.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart' show HapticFeedback;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  String? profileImage;
  bool hasUnreadNotifications = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      HomeScreen(),
      SearchScreen(),
      CreatePostScreen(),
      NotificationsScreen(),
      MyProfileScreen(),
    ];
    _loadUserData();
    _checkUnreadNotifications();

    // تحديث الشارة عند وصول إشعار Foreground
    FirebaseMessaging.onMessage.listen((_) => _checkUnreadNotifications());
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => profileImage = prefs.getString('profileImage'));
  }

  Future<void> _checkUnreadNotifications() async {
    final notifs = await NotificationService.fetchNotifications();
    final unread = notifs.any((n) => !n.isRead);
    if (!mounted) return;
    setState(() => hasUnreadNotifications = unread);
  }

  void _onTap(int newIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      _index = newIndex;
      if (newIndex == 3) hasUnreadNotifications = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // فرّق بين iOS و Android تلقائياً
    return Platform.isIOS ? _buildCupertino(context) : _buildMaterial(context);
  }

  // =========================
  // iOS (Cupertino) تجربة ضبابية + زر وسط
  // =========================
  Widget _buildCupertino(BuildContext context) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.house),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.search),
        label: 'Search',
      ),
      const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.add_circled_solid),
        label: 'Post',
      ),
      BottomNavigationBarItem(
        icon: _badgeWrapper(
          hasUnreadNotifications,
          const Icon(CupertinoIcons.bell),
        ),
        label: 'Alerts',
      ),
      BottomNavigationBarItem(icon: _profileAvatar(size: 22), label: 'Me'),
    ];

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          // الجسم
          SafeArea(
            top: false,
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _screens[_index],
            ),
          ),

          // شريط سفلي بزجاج ضبابي
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoTheme.of(
                      context,
                    ).barBackgroundColor.withOpacity(0.7),
                    border: const Border(
                      top: BorderSide(color: Color(0x1A000000)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: CupertinoTabBar(
                      currentIndex: _index,
                      onTap: (i) {
                        if (i == 2) {
                          _onTap(2);
                          return;
                        }
                        _onTap(i);
                      },
                      height: 56,
                      iconSize: 24,
                      items: items,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Android (Material 3) NavigationBar + FAB مركزي مع Notch
  // =========================
  Widget _buildMaterial(BuildContext context) {
    return Scaffold(
      extendBody: true, // يجعل الشفافية أجمل حول الـ FAB
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _screens[_index],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFab(),
      bottomNavigationBar: _buildMaterialNavBar(context),
    );
  }

  Widget _buildFab() {
    return Tooltip(
      message: 'Create Post',
      child: FloatingActionButton(
        elevation: 4,
        onPressed: () => _onTap(2),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMaterialNavBar(BuildContext context) {
    final navDestinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search),
        label: 'Search',
      ),
      // مكان الـ FAB — نُظهر عنصرًا شفافًا للحفاظ على الفواصل
      const NavigationDestination(icon: SizedBox.shrink(), label: ''),
      NavigationDestination(
        icon: _badgeWrapper(
          hasUnreadNotifications,
          const Icon(Icons.notifications_none),
        ),
        selectedIcon: _badgeWrapper(
          hasUnreadNotifications,
          const Icon(Icons.notifications),
        ),
        label: 'Alerts',
      ),
      NavigationDestination(icon: _profileAvatar(), label: 'Me'),
    ];

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        elevation: 8,
        height: 64,
        indicatorShape: const StadiumBorder(),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      child: NavigationBar(
        // لا حاجة لأي خرائط: إذا كنت على شاشة الإنشاء (_index == 2)
        // فسيكون المؤشّر على الخانة الوسطى (المكان المحجوز لـ FAB) — وهذا مقبول بصريًا.
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // تجاهل الخانة الوسطى؛ الضغط الفعلي للإنشاء يتم عبر الـ FAB
          if (i == 2) return;
          _onTap(i);
        },
        destinations: navDestinations,
      ),
    );
  }

  // =========================
  // Widgets مساعدة
  // =========================
  Widget _badgeWrapper(bool show, Widget child) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileAvatar({double size = 20}) {
    String imageUrl = '';
    if (profileImage != null && profileImage!.isNotEmpty) {
      imageUrl = profileImage!.startsWith('http')
          ? profileImage!
          : 'https://linktinger.xyz/linktinger-api/$profileImage';
    }

    final avatar = CircleAvatar(
      radius: size,
      backgroundImage: imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : const AssetImage('assets/images/user1.jpg') as ImageProvider,
    );

    // إطار تمييز عند الاختيار (أنيق على iOS وAndroid)
    final isSelected = _index == 4;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: avatar,
    );
  }
}
