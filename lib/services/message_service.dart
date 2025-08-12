import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class MessageService {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api';
  static const String fcmUrl = '$baseUrl/send_fcm_v1.php';

  /// 📥 Fetch all messages between two users
  static Future<List<Map<String, dynamic>>> fetchMessages({
    required int senderId,
    required int receiverId,
  }) async {
    final url = Uri.parse('$baseUrl/get_messages.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sender_id': senderId, 'receiver_id': receiverId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success' && data['messages'] != null) {
          return List<Map<String, dynamic>>.from(
            data['messages'].map(
              (msg) => {
                'sender_id': msg['sender_id'],
                'receiver_id': msg['receiver_id'],
                'message': msg['message'] ?? '',
                'type': msg['type'] ?? 'text',
                'seen': msg['seen'] ?? 0,
                'created_at': msg['created_at'] ?? '',
              },
            ),
          );
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
    final url = Uri.parse('$baseUrl/send_message.php');

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
          await _sendNotification(
            receiverToken: data['receiver_fcm'],
            title: "💬 Message from ${data['sender_username'] ?? 'User'}",
            body: message,
            payload: {
              'sender_id': senderId.toString(),
              'sender_name': data['sender_username'] ?? '',
              'message_text': message,
              'profile_image_url': data['sender_image'] ?? '',
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
    final url = Uri.parse('$baseUrl/send_media_message.php');

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
          await _sendNotification(
            receiverToken: data['receiver_fcm'],
            title: "📎 Message from ${data['sender_username'] ?? 'User'}",
            body: type == 'image' ? "📷 Image" : "🎵 Audio message",
            payload: {
              'sender_id': senderId.toString(),
              'sender_name': data['sender_username'] ?? '',
              'message_text': '[media]',
              'profile_image_url': data['sender_image'] ?? '',
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

  static Future<void> _sendNotification({
    required String receiverToken,
    required String title,
    required String body,
    required Map<String, String> payload,
  }) async {
    final url = Uri.parse(fcmUrl);

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
