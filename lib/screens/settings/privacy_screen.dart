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
  // مفاتيح SharedPreferences
  static const _kPrefPrivate = 'is_private';
  static const _kPrefOnline = 'show_online';
  static const _kPrefMsgs = 'allow_messages';

  // قاعدة الـ API
  static const String _base = 'https://linktinger.xyz/linktinger-api/';

  bool isPrivate = false;
  bool showOnline = true;
  bool allowMessages = true;

  bool isLoading = true;
  // تتبع الطلبات الجارية لتعطيل السويتش
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _hydrateFromPrefsThenFetch();
  }

  // 1) اقرأ القيم من prefs وأظهرها فوراً
  // 2) اجلب من الخادم
  // 3) لو عندنا قيم محلية سابقة نُفضّلها وندفعها للخادم؛
  //    لو ما عندنا محليًا بعد، نأخذ قيمة الخادم ونحفظها محليًا.
  Future<void> _hydrateFromPrefsThenFetch() async {
    final prefs = await SharedPreferences.getInstance();

    final hasLocalPrivate = prefs.containsKey(_kPrefPrivate);
    final hasLocalOnline = prefs.containsKey(_kPrefOnline);
    final hasLocalMessages = prefs.containsKey(_kPrefMsgs);

    // اعرض القيم المحلية فورًا
    setState(() {
      isPrivate = prefs.getBool(_kPrefPrivate) ?? false;
      showOnline = prefs.getBool(_kPrefOnline) ?? true;
      allowMessages = prefs.getBool(_kPrefMsgs) ?? true;
      isLoading = false;
    });

    // اجلب من الخادم وصالح القيم
    await _loadPrivacyFromServer(
      hasLocalPrivate: hasLocalPrivate,
      hasLocalOnline: hasLocalOnline,
      hasLocalMessages: hasLocalMessages,
    );
  }

  Future<void> _loadPrivacyFromServer({
    required bool hasLocalPrivate,
    required bool hasLocalOnline,
    required bool hasLocalMessages,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      final url = Uri.parse('${_base}get_privacy_settings.php');
      final response = await http
          .post(url, body: {'user_id': userId.toString()})
          .timeout(const Duration(seconds: 12));

      if (!mounted || response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final settings = data['settings'] ?? {};

      final serverPrivate =
          (settings['private_account'] == 1 ||
          settings['private_account'] == true);
      final serverOnline =
          (settings['show_online'] == 1 || settings['show_online'] == true);
      final serverMessages =
          (settings['allow_messages'] == 1 ||
          settings['allow_messages'] == true);

      // القيم المعروضة حاليًا (المحلية)
      final localPrivate = isPrivate;
      final localOnline = showOnline;
      final localMessages = allowMessages;

      // Private
      if (!hasLocalPrivate) {
        await prefs.setBool(_kPrefPrivate, serverPrivate);
        if (mounted) setState(() => isPrivate = serverPrivate);
      } else if (serverPrivate != localPrivate) {
        _silentPushToServer('private_account', localPrivate);
      }

      // Online
      if (!hasLocalOnline) {
        await prefs.setBool(_kPrefOnline, serverOnline);
        if (mounted) setState(() => showOnline = serverOnline);
      } else if (serverOnline != localOnline) {
        _silentPushToServer('show_online', localOnline);
      }

      // Messages
      if (!hasLocalMessages) {
        await prefs.setBool(_kPrefMsgs, serverMessages);
        if (mounted) setState(() => allowMessages = serverMessages);
      } else if (serverMessages != localMessages) {
        _silentPushToServer('allow_messages', localMessages);
      }
    } catch (_) {
      // إبقَ على القيم المحلية عند فشل الشبكة
    }
  }

  Future<void> _silentPushToServer(String serverKey, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      final url = Uri.parse('${_base}update_privacy_settings.php');
      await http
          .post(
            url,
            body: {
              'user_id': userId.toString(),
              'setting': serverKey,
              'value': value ? '1' : '0',
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // نحاول لاحقًا؛ الواجهة تبقى على المحلي
    }
  }

  Future<void> _updatePrivacySetting({
    required String
    serverKey, // أسماء API: private_account | show_online | allow_messages
    required String prefKey, // مفاتيح SharedPreferences أعلاه
    required bool newValue,
    required void Function(bool v) applyToState,
  }) async {
    // تعطيل أثناء الإرسال
    setState(() => _pending.add(serverKey));

    // تحديث متفائل + حفظ محلي فوري (سيبقى بعد الإغلاق)
    applyToState(newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, newValue);

    try {
      final userId = prefs.getInt('user_id') ?? 0;
      final url = Uri.parse('${_base}update_privacy_settings.php');
      final resp = await http
          .post(
            url,
            body: {
              'user_id': userId.toString(),
              'setting': serverKey,
              'value': newValue ? '1' : '0',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync with server. Saved locally.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet. Change saved locally, will sync later.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(serverKey));
    }
  }

  bool _disabled(String serverKey) => _pending.contains(serverKey);

  Future<void> _deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    try {
      final url = Uri.parse('${_base}delete_account.php');
      final response = await http
          .post(url, body: {'user_id': userId.toString()})
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          await prefs.clear();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
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
                Opacity(
                  opacity: _disabled('private_account') ? 0.6 : 1,
                  child: SwitchListTile(
                    title: const Text('Private Account'),
                    subtitle: const Text(
                      'Only your approved friends can see your posts',
                    ),
                    value: isPrivate,
                    onChanged: _disabled('private_account')
                        ? null
                        : (value) {
                            _updatePrivacySetting(
                              serverKey: 'private_account',
                              prefKey: _kPrefPrivate,
                              newValue: value,
                              applyToState: (v) =>
                                  setState(() => isPrivate = v),
                            );
                          },
                  ),
                ),
                const Divider(),
                const Text(
                  'Activity Controls',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Opacity(
                  opacity: _disabled('show_online') ? 0.6 : 1,
                  child: SwitchListTile(
                    title: const Text('Show Online Status'),
                    subtitle: const Text('Let others know when you’re online'),
                    value: showOnline,
                    onChanged: _disabled('show_online')
                        ? null
                        : (value) {
                            _updatePrivacySetting(
                              serverKey: 'show_online',
                              prefKey: _kPrefOnline,
                              newValue: value,
                              applyToState: (v) =>
                                  setState(() => showOnline = v),
                            );
                          },
                  ),
                ),
                Opacity(
                  opacity: _disabled('allow_messages') ? 0.6 : 1,
                  child: SwitchListTile(
                    title: const Text('Allow Message Requests'),
                    subtitle: const Text('Receive messages from non-friends'),
                    value: allowMessages,
                    onChanged: _disabled('allow_messages')
                        ? null
                        : (value) {
                            _updatePrivacySetting(
                              serverKey: 'allow_messages',
                              prefKey: _kPrefMsgs,
                              newValue: value,
                              applyToState: (v) =>
                                  setState(() => allowMessages = v),
                            );
                          },
                  ),
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
                      await _deleteAccount();
                    }
                  },
                ),
              ],
            ),
    );
  }
}
