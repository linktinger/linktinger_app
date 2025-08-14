import 'dart:async'; // ✅ هذا هو المطلوب
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// ملاحظة:
/// - اجعل baseUrl يشير إلى جذر الـ API دون الشرطة الختامية.
/// - استخدم overrideBaseUrl في الاستدعاءات لو أردت التغلب على القيمة الافتراضية (للبيئات المختلفة).
class MessageService {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api';
  static const Duration _defaultTimeout = Duration(seconds: 20);

  static String get fcmUrl => '$baseUrl/send_fcm_v1.php';

  /// يبني رابطًا كاملاً لمسار قد يأتي نسبيًا من الـ API
  static String _fullUrl(String path, {String? overrideBaseUrl}) {
    final p = path.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final b = (overrideBaseUrl ?? baseUrl).trim();
    if (b.isEmpty) return p;

    final left = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    final right = p.startsWith('/') ? p.substring(1) : p;
    return '$left/$right';
  }

  /// توحيد رسالة واحدة من شكل الـ API (يدعم الاختلافات + message كـ JSON لـ shared_post)
  static Map<String, dynamic> _normalizeApiMessage(
    Map input, {
    String? overrideBaseUrl,
  }) {
    final msg = Map<String, dynamic>.from(input);

    // النوع
    final type = (msg['type'] ?? 'text').toString().trim();

    // معرفات
    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final sender = _asInt(msg['sender_id']);
    final receiver = _asInt(msg['receiver_id']);
    final seen = _asInt(msg['seen']);
    final createdAt = (msg['created_at'] ?? msg['createdAt'] ?? '').toString();

    // النص الخام (قد يكون JSON عند shared_post)
    final rawMessage = msg['message'];

    // حقول خاصة بالمنشور المشترك
    int? sharedPostId;
    String? sharedPostThumb;
    String? sharedPostOwner;

    if (type == 'shared_post') {
      Map<String, dynamic>? inner;
      try {
        if (rawMessage is Map) {
          inner = Map<String, dynamic>.from(rawMessage);
        } else if (rawMessage is String && rawMessage.trim().isNotEmpty) {
          final decoded = jsonDecode(rawMessage);
          if (decoded is Map) inner = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // تجاهل — سيُلتقط من الجذر
      }

      dynamic pick(List keys) {
        for (final k in keys) {
          if (inner != null &&
              inner[k] != null &&
              inner[k].toString().isNotEmpty) {
            return inner[k];
          }
          if (msg[k] != null && msg[k].toString().isNotEmpty) return msg[k];
        }
        return null;
      }

      sharedPostId = (() {
        final v = pick(['shared_post_id', 'post_id', 'postId']);
        final n = _asInt(v);
        return n > 0 ? n : null;
      })();

      final thumb =
          (pick([
                    'shared_post_thumb',
                    'thumb',
                    'postImage',
                    'post_image',
                    'image',
                    'thumbnail',
                  ]) ??
                  '')
              .toString()
              .trim();
      sharedPostThumb = thumb.isEmpty
          ? null
          : _fullUrl(thumb, overrideBaseUrl: overrideBaseUrl);

      final owner =
          (pick([
                    'shared_post_owner',
                    'owner',
                    'username',
                    'user_name',
                    'author',
                  ]) ??
                  '')
              .toString()
              .trim();
      sharedPostOwner = owner.isEmpty ? null : owner;
    }

    // media_url إن وجد من السيرفر
    final mediaUrlRaw = (msg['media_url'] ?? '').toString().trim();
    final mediaUrl = mediaUrlRaw.isEmpty
        ? ''
        : _fullUrl(mediaUrlRaw, overrideBaseUrl: overrideBaseUrl);

    // النص النهائي (دائمًا String)
    final text = (rawMessage ?? '').toString();

    return {
      'sender_id': sender,
      'receiver_id': receiver,
      'type': type, // text | image | audio | shared_post
      'message': text,
      'seen': seen,
      'created_at': createdAt,

      // لرسائل المشاركة
      'shared_post_id': sharedPostId,
      'shared_post_thumb': sharedPostThumb,
      'shared_post_owner': sharedPostOwner,

      // لرسائل الميديا
      'media_url': mediaUrl,
    };
  }

  /// 📥 Fetch all messages between two users
  /// يتعامل مع الأنواع: text, image, audio, shared_post
  static Future<List<Map<String, dynamic>>> fetchMessages({
    required int senderId,
    required int receiverId,
    String? overrideBaseUrl,
  }) async {
    final url = Uri.parse('${overrideBaseUrl ?? baseUrl}/get_messages.php');

    try {
      final response = await http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sender_id': senderId,
              'receiver_id': receiverId,
            }),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        print("❌ HTTP Error: ${response.statusCode}");
        return [];
      }

      final raw = jsonDecode(response.body);
      if (raw is Map && raw['status'] == 'success' && raw['messages'] is List) {
        final List list = raw['messages'];
        return list
            .whereType<Map>()
            .map<Map<String, dynamic>>(
              (m) => _normalizeApiMessage(m, overrideBaseUrl: overrideBaseUrl),
            )
            .toList();
      } else {
        print("⚠️ API Error: ${raw is Map ? raw['message'] : 'Unknown error'}");
      }
    } on SocketException {
      print("❗ Network unreachable");
    } on FormatException catch (e) {
      print("❗ JSON Format error: $e");
    } on HttpException catch (e) {
      print("❗ HTTP Exception: $e");
    } on TimeoutException {
      print("⏳ Request timed out");
    } catch (e) {
      print("❗ Fetch Exception: $e");
    }

    return [];
  }

  /// 📨 إرسال رسالة نص/عام (type='text' افتراضيًا)
  /// يمكن أيضًا تمرير 'image'، 'audio' إذا كان الباك-إند يسمح.
  static Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String message,
    String type = 'text',
    bool sendPush = true,
    String? overrideBaseUrl,
  }) async {
    final url = Uri.parse('${overrideBaseUrl ?? baseUrl}/send_message.php');

    try {
      final resp = await http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sender_id': senderId,
              'receiver_id': receiverId,
              'message': message,
              'type': type, // text | image | audio | shared_post
            }),
          )
          .timeout(_defaultTimeout);

      if (resp.statusCode != 200) {
        print("❌ HTTP Error: ${resp.statusCode}");
        return false;
      }

      final data = jsonDecode(resp.body);
      if (data is Map && data['status'] == 'success') {
        if (sendPush) {
          await _sendNotification(
            receiverToken: '${data['receiver_fcm'] ?? ''}',
            title: "💬 Message from ${data['sender_username'] ?? 'User'}",
            body: type == 'text' ? message : '[${type}]',
            payload: {
              'currentUserId': '$receiverId',
              'targetUserId': '$senderId',
              'targetUsername': '${data['sender_username'] ?? ''}',
              'profile_image_url': '${data['sender_image'] ?? ''}',
              'message_type': type,
              'message_text': message,
            },
            overrideBaseUrl: overrideBaseUrl,
          );
        }
        return true;
      } else {
        print(
          "⚠️ Sending Failed: ${data is Map ? data['message'] : 'Unknown'}",
        );
      }
    } on TimeoutException {
      print("⏳ sendMessage timed out");
    } catch (e) {
      print("❗ Message Send Exception: $e");
    }

    return false;
  }

  /// 📎 إرسال ميديا (image أو audio)
  static Future<bool> sendMediaMessage({
    required int senderId,
    required int receiverId,
    required File file,
    required String type, // 'image' or 'audio'
    bool sendPush = true,
    String? overrideBaseUrl,
  }) async {
    final url = Uri.parse(
      '${overrideBaseUrl ?? baseUrl}/send_media_message.php',
    );

    final request = http.MultipartRequest('POST', url)
      ..fields['sender_id'] = '$senderId'
      ..fields['receiver_id'] = '$receiverId'
      ..fields['type'] = type; // image | audio;

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
      final streamed = await request.send().timeout(_defaultTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        print("❌ Media HTTP Error: ${response.statusCode}");
        return false;
      }

      final data = jsonDecode(response.body);
      if (data is Map && data['status'] == 'success') {
        if (sendPush) {
          await _sendNotification(
            receiverToken: '${data['receiver_fcm'] ?? ''}',
            title: "📎 Message from ${data['sender_username'] ?? 'User'}",
            body: type == 'image' ? "📷 Image" : "🎵 Audio message",
            payload: {
              'currentUserId': '$receiverId',
              'targetUserId': '$senderId',
              'targetUsername': '${data['sender_username'] ?? ''}',
              'profile_image_url': '${data['sender_image'] ?? ''}',
              'message_type': type,
              'message_text': '[media]',
            },
            overrideBaseUrl: overrideBaseUrl,
          );
        }
        return true;
      } else {
        print("⚠️ Media Error: ${data is Map ? data['message'] : 'Unknown'}");
      }
    } on TimeoutException {
      print("⏳ sendMediaMessage timed out");
    } catch (e) {
      print("❗ Media Upload Exception: $e");
    }

    return false;
  }

  /// 🔗 إرسال رسالة مشاركة منشور (post_id فقط)
  static Future<bool> sendSharedPost({
    required int senderId,
    required int receiverId,
    required int postId,
    bool sendPush = true,
    String? overrideBaseUrl,
  }) async {
    final url = Uri.parse('${overrideBaseUrl ?? baseUrl}/send_message.php');

    try {
      final resp = await http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sender_id': senderId,
              'receiver_id': receiverId,
              'type': 'shared_post',
              'post_id': postId,
              // message: يمكن تركه فارغًا
            }),
          )
          .timeout(_defaultTimeout);

      if (resp.statusCode != 200) {
        print("❌ HTTP Error: ${resp.statusCode}");
        return false;
      }

      final data = jsonDecode(resp.body);
      if (data is Map && data['status'] == 'success') {
        if (sendPush) {
          await _sendNotification(
            receiverToken: '${data['receiver_fcm'] ?? ''}',
            title: "🔗 Post from ${data['sender_username'] ?? 'User'}",
            body: "تمت مشاركة منشور معك",
            payload: {
              'currentUserId': '$receiverId',
              'targetUserId': '$senderId',
              'targetUsername': '${data['sender_username'] ?? ''}',
              'profile_image_url': '${data['sender_image'] ?? ''}',
              'message_type': 'shared_post',
              'post_id': '$postId',
            },
            overrideBaseUrl: overrideBaseUrl,
          );
        }
        return true;
      } else {
        print(
          "⚠️ Shared Post Failed: ${data is Map ? data['message'] : 'Unknown'}",
        );
      }
    } on TimeoutException {
      print("⏳ sendSharedPost timed out");
    } catch (e) {
      print("❗ Shared Post Exception: $e");
    }

    return false;
  }

  /// 🚀 إرسال إشعار FCM عبر سكربت PHP لديك (اختياري)
  static Future<void> _sendNotification({
    required String receiverToken,
    required String title,
    required String body,
    required Map<String, String> payload,
    String? overrideBaseUrl,
  }) async {
    if (receiverToken.isEmpty) return;

    final url = Uri.parse('${overrideBaseUrl ?? baseUrl}/send_fcm_v1.php');

    try {
      final requestBody = {
        'token': receiverToken,
        'title': title,
        'body': body,
        ...payload, // currentUserId, targetUserId, message_type, post_id, ...
      };

      final response = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        print('❌ FCM Failed: ${response.body}');
      }
    } on TimeoutException {
      print("⏳ FCM request timed out");
    } catch (e) {
      print("❗ FCM Exception: $e");
    }
  }
}
