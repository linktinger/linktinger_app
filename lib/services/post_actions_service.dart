import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PostActionsService {
  static const String _baseUrl = 'https://linktinger.xyz/linktinger-api';

  static Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    return (id != null && id > 0) ? id : null;
  }

  static Future<void> _sendNotification({
    required int senderId,
    required int receiverId,
    required int postId,
    required String type,
    required String message,
  }) async {
    final url = Uri.parse('$_baseUrl/create_notification.php');

    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'post_id': postId,
        'type': type,
        'message': message,
      }),
    );
  }

  // 🔄 Toggle Like
  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    final userId = await _getUserId();
    if (userId == null) {
      return {'status': 'error', 'message': 'User ID not found'};
    }

    final Uri url = Uri.parse('$_baseUrl/like_post.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'post_id': postId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic> && data['status'] == 'success') {
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
        } else {
          return {'status': 'error', 'message': 'Invalid response structure'};
        }
      } else {
        return {
          'status': 'error',
          'message': 'HTTP error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> commentPost({
    required int postId,
    required String commentText,
  }) async {
    final userId = await _getUserId();
    if (userId == null) {
      return {'status': 'error', 'message': 'User ID not found'};
    }

    final Uri url = Uri.parse('$_baseUrl/comment_post.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'post_id': postId,
          'comment': commentText,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data is Map<String, dynamic>)
            ? data
            : {'status': 'error', 'message': 'Invalid response format'};
      } else {
        return {
          'status': 'error',
          'message': 'HTTP error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }
}
