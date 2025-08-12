import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api';

  static String formatImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$baseUrl/$path';
  }

  static Future<Map<String, dynamic>> fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    final url = Uri.parse('$baseUrl/get_profile.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final user = data['user'];
          user['profileImage'] = formatImageUrl(user['profileImage']);
          user['profileCover'] = formatImageUrl(user['profileCover']);
          user['isVerified'] = user['verified'] == 1;

          data['posts']['all'] = List<String>.from(
            (data['posts']['all'] ?? []).map((e) => formatImageUrl(e)),
          );
          data['posts']['photos'] = List<String>.from(
            (data['posts']['photos'] ?? []).map((e) => formatImageUrl(e)),
          );
          data['posts']['videos'] = List<String>.from(
            (data['posts']['videos'] ?? []).map((e) => formatImageUrl(e)),
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

  static Future<Map<String, dynamic>> fetchOtherUserProfile(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getInt('user_id') ?? 0;
    final url = Uri.parse('$baseUrl/get_user_profile.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'current_user_id': currentUserId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final user = data['user'];
          user['profileImage'] = formatImageUrl(user['profileImage']);
          user['profileCover'] = formatImageUrl(user['profileCover']);
          user['isVerified'] = user['verified'] == 1;

          final isPrivate = data['is_private'] == 1;
          final isFriend = data['is_friend'] == true;

          if (!isPrivate || isFriend || currentUserId == userId) {
            data['posts']['all'] = List<String>.from(
              (data['posts']['all'] ?? []).map((e) => formatImageUrl(e)),
            );
            data['posts']['photos'] = List<String>.from(
              (data['posts']['photos'] ?? []).map((e) => formatImageUrl(e)),
            );
            data['posts']['videos'] = List<String>.from(
              (data['posts']['videos'] ?? []).map((e) => formatImageUrl(e)),
            );
          }

          data['isPrivate'] = isPrivate;
          data['isFriend'] = isFriend;

          return data;
        } else {
          return {
            'status': 'error',
            'message': data['message'] ?? 'Failed to load profile',
          };
        }
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

  static Future<Map<String, dynamic>> toggleFollowUser({
    required int followerId,
    required int followingId,
  }) async {
    final url = Uri.parse('$baseUrl/follow_user.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'follower_id': followerId,
          'following_id': followingId,
        }),
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
      return {'status': 'error', 'message': 'Connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadCoverImage(File imageFile) async {
    final url = Uri.parse('$baseUrl/upload_cover_image.php');

    try {
      final mimeType = lookupMimeType(imageFile.path);
      final allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];

      if (mimeType == null || !allowedTypes.contains(mimeType)) {
        return {
          'status': 'error',
          'message':
              '❌ The image type is not supported. Use JPEG or PNG or WEBP.',
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      final request = http.MultipartRequest('POST', url)
        ..fields['user_id'] = userId.toString()
        ..files.add(
          await http.MultipartFile.fromPath(
            'cover_image',
            imageFile.path,
            contentType: MediaType.parse(mimeType),
          ),
        );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(respStr);

        if (data['status'] == 'success') {
          final path = data['coverImagePath'];
          final fullUrl = formatImageUrl(path);
          data['coverImagePath'] = fullUrl;
        }

        return data;
      } else {
        return {
          'status': 'error',
          'message': '❌ Server error: ${response.statusCode}',
          'response': respStr,
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': '❌ Upload failed: $e',
        'path': imageFile.path,
      };
    }
  }

  static Future<Map<String, dynamic>> deletePost(int postId) async {
    final url = Uri.parse('$baseUrl/delete_post.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'post_id': postId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
}
