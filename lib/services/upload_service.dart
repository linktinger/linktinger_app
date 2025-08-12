import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:image_picker/image_picker.dart';

class UploadService {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api';

  static Future<String?> uploadUserImage({
    required File imageFile,
    required int userId,
    required String type,
  }) async {
    final uri = Uri.parse('$baseUrl/upload_profile_image.php');

    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = userId.toString()
      ..fields['type'] = type
      ..files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: basename(imageFile.path),
        ),
      );

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();

        final decoded = json.decode(responseData);
        if (decoded['status'] == 'success') {
          return decoded['image_url'];
        } else {
          print('❌ Upload failed: ${decoded['message']}');
          return null;
        }
      } else {
        print('❌ Upload failed with code ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❗ JSON decode error: $e');
      return null;
    }
  }

  static Future<String?> pickAndUploadImage({
    required int userId,
    required String type,
  }) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      return await uploadUserImage(imageFile: file, userId: userId, type: type);
    }

    return null;
  }
}
