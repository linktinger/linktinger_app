import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class MessageService {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api';
  static const String fcmUrl = '$baseUrl/send_fcm_v1.php';

  // ========= Helpers =========
  static Uri _api(String path) => Uri.parse('$baseUrl/$path');

  static String _fullUrl(String? pathOrUrl) {
    final v = (pathOrUrl ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    final p = v.startsWith('/') ? v.substring(1) : v;
    return '$baseUrl/$p';
  }

  /// 📥 Fetch all messages between two users
  /// يدعم afterId/limit اختياريًا للتحميل التزايدي
  static Future<List<Map<String, dynamic>>> fetchMessages({
    required int senderId,
    required int receiverId,
    int? afterId,
    int limit = 200,
  }) async {
    final url = _api('get_messages.php');

    try {
      final body = <String, dynamic>{
        'sender_id': senderId,
        'receiver_id': receiverId,
        if (afterId != null && afterId > 0) 'after_id': afterId,
        'limit': limit,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success' && data['messages'] != null) {
          final List msgs = data['messages'];
          return msgs.map<Map<String, dynamic>>((m) {
            final type = (m['type'] ?? 'text').toString();
            var message = (m['message'] ?? '').toString();

            // طبع الروابط للوسائط إلى مطلقة
            if (type == 'image' || type == 'audio') {
              message = _fullUrl(message);
            }

            final out = <String, dynamic>{
              'id': m['id'],
              'sender_id': m['sender_id'],
              'receiver_id': m['receiver_id'],
              'message': message,
              'type': type,
              'seen': m['seen'] ?? 0,
              'created_at': m['created_at'] ?? '',
            };

            if (type == 'shared_post') {
              out['shared_post_id'] = m['shared_post_id'];
              out['shared_post_owner'] = m['shared_post_owner'] ?? '';
              out['shared_post_thumb'] = _fullUrl(m['shared_post_thumb']);
            }

            return out;
          }).toList();
        } else {
          print("⚠️ API Error: ${data['message'] ?? 'Unknown error'}");
        }
      } else {
        print("❌ HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❗ Fetch Exception: $e");
    }

    return [];
  }

  /// 📨 Send a text message
  static Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String message,
    String type = 'text',
  }) async {
    final url = _api('send_message.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'message': message,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // إشعار FCM اختياري
          await _sendNotification(
            receiverToken: (data['receiver_fcm'] ?? '').toString(),
            title: "💬 Message from ${data['sender_username'] ?? 'User'}",
            body: message,
            payload: {
              'sender_id': senderId.toString(),
              'sender_name': data['sender_username']?.toString() ?? '',
              'message_text': message,
              'profile_image_url': data['sender_image']?.toString() ?? '',
            },
          );
          return true;
        } else {
          print("⚠️ Sending Failed: ${data['message']}");
        }
      } else {
        print("❌ HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❗ Message Send Exception: $e");
    }

    return false;
  }

  /// 📎 Send a media message (image or audio)
  static Future<bool> sendMediaMessage({
    required int senderId,
    required int receiverId,
    required File file,
    required String type, // 'image' or 'audio'
  }) async {
    final url = _api('send_media_message.php');

    final request = http.MultipartRequest('POST', url)
      ..fields['sender_id'] = senderId.toString()
      ..fields['receiver_id'] = receiverId.toString()
      ..fields['type'] = type;

    final mediaType = type == 'image' ? 'image/jpeg' : 'audio/mpeg';
    final extension = type == 'image' ? 'jpg' : 'mp3';

    final mediaFile = await http.MultipartFile.fromPath(
      'media',
      file.path,
      filename: 'msg.$extension',
      contentType: MediaType.parse(mediaType),
    );

    request.files.add(mediaFile);

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // إشعار FCM اختياري
          await _sendNotification(
            receiverToken: (data['receiver_fcm'] ?? '').toString(),
            title: "📎 Message from ${data['sender_username'] ?? 'User'}",
            body: type == 'image' ? "📷 Image" : "🎵 Audio message",
            payload: {
              'sender_id': senderId.toString(),
              'sender_name': data['sender_username']?.toString() ?? '',
              'message_text': '[media]',
              'profile_image_url': data['sender_image']?.toString() ?? '',
            },
          );
          return true;
        } else {
          print("⚠️ Media Error: ${data['message']}");
        }
      } else {
        print("❌ Media HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❗ Media Upload Exception: $e");
    }

    return false;
  }

  /// 🔗 Send a shared_post message via dedicated backend
  /// يخزّن الرسالة في أعمدة shared_post_* مع type='shared_post'
  static Future<bool> sendSharedPost({
    required int senderId,
    required int receiverId, // يستخدم كـ target_user_id في الباك-إند
    required int postId,
  }) async {
    final url = _api('share_post_to_user.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': senderId,
          'target_user_id': receiverId,
          'post_id': postId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // بإمكانك هنا إرسال FCM إن أردت، أو تركه للباك-إند
          // مثال بسيط (لو كان عندك توكن المستلم):
          // await _sendNotification(...);
          return true;
        } else {
          print("⚠️ SharedPost Error: ${data['message']}");
        }
      } else {
        print("❌ SharedPost HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❗ SharedPost Exception: $e");
    }

    return false;
  }

  // ========= FCM helper =========
  static Future<void> _sendNotification({
    required String receiverToken,
    required String title,
    required String body,
    required Map<String, String> payload,
  }) async {
    if (receiverToken.isEmpty) return;

    final url = _api('send_fcm_v1.php');

    try {
      final requestBody = {
        'token': receiverToken,
        'title': title,
        'body': body,
        ...payload,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        print('❌ FCM Failed: ${response.body}');
      }
    } catch (e) {
      print("❗ FCM Exception: $e");
    }
  }
}
