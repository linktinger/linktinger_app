import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class PostService {
  static const String _url =
      'https://linktinger.xyz/linktinger-api/create_post.php';

  static Future<Map<String, dynamic>> createPost({
    required File image,
    required String caption,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        return {
          'status': 'error',
          'message': '🔐 The user is not logged in. Please log in first.',
        };
      }

      if (!image.existsSync()) {
        return {
          'status': 'error',
          'message': '❌ The image was not found. Please select a valid image.',
        };
      }

      final mimeType = lookupMimeType(image.path);
      if (mimeType == null || !mimeType.startsWith('image/')) {
        return {
          'status': 'error',
          'message':
              '⚠️ The file type is not supported. Please select an image only.',
        };
      }

      final mimeSplit = mimeType.split('/');
      final request = http.MultipartRequest('POST', Uri.parse(_url))
        ..fields['user_id'] = userId.toString()
        ..fields['caption'] = caption
        ..files.add(
          await http.MultipartFile.fromPath(
            'image',
            image.path,
            contentType: MediaType(mimeSplit[0], mimeSplit[1]),
          ),
        );

      final response = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception(
            '⏰ The time allocated for the order has ended. Check your connection.',
          );
        },
      );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 && responseBody.isNotEmpty) {
        try {
          final data = jsonDecode(responseBody);
          return data;
        } catch (e) {
          print('⚠️ Error while converting the response to JSON: $e');
          return {
            'status': 'error',
            'message': '⚠️ Invalid response from the server.',
          };
        }
      } else {
        return {
          'status': 'error',
          'message':
              '⚠️ An error occurred while connecting to the server ${response.statusCode})',
        };
      }
    } catch (e, stack) {
      print('❌ Exception: $e');
      print('🧵 Stacktrace: $stack');
      return {
        'status': 'error',
        'message': 'An exception occurred while uploading the post: $e',
      };
    }
  }
}
