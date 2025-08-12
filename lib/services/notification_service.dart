import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static const String _baseUrl = 'https://linktinger.xyz/linktinger-api';

  static Future<List<NotificationModel>> fetchNotifications() async {
    final userId = await _getUserId();
    if (userId == 0) return [];

    final response = await _post(
      'get_notifications.php',
      body: {'user_id': userId},
    );

    if (response['status'] == 'success' && response['notifications'] is List) {
      return (response['notifications'] as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    }

    return [];
  }

  static Future<Map<String, dynamic>> acceptFollow(int senderId) async {
    final userId = await _getUserId();
    return await _post(
      'accept_follow.php',
      body: {'user_id': userId, 'sender_id': senderId},
    );
  }

  static Future<Map<String, dynamic>> rejectFollow(int senderId) async {
    final userId = await _getUserId();
    return await _post(
      'reject_follow.php',
      body: {'user_id': userId, 'sender_id': senderId},
    );
  }

  static Future<int> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? 0;
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('$_baseUrl/$endpoint');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print("❌ POST $endpoint failed: $e");
      return {
        'status': 'error',
        'message': 'Something went wrong. Please try again later.',
      };
    }
  }
}
