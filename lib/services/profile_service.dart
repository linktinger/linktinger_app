import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _base = 'https://linktinger.xyz/linktinger-api';
  static Uri _u(String path) => Uri.parse('$_base/$path');

  // ======= Networking =======
  static final http.Client _client = http.Client();
  static const Duration _rwTimeout = Duration(seconds: 15);

  static Map<String, String> _jsonHeaders({String? token}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // دالة مفقودة - الآن موجودة
  static Future<Map<String, dynamic>> _postJson(
    Uri url,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final resp = await _client
          .post(
            url,
            headers: _jsonHeaders(token: token),
            body: jsonEncode(body),
          )
          .timeout(_rwTimeout);

      final text = resp.body;
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        return {
          'status': 'error',
          'message': 'Invalid JSON response',
          'code': resp.statusCode,
          'raw': text,
        };
      }

      if (resp.statusCode == 200) return parsed;

      return {
        'status': 'error',
        'message': parsed['message'] ?? 'Server error: ${resp.statusCode}',
        'code': resp.statusCode,
      };
    } on SocketException catch (e) {
      return {'status': 'error', 'message': 'No internet connection: $e'};
    } on HttpException catch (e) {
      return {'status': 'error', 'message': 'HTTP error: $e'};
    } on FormatException catch (e) {
      return {'status': 'error', 'message': 'Bad response format: $e'};
    } on TimeoutException {
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      return {'status': 'error', 'message': 'Unexpected error: $e'};
    }
  }

  // ======= Utilities =======
  static Future<(int userId, String? token)> _auth() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('user_id') ?? 0;
    final token = prefs.getString('auth_token');
    return (uid, token);
  }

  static bool _isAbsolute(String? s) =>
      s != null && (s.startsWith('http://') || s.startsWith('https://'));

  static String _normalizePath(String? path) {
    if (path == null || path.isEmpty) return '';
    if (_isAbsolute(path)) return path;
    String p = path.trim();
    p = p.replaceAll(RegExp(r'^[\s\{\(\[]+'), '');
    p = p.replaceAll(RegExp(r'[\s\}\)\]]+$'), '');
    if (p.startsWith('/')) p = p.substring(1);
    return '$_base/$p';
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static int _asInt(dynamic v, [int def = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  static String normalizeUrlLoose(String raw) {
    if (raw.isEmpty) return raw;
    String s = raw;
    try {
      s = Uri.decodeFull(s);
    } catch (_) {}
    s = s.trim();
    final m = RegExp(
      r'(https?://[^\s\}\]]+)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      s = m.group(1)!;
    } else {
      s = _normalizePath(s);
    }
    s = s.replaceAll(RegExp(r'(%7D)+$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[}\s]+$'), '');
    return s;
  }

  static List<String> _asUrlListFlexible(dynamic v) {
    if (v is! List) return const [];
    final out = <String>[];
    for (final item in v) {
      if (item == null) continue;
      if (item is Map) {
        final raw =
            (item['url'] ??
                    item['media'] ??
                    item['image'] ??
                    item['path'] ??
                    item['file'] ??
                    '')
                .toString();
        final url = normalizeUrlLoose(raw);
        if (url.isNotEmpty) out.add(url);
      } else {
        final url = normalizeUrlLoose(item.toString());
        if (url.isNotEmpty) out.add(url);
      }
    }
    return out;
  }

  static List<String> _asStringList(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => normalizeUrlLoose(e?.toString() ?? ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Map<String, int> normalizeKeys(Map<String, int> m) {
    final out = <String, int>{};
    m.forEach((k, v) {
      final nk = normalizeUrlLoose(k);
      if (nk.isNotEmpty && v > 0) out[nk] = v;
    });
    return out;
  }

  static Map<String, int> toMapFromParallel(List urls, List ids) {
    final out = <String, int>{};
    final n = urls.length;
    for (int i = 0; i < n; i++) {
      final u = normalizeUrlLoose('${urls[i]}');
      final id = int.tryParse('${ids[i]}') ?? 0;
      if (u.isNotEmpty && id > 0) out[u] = id;
    }
    return out;
  }

  static Map<String, dynamic> _extractPosts(dynamic rawPosts) {
    final posts = (rawPosts ?? {}) as Map;

    // 1) جهّز القوائم (تدعم عناصر نصوص أو كائنات {id,url})
    final List<String> allUrls = (posts['all'] is List)
        ? _asUrlListFlexible(posts['all'])
        : const [];
    final List<String> photosUrls = (posts['photos'] is List)
        ? _asUrlListFlexible(posts['photos'])
        : const [];
    final List<String> videosUrls = (posts['videos'] is List)
        ? _asUrlListFlexible(posts['videos'])
        : const [];

    // 2) خرائط جاهزة (legacy: مباشرة داخل posts)
    Map<String, int> allMap = (posts['allMap'] is Map)
        ? Map<String, int>.from(posts['allMap'])
        : {};
    Map<String, int> photosMap = (posts['photosMap'] is Map)
        ? Map<String, int>.from(posts['photosMap'])
        : {};
    Map<String, int> videosMap = (posts['videosMap'] is Map)
        ? Map<String, int>.from(posts['videosMap'])
        : {};

    // 3) ✅ الشكل الجديد: الخرائط داخل posts['maps']
    if (posts['maps'] is Map) {
      final maps = Map<String, dynamic>.from(posts['maps'] as Map);
      if (maps['all'] is Map && allMap.isEmpty) {
        allMap = Map<String, int>.from(maps['all'] as Map);
      }
      if (maps['photos'] is Map && photosMap.isEmpty) {
        photosMap = Map<String, int>.from(maps['photos'] as Map);
      }
      if (maps['videos'] is Map && videosMap.isEmpty) {
        videosMap = Map<String, int>.from(maps['videos'] as Map);
      }
      // ملاحظة: maps['global'] متاح لو حبيت تستخدمه لاحقًا
    }

    // 4) بناء خرائط من قوائم مفصّلة لو موجودة (fallback)
    Map<String, int> mapFromDetailed(List list) {
      final out = <String, int>{};
      for (final e in list) {
        if (e is! Map) continue;
        final id = _asInt(e['id'] ?? e['post_id'] ?? e['postId'] ?? 0);
        final urlRaw =
            (e['url'] ??
                    e['media'] ??
                    e['path'] ??
                    e['file'] ??
                    e['image'] ??
                    '')
                .toString();
        final url = normalizeUrlLoose(urlRaw);
        if (id > 0 && url.isNotEmpty) out[url] = id;
      }
      return out;
    }

    if (allMap.isEmpty && posts['allDetailed'] is List) {
      allMap = mapFromDetailed(posts['allDetailed'] as List);
    }
    if (photosMap.isEmpty && posts['photosDetailed'] is List) {
      photosMap = mapFromDetailed(posts['photosDetailed'] as List);
    }
    if (videosMap.isEmpty && posts['videosDetailed'] is List) {
      videosMap = mapFromDetailed(posts['videosDetailed'] as List);
    }

    // 5) fallback إضافي: مصفوفتان متوازيتان urls + ids
    if (allMap.isEmpty && posts['allIds'] is List) {
      allMap = toMapFromParallel(allUrls, posts['allIds'] as List);
    }
    if (photosMap.isEmpty && posts['photosIds'] is List) {
      photosMap = toMapFromParallel(photosUrls, posts['photosIds'] as List);
    }
    if (videosMap.isEmpty && posts['videosIds'] is List) {
      videosMap = toMapFromParallel(videosUrls, posts['videosIds'] as List);
    }

    // 6) تطبيع المفاتيح والقوائم لضمان التطابق 1:1
    allMap = normalizeKeys(allMap);
    photosMap = normalizeKeys(photosMap);
    videosMap = normalizeKeys(videosMap);

    final allN = allUrls.map(normalizeUrlLoose).toList();
    final photosN = photosUrls.map(normalizeUrlLoose).toList();
    final videosN = videosUrls.map(normalizeUrlLoose).toList();

    return {
      'all': allN,
      'photos': photosN,
      'videos': videosN,
      'allMap': allMap,
      'photosMap': photosMap,
      'videosMap': videosMap,
    };
  }

  // ======= Public API =======
  static String formatImageUrl(String? path) => _normalizePath(path);

  static Future<Map<String, dynamic>> fetchProfileData() async {
    final (userId, token) = await _auth();
    final data = await _postJson(_u('get_profile.php'), {
      'user_id': userId,
    }, token: token);

    if (data['status'] != 'success') return data;

    try {
      final user = (data['user'] as Map).cast<String, dynamic>();
      user['profileImage'] = _normalizePath(user['profileImage']);
      user['profileCover'] = _normalizePath(user['profileCover']);
      user['isVerified'] = _asBool(user['verified']);
      data['user'] = user;
      data['posts'] = _extractPosts(data['posts']);
      return data;
    } catch (e) {
      return {'status': 'error', 'message': 'Parsing error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchOtherUserProfile(int userId) async {
    final (currentUserId, token) = await _auth();
    final data = await _postJson(_u('get_user_profile.php'), {
      'user_id': userId,
      'current_user_id': currentUserId,
    }, token: token);

    if (data['status'] != 'success') return data;

    try {
      final user = (data['user'] as Map).cast<String, dynamic>();
      user['profileImage'] = _normalizePath(user['profileImage']);
      user['profileCover'] = _normalizePath(user['profileCover']);
      user['isVerified'] = _asBool(user['verified']);
      data['user'] = user;

      final isPrivate = _asBool(data['is_private']);
      final isFriend = _asBool(data['is_friend']);
      data['isPrivate'] = isPrivate;
      data['isFriend'] = isFriend;

      if (!isPrivate || isFriend || currentUserId == userId) {
        data['posts'] = _extractPosts(data['posts']);
      } else {
        data['posts'] = {
          'all': const <String>[],
          'photos': const <String>[],
          'videos': const <String>[],
          'allMap': const <String, int>{},
          'photosMap': const <String, int>{},
          'videosMap': const <String, int>{},
        };
      }
      return data;
    } catch (e) {
      return {'status': 'error', 'message': 'Parsing error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleFollowUser({
    required int followerId,
    required int followingId,
  }) async {
    final (_, token) = await _auth();
    return _postJson(_u('follow_user.php'), {
      'follower_id': followerId,
      'following_id': followingId,
    }, token: token);
  }

  static const int _maxUploadBytes = 5 * 1024 * 1024; // 5MB

  static Future<Map<String, dynamic>> uploadCoverImage(File imageFile) async {
    try {
      final mimeType = lookupMimeType(imageFile.path);
      final allowedTypes = {'image/jpeg', 'image/png', 'image/webp'};

      if (mimeType == null || !allowedTypes.contains(mimeType)) {
        return {
          'status': 'error',
          'message': '❌ Unsupported image type. Use JPEG/PNG/WEBP.',
        };
      }

      final length = await imageFile.length();
      if (length > _maxUploadBytes) {
        return {
          'status': 'error',
          'message': '❌ Image too large. Max 5MB.',
          'size': length,
        };
      }

      final (userId, token) = await _auth();
      final req = http.MultipartRequest('POST', _u('upload_cover_image.php'))
        ..headers.addAll({
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        })
        ..fields['user_id'] = userId.toString()
        ..files.add(
          await http.MultipartFile.fromPath(
            'cover_image',
            imageFile.path,
            contentType: MediaType.parse(mimeType!),
          ),
        );

      final resp = await req.send().timeout(_rwTimeout);
      final body = await resp.stream.bytesToString();

      Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'status': 'error',
          'message': 'Invalid JSON response',
          'code': resp.statusCode,
          'raw': body,
        };
      }

      if (resp.statusCode != 200) {
        return {
          'status': 'error',
          'message': data['message'] ?? '❌ Server error: ${resp.statusCode}',
          'code': resp.statusCode,
        };
      }

      if (data['status'] == 'success') {
        final path = data['coverImagePath']?.toString();
        data['coverImagePath'] = _normalizePath(path);
      }
      return data;
    } on TimeoutException {
      return {'status': 'error', 'message': 'Upload timed out'};
    } catch (e) {
      return {'status': 'error', 'message': '❌ Upload failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> deletePost(int postId) async {
    final (userId, token) = await _auth();
    return _postJson(_u('delete_post.php'), {
      'post_id': postId,
      'user_id': userId,
    }, token: token);
  }
}
