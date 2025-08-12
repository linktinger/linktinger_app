import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static const String baseUrl = "https://linktinger.xyz/linktinger-api";

  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/login.php');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final result = _handleResponse(response);

      if (result['status'] == 'success' && result.containsKey('user')) {
        await _saveUserData(result['user']);

        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getInt('user_id');
        print('✅ user_id saved in SharedPreferences: $savedUserId');
      }

      return result;
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  static Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
    required String specialty, // ← أضفنا هذا البراميتر
  }) async {
    final url = Uri.parse('$baseUrl/register.php');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'email': email.trim(),
              'password': password.trim(),
              'specialty': specialty.trim(), // ← أرسل التخصص مع البيانات
            }),
          )
          .timeout(const Duration(seconds: 10));

      final result = _handleResponse(response);

      if (result['status'] == 'success') {
        if (result.containsKey('user')) {
          await _saveUserData(result['user']);
        } else if (result.containsKey('user_id')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', result['user_id']);
          print('✅ user_id saved in SharedPreferences: ${result['user_id']}');
        }
      }

      return result;
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email) async {
    final url = Uri.parse('$baseUrl/forgot-password.php');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        return {"status": "error", "message": "Unexpected response format"};
      }
    } catch (e) {
      return {
        "status": "error",
        "message": "Invalid server response: ${response.body}",
      };
    }
  }

  static Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('user_id', user['user_id'] ?? 0);
    await prefs.setString('username', user['username'] ?? '');
    await prefs.setString('email', user['email'] ?? '');
    await prefs.setString(
      'profileImage',
      '$baseUrl/${user['profileImage'] ?? ''}',
    );
    await prefs.setString(
      'profileCover',
      '$baseUrl/${user['profileCover'] ?? ''}',
    );
    await prefs.setString('screenName', user['screenName'] ?? '');
    await prefs.setString('bio', user['bio'] ?? '');
    await prefs.setBool('verified', user['verified'] == 1);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    print('🔍 getUserId(): $userId');
    return userId;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_id');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<Map<String, dynamic>> fetchOtherUserProfile(int userId) async {
    final url = Uri.parse('$baseUrl/get_user_profile.php');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final user = data['user'];
          user['profileImage'] = '$baseUrl/${user['profileImage'] ?? ''}';
          user['profileCover'] = '$baseUrl/${user['profileCover'] ?? ''}';

          data['posts']['all'] = List<String>.from(
            data['posts']['all'].map((e) => '$baseUrl/$e'),
          );
          data['posts']['photos'] = List<String>.from(
            data['posts']['photos'].map((e) => '$baseUrl/$e'),
          );
          data['posts']['videos'] = List<String>.from(
            data['posts']['videos'].map((e) => '$baseUrl/$e'),
          );
        }

        return data;
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection failed: $e'};
    }
  }

  static Future<void> saveFcmTokenToServer(int userId) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        await http.post(
          Uri.parse('$baseUrl/save_fcm_token.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'fcm_token': fcmToken}),
        );
        print('✅ FCM token sent to server');
      } else {
        print('⚠️ FCM token is null');
      }
    } catch (e) {
      print('❌ Failed to save FCM token: $e');
    }
  }
}
