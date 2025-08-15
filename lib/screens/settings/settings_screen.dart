import 'package:flutter/material.dart';
import 'package:linktinger_app/screens/settings/ads_screen.dart';
import 'package:linktinger_app/screens/settings/help_screen.dart';
import 'package:linktinger_app/screens/settings/notifications_screen.dart';
import '../../widgets/settings/settings_header.dart';
import '../../widgets/settings/settings_list_item.dart';
import 'account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            const SettingsHeader(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  SettingsListItem(
                    icon: Icons.person,
                    title: 'Account',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                    },
                  ),
                  SettingsListItem(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      );
                    },
                  ),

                  // SettingsListItem(
                  //   icon: Icons.notifications_outlined,
                  //   title: 'Notifications',
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => const NotificationsScreen(),
                  //       ),
                  //     );
                  //   },
                  // ),
                  SettingsListItem(
                    icon: Icons.ads_click,
                    title: 'Ads',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdsScreen()),
                      );
                    },
                  ),
                  SettingsListItem(
                    icon: Icons.help_outline,
                    title: 'Help',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  SettingsListItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();

                      navigator.pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Log out',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
