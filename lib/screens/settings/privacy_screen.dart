import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool isPrivate = false;
  bool showOnline = true;
  bool allowMessages = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPrivacySettings();
  }

  Future<void> loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final url = Uri.parse(
      'https://linktinger.xyz/linktinger-api/get_privacy_settings.php',
    );
    final response = await http.post(url, body: {'user_id': userId.toString()});

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final settings = data['settings'];

      final newPrivate = settings['private_account'] == 1;
      final newOnline = settings['show_online'] == 1;
      final newMessages = settings['allow_messages'] == 1;

      setState(() {
        isPrivate = newPrivate;
        showOnline = newOnline;
        allowMessages = newMessages;
        isLoading = false;
      });

      prefs.setBool('is_private', newPrivate);
      prefs.setBool('show_online', newOnline);
      prefs.setBool('allow_messages', newMessages);
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> updatePrivacySetting(
    String key,
    bool newValue,
    VoidCallback revertSwitch,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final url = Uri.parse(
      'https://linktinger.xyz/linktinger-api/update_privacy_settings.php',
    );
    final response = await http.post(
      url,
      body: {
        'user_id': userId.toString(),
        'setting': key,
        'value': newValue ? '1' : '0',
      },
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      prefs.setBool(
        key == 'private_account'
            ? 'is_private'
            : key == 'show_online'
            ? 'show_online'
            : 'allow_messages',
        newValue,
      );
    } else {
      revertSwitch();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update setting. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final url = Uri.parse(
      'https://linktinger.xyz/linktinger-api/delete_account.php',
    );
    final response = await http.post(url, body: {'user_id': userId.toString()});

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        await prefs.clear();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to delete account'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF6F6F6),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Who can see my content?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: const Text('Private Account'),
                  subtitle: const Text(
                    'Only your approved friends can see your posts',
                  ),
                  value: isPrivate,
                  onChanged: (value) {
                    final oldValue = isPrivate;
                    setState(() => isPrivate = value);
                    updatePrivacySetting('private_account', value, () {
                      setState(() => isPrivate = oldValue);
                    });
                  },
                ),
                const Divider(),
                const Text(
                  'Activity Controls',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: const Text('Show Online Status'),
                  subtitle: const Text('Let others know when you’re online'),
                  value: showOnline,
                  onChanged: (value) {
                    final oldValue = showOnline;
                    setState(() => showOnline = value);
                    updatePrivacySetting('show_online', value, () {
                      setState(() => showOnline = oldValue);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Allow Message Requests'),
                  subtitle: const Text('Receive messages from non-friends'),
                  value: allowMessages,
                  onChanged: (value) {
                    final oldValue = allowMessages;
                    setState(() => allowMessages = value);
                    updatePrivacySetting('allow_messages', value, () {
                      setState(() => allowMessages = oldValue);
                    });
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete My Account',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Account'),
                        content: const Text(
                          'Are you sure you want to delete your account permanently?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await deleteAccount();
                    }
                  },
                ),
              ],
            ),
    );
  }
}
