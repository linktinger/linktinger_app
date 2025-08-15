import 'dart:convert';
import 'dart:async'; // لـ TimeoutException
import 'dart:io'; // لـ SocketException, HttpException
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PostActionsService {
  static const String _baseUrl = 'https://linktinger.xyz/linktinger-api';

  // ===================== Helpers =====================
  static Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    return (id != null && id > 0) ? id : null;
  }

  static Map<String, dynamic> _safeDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'status': 'error', 'message': 'Invalid response structure'};
    } catch (_) {
      return {'status': 'error', 'message': 'Invalid JSON'};
    }
  }

  static Future<void> _sendNotification({
    required int senderId,
    required int receiverId,
    required int postId,
    required String type,
    required String message,
  }) async {
    final url = Uri.parse('$_baseUrl/create_notification.php');
    try {
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sender_id': senderId,
              'receiver_id': receiverId,
              'post_id': postId,
              'type': type,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // نتجاهل فشل الإشعار حتى لا يعطّل التجربة الأساسية
    }
  }

  // ===================== Like =====================
  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    final userId = await _getUserId();
    if (userId == null) {
      return {'status': 'error', 'message': 'User ID not found'};
    }

    final url = Uri.parse('$_baseUrl/like_post.php');

    try {
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': userId, 'post_id': postId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        return {'status': 'error', 'message': 'HTTP error: ${res.statusCode}'};
      }

      final data = _safeDecode(res.body);
      if (data['status'] == 'success') {
        final liked = data['liked'] == true;
        final receiverId = data['post_owner_id'];
        if (liked && receiverId != null && receiverId != userId) {
          await _sendNotification(
            senderId: userId,
            receiverId: receiverId,
            postId: postId,
            type: 'like',
            message: 'like your post ',
          );
        }
        return data;
      }

      return {
        'status': 'error',
        'message': data['message'] ?? 'Invalid response structure',
      };
    } on SocketException catch (e) {
      return {'status': 'error', 'message': 'No internet connection: $e'};
    } on HttpException catch (e) {
      return {'status': 'error', 'message': 'HTTP exception: $e'};
    } on FormatException catch (e) {
      return {'status': 'error', 'message': 'Invalid JSON: $e'};
    } on TimeoutException {
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // ===================== Comment =====================
  static Future<Map<String, dynamic>> commentPost({
    required int postId,
    required String commentText,
  }) async {
    final userId = await _getUserId();
    if (userId == null) {
      return {'status': 'error', 'message': 'User ID not found'};
    }

    final url = Uri.parse('$_baseUrl/comment_post.php');

    try {
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'post_id': postId,
              'comment': commentText,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        return {'status': 'error', 'message': 'HTTP error: ${res.statusCode}'};
      }

      final data = _safeDecode(res.body);
      return data;
    } on TimeoutException {
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // ===================== Share Post to User (shared_post) =====================
  /// يرسل مشاركة منشور عبر الباك-إند المخصّص `share_post_to_user.php`
  /// الذي يملأ أعمدة messages: shared_post_id, shared_post_thumb, shared_post_owner, type='shared_post'
  static Future<Map<String, dynamic>> sharePostToUser({
    required int postId,
    required int targetUserId,
    String? note,
  }) async {
    final senderId = await _getUserId();
    if (senderId == null) {
      return {'status': 'error', 'message': 'User ID not found'};
    }
    if (postId <= 0 || targetUserId <= 0) {
      return {'status': 'error', 'message': 'Invalid parameters'};
    }

    // ✅ endpoint الصحيح حسب ما اتفقنا
    final url = Uri.parse('$_baseUrl/share_post_to_user.php');

    // ✅ مفاتيح مطابقة للباك-إند
    final payload = <String, dynamic>{
      'sender_id': senderId,
      'target_user_id': targetUserId,
      'post_id': postId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    try {
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        return {'status': 'error', 'message': 'HTTP error: ${res.statusCode}'};
      }

      final data = _safeDecode(res.body);

      // نجاح الإدخال في جدول messages بنوع shared_post
      if (data['status'] == 'success') {
        // إشعار اختياري للطرف الآخر
        await _sendNotification(
          senderId: senderId,
          receiverId: targetUserId,
          postId: postId,
          type: 'share_post',
          message: 'shared a post with you',
        );
      }

      return data;
    } on TimeoutException {
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }
}
