import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show ScrollDirection; // لقراءة حالة السحب (idle)
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_model.dart';
import '../screens/camera_screen.dart';
import '../screens/messenger/hat_list_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../services/home_service.dart';
import '../services/post_actions_service.dart';
import '../services/permissions.dart';
import '../widgets/home/comment_sheet.dart';
import '../widgets/home/post_card.dart';
import '../widgets/home/post_skeleton.dart';
import '../widgets/home/story_bubble.dart';
import '../widgets/home/story_viewer_screen.dart';

// ✅ فلاغ تشغيل/إيقاف ميزة المشاركة (مغلق للمراجعة)
const bool kShareEnabled = false;
// قاعدة الروابط
const String kBaseUrl = 'https://linktinger.xyz/linktinger-api/';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;

  // بدلاً من dynamic نحافظ على خرائط مضبوطة
  List<Map<String, dynamic>> stories = const [];
  List<Map<String, dynamic>> posts = const [];

  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  // لمنع النقر المزدوج
  bool _shareBusy = false;
  bool _pushingStory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchHomeData();
    _startAutoRefresh();

    // تحميل المزيد عند الاقتراب من الأسفل
    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 100 &&
          !isLoadingMore &&
          hasMore &&
          !isLoading) {
        loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // إدارة دورة حياة التطبيق: أوقف/استأنف التحديث الدوري
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_pushingStory) _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  /* =========================
   * Helpers
   * ========================= */

  // محوّل URL آمن باستخدام Uri.resolve
  String absUrl(String path) {
    final p = (path).trim();
    if (p.isEmpty || p.startsWith('http')) return p;
    final base = Uri.parse(kBaseUrl);
    final rel = p.startsWith('/') ? p.substring(1) : p;
    return base.resolve(rel).toString();
  }

  // توحيد القصص (Normalize) قبل المقارنة/العرض
  List<Map<String, dynamic>> _normalizeStories(List input) {
    final raw = input.map<Map<String, dynamic>>((e) {
      return Map<String, dynamic>.from(e as Map);
    }).toList();

    // قصتي (إن وُجدت)
    Map<String, dynamic>? myStory = raw
        .cast<Map<String, dynamic>?>()
        .firstWhere((s) => (s?['isMe'] == true), orElse: () => null);

    // قصص المتابعين التي تحتوي عناصر
    final following = raw.where((s) {
      final items = s['items'];
      return s['isMe'] != true && (items is List && items.isNotEmpty);
    }).toList();

    final out = <Map<String, dynamic>>[];
    if (myStory != null) out.add(myStory);
    out.addAll(following);
    return out;
  }

  // توحيد المنشورات
  List<Map<String, dynamic>> _normalizePosts(List input) {
    return input.map<Map<String, dynamic>>((p) {
      return Map<String, dynamic>.from(p as Map);
    }).toList();
  }

  // تحديث دوري ذكي: لا يحدث أثناء السحب/الخلفية/عرض الستوري
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;

      // ❗ لا تحدّث أثناء عرض الستوري لتجنّب أي وميض أو فريم أسود
      if (_pushingStory) return;

      // لا تحدّث أثناء سحب المستخدم (يمنع ومضات الصور)
      if (_scrollController.hasClients &&
          _scrollController.position.userScrollDirection !=
              ScrollDirection.idle) {
        return;
      }
      fetchHomeData();
    });
  }

  /* =========================
   * Networking
   * ========================= */

  Future<void> fetchHomeData() async {
    setState(() {
      isLoading = true;
      error = null;
      hasMore = true;
    });

    final data = await HomeService.fetchHomeData();
    if (!mounted) return;

    if (data['status'] == 'success') {
      final newStories = _normalizeStories(data['stories'] ?? const []);
      final newPosts = _normalizePosts(data['posts'] ?? const []);

      // لا تعمل setState إن لم تتغيّر البيانات
      final storiesChanged = jsonEncode(newStories) != jsonEncode(stories);
      final postsChanged = jsonEncode(newPosts) != jsonEncode(posts);

      if (storiesChanged || postsChanged) {
        setState(() {
          stories = newStories;
          posts = newPosts;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } else {
      setState(() {
        error = data['message'] ?? 'An unexpected error occurred.';
        isLoading = false;
      });
    }
  }

  Future<void> loadMorePosts() async {
    if (posts.isEmpty) return;

    final lastPostId = int.tryParse('${posts.last['postId'] ?? 0}') ?? 0;
    isLoadingMore = true;

    final data = await HomeService.fetchHomeData(lastId: lastPostId);
    isLoadingMore = false;

    if (!mounted) return;

    if (data['status'] == 'success') {
      final List newPostsRaw = data['posts'] ?? [];
      if (newPostsRaw.isEmpty) {
        hasMore = false;
      } else {
        setState(() {
          posts.addAll(_normalizePosts(newPostsRaw));
        });
      }
    }
  }

  /* =========================
   * Actions
   * ========================= */

  Future<void> _openStoryCamera() async {
    final granted = await ensureCamera(context);
    if (!mounted) return;

    if (granted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to capture a story'),
        ),
      );
    }
  }

  Future<void> _goToMessenger() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MessagesListScreen(userId: userId)),
    );
  }

  Future<void> _openStoryViewer({
    required List<StoryModel> items,
    required String username,
    required String userImage,
  }) async {
    if (_pushingStory) return;
    _pushingStory = true;

    // أوقف التحديث الدوري أثناء عرض الستوري
    _refreshTimer?.cancel();

    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false, // ← مسار شفاف
          barrierColor: Colors.black, // خلفية سوداء شفافة
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (_, __, ___) => StoryViewerScreen(
            username: username,
            userImage: userImage,
            stories: items,
          ),
        ),
      );
    } finally {
      _pushingStory = false;
      if (mounted) _startAutoRefresh(); // استأنف التحديث الدوري بعد الرجوع
    }
  }

  /* =========================
   * UI
   * ========================= */

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 42, color: Colors.grey),
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: fetchHomeData,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          key: const PageStorageKey('home-refresh'),
          onRefresh: () async {
            await fetchHomeData();
            if (mounted) HapticFeedback.selectionClick();
          },
          child: isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.only(top: 24),
                  itemCount: 4,
                  itemBuilder: (context, index) => const PostSkeleton(),
                )
              : ListView(
                  key: const PageStorageKey('home-list'),
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    _buildStoriesSection(),
                    const SizedBox(height: 16),
                    _buildPostsSection(),
                    if (isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.camera_alt_rounded, _openStoryCamera),
          const Text(
            "Linktinger",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          _circleButton(Icons.chat_bubble_rounded, _goToMessenger),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, [VoidCallback? onTap]) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF142B63),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildStoriesSection() {
    if (stories.isEmpty) return const SizedBox();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          final List items = story['items'] ?? const [];
          final bool hasStories = items.isNotEmpty;

          final String? previewImage = hasStories
              ? absUrl('${items.first['storyImage']}')
              : null;

          final userImage = absUrl('${story['userImage'] ?? ''}');
          final username = '${story['username'] ?? ''}';
          final isMe = story['isMe'] == true;
          final isSeen = story['isSeen'] == true;

          // مفتاح ثابت يمنع تبديل العناصر (يقلّل الوميض)
          final itemKey = ValueKey('story-${story['userId'] ?? username}');

          return KeyedSubtree(
            key: itemKey,
            child: StoryBubble(
              storyImage: previewImage,
              userImage: userImage,
              username: username,
              isMe: isMe,
              isSeen: isSeen,
              onTap: () async {
                if (hasStories) {
                  // تحويل لعناصر StoryModel (صور فقط)
                  final parsed = items.map<StoryModel>((s) {
                    DateTime ts;
                    try {
                      ts = DateTime.parse('${s['createdAt']}').toLocal();
                    } catch (_) {
                      ts = DateTime.now();
                    }
                    return StoryModel(
                      imageUrl: absUrl('${s['storyImage']}'),
                      timestamp: ts,
                    );
                  }).toList();

                  await _openStoryViewer(
                    items: parsed,
                    username: username,
                    userImage: userImage,
                  );
                } else if (isMe) {
                  // قصتي بدون عناصر: افتح الكاميرا
                  _openStoryCamera();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsSection() {
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'There are no posts currently 🥲',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postId = int.tryParse('${post['postId'] ?? 0}') ?? 0;
        final userId = int.tryParse('${post['user_id'] ?? 0}') ?? 0;

        return KeyedSubtree(
          key: ValueKey('post-$postId'),
          child: PostCard(
            postId: postId,
            userId: userId,
            username: post['username'] ?? '',
            userImage: absUrl('${post['userImage'] ?? ''}'),
            postImage: absUrl('${post['postImage'] ?? ''}'),
            caption: post['caption'] ?? '',
            handle: post['handle'] ?? '',
            likes: post['likes'] ?? 0,
            comments: post['comments'] ?? 0,
            isLiked: post['isLiked'] ?? false,

            onUserTap: () {
              if (userId > 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: userId),
                  ),
                );
              }
            },

            onLike: () async {
              if (postId <= 0) return;
              final result = await PostActionsService.toggleLike(postId);
              if (!mounted) return;

              if (result['status'] == 'success') {
                setState(() {
                  final isLiked = post['isLiked'] ?? false;
                  post['isLiked'] = !isLiked;
                  post['likes'] = isLiked
                      ? (post['likes'] ?? 1) - 1
                      : (post['likes'] ?? 0) + 1;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Failed to impress'),
                  ),
                );
              }
            },

            onComment: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: CommentSheet(postId: postId),
                ),
              );
            },

            // ⛔ زر المشاركة مخفي مؤقتًا عند kShareEnabled=false
            onShare: kShareEnabled
                ? () async {
                    if (postId <= 0 || _shareBusy) return;
                    _shareBusy = true;
                    try {
                      final target =
                          await showModalBottomSheet<_UserPickResult>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const _ShareUserPickerSheet(),
                          );
                      if (target == null) return;

                      final prefs = await SharedPreferences.getInstance();
                      final myId = prefs.getInt('user_id') ?? 0;
                      if (target.userId == myId) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('you cant share with your self'),
                          ),
                        );
                        return;
                      }

                      final res = await PostActionsService.sharePostToUser(
                        postId: postId,
                        targetUserId: target.userId,
                      );

                      if (!mounted) return;

                      if (res['status'] == 'success') {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('share with ${target.username}'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'cant share now'),
                          ),
                        );
                      }
                    } finally {
                      _shareBusy = false;
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}

/* =========================
 * Share user picker
 * ========================= */

class _UserPickResult {
  final int userId;
  final String username;
  final String profileImage;
  const _UserPickResult({
    required this.userId,
    required this.username,
    required this.profileImage,
  });
}

class _ShareUserPickerSheet extends StatefulWidget {
  const _ShareUserPickerSheet();

  @override
  State<_ShareUserPickerSheet> createState() => _ShareUserPickerSheetState();
}

class _ShareUserPickerSheetState extends State<_ShareUserPickerSheet> {
  String _query = '';
  bool _loading = true;
  List<Map<String, dynamic>> _people = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getInt('user_id') ?? 0;

      if (myId <= 0) {
        _people = [];
        return;
      }

      final uri = Uri.parse(
        '${kBaseUrl}get_share_targets.php'
        '?user_id=$myId&q=${Uri.encodeQueryComponent(_query)}&limit=50',
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['status'] == 'success') {
          final List list = decoded['people'] ?? [];
          _people = list.map<Map<String, dynamic>>((p) {
            return {
              'user_id': p['user_id'],
              'username': p['username'] ?? '',
              'profileImage': p['profileImage'] ?? '',
            };
          }).toList();
        } else {
          _people = [];
        }
      } else {
        _people = [];
      }
    } catch (_) {
      _people = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadPeople();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _people.where((p) {
      if (_query.trim().isEmpty) return true;
      return (p['username'] ?? '').toString().toLowerCase().contains(
        _query.toLowerCase(),
      );
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'share with ...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final uid = int.tryParse('${p['user_id'] ?? 0}') ?? 0;
                    final name = '${p['username'] ?? ''}';
                    final img = '${p['profileImage'] ?? ''}';
                    final imgUrl = img.isEmpty ? '' : '$kBaseUrl$img';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (imgUrl.isNotEmpty)
                            ? NetworkImage(imgUrl)
                            : null,
                        child: imgUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text(name),
                      onTap: () {
                        Navigator.pop(
                          context,
                          _UserPickResult(
                            userId: uid,
                            username: name,
                            profileImage: img,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
