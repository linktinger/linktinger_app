import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback (optional)
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_model.dart';
import '../screens/camera_screen.dart';
import '../screens/messenger/hat_list_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../services/home_service.dart';
import '../services/post_actions_service.dart';
import '../services/permissions.dart'; // ✨ Added: camera/notifications permissions
import '../widgets/home/comment_sheet.dart';
import '../widgets/home/post_card.dart';
import '../widgets/home/post_skeleton.dart';
import '../widgets/home/story_bubble.dart';
import '../widgets/home/story_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;

  List<dynamic> stories = [];
  List<dynamic> posts = [];

  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  // Flag to prevent double-tapping share
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    fetchHomeData();
    startAutoRefresh();

    // Load more when close to bottom
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingMore &&
          hasMore &&
          !isLoading) {
        loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      fetchHomeData();
    });
  }

  // Fetch base data (stories & posts)
  Future<void> fetchHomeData() async {
    setState(() {
      isLoading = true;
      error = null;
      hasMore = true;
    });

    final data = await HomeService.fetchHomeData();
    if (!mounted) return;

    if (data['status'] == 'success') {
      final List<dynamic> fetchedStories = data['stories'] ?? [];

      // My own story
      final myStory = fetchedStories.firstWhere(
        (story) => story['isMe'] == true,
        orElse: () => null,
      );

      // Following stories that actually have items
      final followingStories = fetchedStories.where((story) {
        return story['isMe'] != true && (story['items']?.isNotEmpty ?? false);
      }).toList();

      final displayedStories = <dynamic>[];
      if (myStory != null) displayedStories.add(myStory);
      displayedStories.addAll(followingStories);

      setState(() {
        stories = displayedStories;
        posts = data['posts'] ?? [];
        isLoading = false;
      });
    } else {
      setState(() {
        error = data['message'] ?? 'An unexpected error occurred.';
        isLoading = false;
      });
    }
  }

  // Load more on scroll
  Future<void> loadMorePosts() async {
    if (posts.isEmpty) return;

    final lastPostId = int.tryParse('${posts.last['postId'] ?? 0}') ?? 0;
    isLoadingMore = true;

    final data = await HomeService.fetchHomeData(lastId: lastPostId);
    isLoadingMore = false;

    if (data['status'] == 'success') {
      final List<dynamic> newPosts = data['posts'] ?? [];
      if (newPosts.isEmpty) {
        hasMore = false;
      } else {
        setState(() {
          posts.addAll(newPosts);
        });
      }
    }
  }

  // Open camera to create a new story (asks for permission first)
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

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: error != null
          ? Center(child: Text(error!))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: fetchHomeData,
                child: isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.only(top: 24),
                        itemCount: 4,
                        itemBuilder: (context, index) => const PostSkeleton(),
                      )
                    : ListView(
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

  // Header with camera & chat buttons
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(Icons.camera_alt_rounded, _openStoryCamera),
          const Text(
            "Linktinger",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          _buildCircleButton(Icons.chat_bubble_rounded, _goToMessenger),
        ],
      ),
    );
  }

  // Navigate to messenger
  Future<void> _goToMessenger() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MessagesListScreen(userId: userId)),
    );
  }

  // Circular icon button
  Widget _buildCircleButton(IconData icon, [VoidCallback? onTap]) {
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

  // Stories row
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
          final List<dynamic> rawStories = story['items'] ?? [];
          final bool hasStories = rawStories.isNotEmpty;

          final String? previewImage = hasStories
              ? 'https://linktinger.xyz/linktinger-api/${rawStories[0]['storyImage']}'
              : null;

          return StoryBubble(
            storyImage: previewImage,
            userImage: story['userImage'] ?? '',
            username: story['username'] ?? '',
            isMe: story['isMe'] ?? false,
            isSeen: story['isSeen'] ?? false,
            onTap: () {
              if (story['isMe'] == true) {
                _openStoryCamera();
              } else if (hasStories) {
                final List<StoryModel>
                parsedStories = rawStories.map<StoryModel>((s) {
                  DateTime ts;
                  try {
                    ts = DateTime.parse('${s['createdAt']}').toLocal();
                  } catch (_) {
                    ts = DateTime.now();
                  }
                  return StoryModel(
                    imageUrl:
                        'https://linktinger.xyz/linktinger-api/${s['storyImage']}',
                    timestamp: ts,
                  );
                }).toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(
                      username: story['username'] ?? '',
                      userImage: story['userImage'] ?? '',
                      stories: parsedStories,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  // Posts list
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

        return PostCard(
          postId: postId,
          userId: userId,
          username: post['username'] ?? '',
          userImage: post['userImage'] ?? '',
          postImage: post['postImage'] ?? '',
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
          onShare: () async {
            if (postId <= 0 || _shareBusy) return;

            _shareBusy = true;
            try {
              // Internal share user picker
              final target = await showModalBottomSheet<_UserPickResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _ShareUserPickerSheet(),
              );

              if (target == null) return;

              // Prevent sharing to yourself
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
                HapticFeedback.lightImpact(); // Nice haptic on success
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('share with ${target.username}')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'cant share now')),
                );
              }
            } finally {
              _shareBusy = false;
            }
          },
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
        'https://linktinger.xyz/linktinger-api/get_share_targets.php'
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

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (img.isNotEmpty)
                            ? NetworkImage(
                                'https://linktinger.xyz/linktinger-api/$img',
                              )
                            : null,
                        child: img.isEmpty ? const Icon(Icons.person) : null,
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
