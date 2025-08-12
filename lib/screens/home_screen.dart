import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_model.dart';
import '../screens/camera_screen.dart';
import '../screens/messenger/hat_list_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../services/home_service.dart';
import '../services/post_actions_service.dart';
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

  @override
  void initState() {
    super.initState();
    fetchHomeData();
    startAutoRefresh();

    // استماع للتمرير لتحميل المزيد عند الاقتراب من نهاية القائمة
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

  // جلب البيانات الأساسية (القصص والمنشورات)
  Future<void> fetchHomeData() async {
    setState(() {
      isLoading = true;
      error = null;
      hasMore = true;
    });

    final data = await HomeService.fetchHomeData();

    if (!mounted) return;

    if (data['status'] == 'success') {
      List<dynamic> fetchedStories = data['stories'];

      // استخراج قصة المستخدم نفسه
      final myStory = fetchedStories.firstWhere(
        (story) => story['isMe'] == true,
        orElse: () => null,
      );

      // استخراج قصص المتابعين التي تحتوي على قصص فعليًا (items غير فارغ)
      final followingStories = fetchedStories.where((story) {
        return story['isMe'] != true && (story['items']?.isNotEmpty ?? false);
      }).toList();

      final displayedStories = <dynamic>[];
      if (myStory != null) displayedStories.add(myStory);
      displayedStories.addAll(followingStories);

      setState(() {
        stories = displayedStories;
        posts = data['posts'];
        isLoading = false;
      });
    } else {
      setState(() {
        error = data['message'] ?? 'An unexpected error occurred.';
        isLoading = false;
      });
    }
  }

  // تحميل المزيد من المنشورات عند التمرير
  Future<void> loadMorePosts() async {
    if (posts.isEmpty) return;

    final lastPostId = int.tryParse(posts.last['postId'].toString()) ?? 0;
    isLoadingMore = true;

    final data = await HomeService.fetchHomeData(lastId: lastPostId);
    isLoadingMore = false;

    if (data['status'] == 'success') {
      final List<dynamic> newPosts = data['posts'];

      if (newPosts.isEmpty) {
        hasMore = false;
      } else {
        setState(() {
          posts.addAll(newPosts);
        });
      }
    }
  }

  // فتح كاميرا نشر ستوري جديد
  void _openStoryCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  // بناء واجهة التطبيق
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

  // شريط العنوان مع أزرار الكاميرا والدردشة
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

  // الانتقال إلى صفحة المراسلة
  Future<void> _goToMessenger() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MessagesListScreen(userId: userId)),
    );
  }

  // زر دائري بأيقونة
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

  // عرض قسم القصص
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
                  return StoryModel(
                    imageUrl:
                        'https://linktinger.xyz/linktinger-api/${s['storyImage']}',
                    timestamp: DateTime.parse(s['createdAt']),
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

  // عرض قسم المنشورات
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
        final postId = int.tryParse(post['postId']?.toString() ?? '0') ?? 0;
        final userId = post['user_id'] ?? 0;

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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: userId),
              ),
            );
          },
          onLike: () async {
            if (postId <= 0) return;

            final result = await PostActionsService.toggleLike(postId);
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
          onShare: () {
            final postUrl = "https://linktinger.xyz/posts/$postId";
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('The link has been copied: $postUrl')),
            );
          },
        );
      },
    );
  }
}
