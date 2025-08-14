import 'package:flutter/material.dart';
import 'package:linktinger_app/widgets/profile/profile_header.dart';
import 'package:linktinger_app/widgets/profile/profile_stats.dart';
import 'package:linktinger_app/widgets/profile/profile_bio.dart';
import 'package:linktinger_app/widgets/profile/profile_tabs.dart';
import 'package:linktinger_app/services/profile_service.dart';
import 'package:linktinger_app/screens/settings/settings_screen.dart';
import 'package:linktinger_app/screens/profile/digital_card_screen.dart';
import 'package:linktinger_app/screens/projects/projects_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool isLoading = true;
  String? error;

  String username = '';
  String screenName = '';
  String bio = '';
  String specialty = '';
  String profileImage = '';
  String coverImage = '';
  int followers = 0;
  int following = 0;
  bool isVerified = false;

  List<String> all = [];
  List<String> photos = [];
  List<String> videos = [];

  // خرائط لحذف المنشور (url -> postId) آتية مباشرة من ProfileService
  Map<String, int> allUrlToId = {};
  Map<String, int> photosUrlToId = {};
  Map<String, int> videosUrlToId = {};

  // cache-buster مرة واحدة لتفادي إعادة تحميل الصور
  late final int _cacheBuster;

  String formatImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://linktinger.xyz/linktinger-api/$path';
  }

  @override
  void initState() {
    super.initState();
    _cacheBuster = DateTime.now().millisecondsSinceEpoch;
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final result = await ProfileService.fetchProfileData();
      if (!mounted) return;

      if (result['status'] == 'success') {
        final user = (result['user'] ?? {}) as Map;

        // ProfileService يضع isVerified بالفعل؛ احتياطاً نتعامل مع الحالتين
        final dynamic verifiedRaw = user['isVerified'] ?? user['verified'];
        final bool verified =
            (verifiedRaw == true ||
            verifiedRaw == 1 ||
            verifiedRaw == '1' ||
            (verifiedRaw is String && verifiedRaw.toLowerCase() == 'true'));

        // ⚠️ خُذ القوائم والخرائط كما أرجعها ProfileService دون أي تطبيع إضافي
        final posts = (result['posts'] ?? {}) as Map;

        setState(() {
          username = '${user['username'] ?? ''}';
          screenName = '${user['screenName'] ?? ''}';
          bio = '${user['bio'] ?? ''}';
          specialty = '${user['specialty'] ?? ''}';
          profileImage = formatImageUrl('${user['profileImage'] ?? ''}');
          coverImage = formatImageUrl('${user['profileCover'] ?? ''}');
          followers = int.tryParse('${result['followers'] ?? 0}') ?? 0;
          following = int.tryParse('${result['following'] ?? 0}') ?? 0;
          isVerified = verified;

          // هذه القوائم مُطبّعة مسبقًا في ProfileService.normalizeUrlLoose
          all = List<String>.from(posts['all'] ?? const <String>[]);
          photos = List<String>.from(posts['photos'] ?? const <String>[]);
          videos = List<String>.from(posts['videos'] ?? const <String>[]);

          // وهذه الخرائط مفاتيحها تتطابق مع القوائم أعلاه
          allUrlToId = (posts['allMap'] is Map)
              ? Map<String, int>.from(posts['allMap'])
              : {};
          photosUrlToId = (posts['photosMap'] is Map)
              ? Map<String, int>.from(posts['photosMap'])
              : {};
          videosUrlToId = (posts['videosMap'] is Map)
              ? Map<String, int>.from(posts['videosMap'])
              : {};

          isLoading = false;
        });
      } else {
        setState(() {
          error = '${result['message']}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Unexpected error: $e';
        isLoading = false;
      });
    }
  }

  Widget _buildCoverImage() {
    if (coverImage.isNotEmpty) {
      final imageUrl = '$coverImage?t=$_cacheBuster';
      return FadeInImage.assetNetwork(
        placeholder: 'assets/images/logo.png',
        image: imageUrl,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) =>
            Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/images/logo.png', fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            'An error occurred while loading the data:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProjectsScreen()),
          );
        },
        backgroundColor: const Color(0xFF142B63),
        tooltip: 'my projects',
        child: const Icon(Icons.work_outline, color: Colors.white),
      ),
      body: Stack(
        children: [
          SizedBox(
            height: 260,
            width: double.infinity,
            child: _buildCoverImage(),
          ),

          // زر الإعدادات
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.black.withAlpha(153),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            ),
          ),

          // زر البطاقة الرقمية
          Positioned(
            top: 40,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.badge_rounded, color: Colors.white),
                  tooltip: 'Digital Card',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DigitalCardScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // المحتوى السفلي
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.65,
            maxChildSize: 1,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ListView(
                controller: scrollController,
                children: [
                  ProfileHeader(
                    username: username,
                    profileImage: '$profileImage?t=$_cacheBuster',
                    isVerified: isVerified,
                  ),
                  const SizedBox(height: 12),
                  ProfileStats(followers: followers, following: following),
                  const SizedBox(height: 12),
                  ProfileBio(bio: bio),
                  if (specialty.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      specialty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ProfileTabs(
                    all: all,
                    photos: photos,
                    videos: videos,
                    isMyProfile: true,

                    // الخرائط كما هي من الـ Service (تطابق تام مع العناصر)
                    allUrlToId: allUrlToId,
                    photosUrlToId: photosUrlToId,
                    videosUrlToId: videosUrlToId,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
