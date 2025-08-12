import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/project.dart';

class ProjectService {
  static const String baseUrl =
      'https://linktinger.xyz/linktinger-api/projects';

  /// ✅ إنشاء مشروع جديد
  static Future<Map<String, dynamic>> createProject({
    required int userId,
    required String title,
    required String description,
    required String skills,
    required File imageFile,
  }) async {
    try {
      if (!imageFile.existsSync()) {
        return {
          'status': 'error',
          'code': 'FILE_NOT_FOUND',
          'message': 'ملف الصورة غير موجود على الجهاز',
        };
      }

      final uri = Uri.parse('$baseUrl/create_project.php');
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = userId.toString()
        ..fields['title'] = title
        ..fields['description'] = description
        ..fields['skills'] = skills
        ..headers['Accept'] = 'application/json'
        ..files.add(
          await http.MultipartFile.fromPath('cover_image', imageFile.path),
        );

      final response = await http.Response.fromStream(await request.send());
      final data = jsonDecode(response.body);

      return data;
    } catch (e) {
      return {
        'status': 'error',
        'code': 'EXCEPTION',
        'message': 'استثناء: ${e.toString()}',
      };
    }
  }

  /// ✅ جلب جميع المشاريع
  static Future<List<Project>> fetchAllProjects() async {
    try {
      final uri = Uri.parse('$baseUrl/get_projects.php');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['projects'] as List)
              .map((json) => Project.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ خطأ في جلب كل المشاريع: $e');
      return [];
    }
  }

  /// ✅ جلب مشاريع مستخدم محدد
  static Future<List<Project>> fetchUserProjects(int userId) async {
    try {
      final uri = Uri.parse('$baseUrl/get_user_projects.php?user_id=$userId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['projects'] as List)
              .map((json) => Project.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ خطأ في جلب مشاريع المستخدم: $e');
      return [];
    }
  }

  /// ✅ حذف مشروع معين
  static Future<Map<String, dynamic>> deleteProject(int projectId) async {
    try {
      final uri = Uri.parse('$baseUrl/delete_project.php');
      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'project_id': projectId.toString()},
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'status': 'error',
        'code': 'EXCEPTION',
        'message': 'فشل حذف المشروع: ${e.toString()}',
      };
    }
  }

  /// ✅ تعديل مشروع
  static Future<Map<String, dynamic>> updateProject({
    required int projectId,
    required String title,
    required String description,
    required String skills,
    File? newImageFile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/update_project.php');
      final request = http.MultipartRequest('POST', uri)
        ..fields['project_id'] = projectId.toString()
        ..fields['title'] = title
        ..fields['description'] = description
        ..fields['skills'] = skills
        ..headers['Accept'] = 'application/json';

      if (newImageFile != null && newImageFile.existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('cover_image', newImageFile.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      return data;
    } catch (e) {
      return {
        'status': 'error',
        'code': 'EXCEPTION',
        'message': 'فشل تعديل المشروع: ${e.toString()}',
      };
    }
  }
}
