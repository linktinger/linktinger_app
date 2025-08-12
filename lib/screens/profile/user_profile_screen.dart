import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linktinger_app/services/profile_service.dart';
import 'package:linktinger_app/widgets/profile/profile_header.dart';
import 'package:linktinger_app/widgets/profile/profile_stats.dart';
import 'package:linktinger_app/widgets/profile/profile_bio.dart';
import 'package:linktinger_app/widgets/profile/profile_tabs.dart';
import 'package:linktinger_app/widgets/profile/profile_actions_other.dart';
import 'package:linktinger_app/screens/messenger/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool isLoading = true;
  String? error;

  String username = '';
  String screenName = '';
  String bio = '';
  String specialty = ''; // Added for specialty display
  String profileImage = '';
  String coverImage = '';
  int followers = 0;
  int following = 0;
  bool isFollowing = false;
  bool isPrivate = false;
  bool isFriend = false;
  bool isPendingRequest = false;
  bool isVerified = false; // Verified flag

  List<String> all = [];
  List<String> photos = [];
  List<String> videos = [];

  int myUserId = 0;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    myUserId = prefs.getInt('user_id') ?? 0;

    final result = await ProfileService.fetchOtherUserProfile(widget.userId);
    if (!mounted) return;

    if (result['status'] == 'success') {
      final user = result['user'];
      setState(() {
        username = user['username'];
        screenName = user['screenName'] ?? '';
        bio = user['bio'] ?? '';
        specialty = user['specialty'] ?? ''; // Load specialty from user data
        profileImage = user['profileImage'] ?? '';
        coverImage = user['profileCover'] ?? '';
        followers = result['followers'] ?? 0;
        following = result['following'] ?? 0;
        isFollowing = result['is_following'] ?? false;
        isPrivate = result['isPrivate'] ?? false;
        isFriend = result['isFriend'] ?? false;
        isPendingRequest = result['isPendingRequest'] ?? false;
        isVerified = user['verified'] == 1;

        if (!isPrivate || isFriend || myUserId == widget.userId) {
          all = List<String>.from(result['posts']['all']);
          photos = List<String>.from(result['posts']['photos']);
          videos = List<String>.from(result['posts']['videos']);
        }

        isLoading = false;
      });
    } else {
      setState(() {
        error = result['message'];
        isLoading = false;
      });
    }
  }

  void toggleFollow() async {
    final result = await ProfileService.toggleFollowUser(
      followerId: myUserId,
      followingId: widget.userId,
    );
    if (!mounted) return;

    if (result['status'] == 'success') {
      final isNowFollowing = result['action'] == 'followed';
      final isPending = result['pending'] ?? false;

      setState(() {
        isFollowing = isNowFollowing;
        isPendingRequest = isPending;
        if (isNowFollowing && (!isPrivate || isFriend)) {
          followers++;
        } else if (!isNowFollowing && followers > 0) {
          followers--;
        }
      });

      Fluttertoast.showToast(
        msg: result['message'] ?? '',
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
    } else {
      Fluttertoast.showToast(
        msg:
            result['message'] ??
            'An error occurred while proceeding/canceling.',
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void sendMessage() {
    if (myUserId == 0) {
      Fluttertoast.showToast(msg: "User ID not found.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: myUserId,
          targetUserId: widget.userId,
          targetUsername: username,
          targetProfileImage: profileImage,
          isOnline: true,
        ),
      ),
    );
  }

  Widget buildCoverImage() {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: coverImage.isNotEmpty
          ? FadeInImage.assetNetwork(
              placeholder: 'assets/images/logo.png',
              image: coverImage,
              fit: BoxFit.cover,
              imageErrorBuilder: (_, __, ___) =>
                  Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            )
          : Image.asset('assets/images/logo.png', fit: BoxFit.cover),
    );
  }

  Widget buildBackButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.5),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text(
                'Error loading profile:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loadUserProfile,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (isPrivate && !isFriend && myUserId != widget.userId) {
      return Scaffold(
        body: Stack(
          children: [
            buildCoverImage(),
            DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.65,
              maxChildSize: 1.0,
              builder: (context, scrollController) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    ProfileHeader(
                      username: username,
                      profileImage: profileImage,
                      isVerified: isVerified,
                    ),
                    const SizedBox(height: 12),
                    ProfileStats(followers: followers, following: following),
                    const SizedBox(height: 12),
                    ProfileActionsOther(
                      isFollowing: isFollowing,
                      isPrivateAccount: isPrivate,
                      isFriend: isFriend,
                      isPendingRequest: isPendingRequest,
                      onFollowToggle: toggleFollow,
                      onMessage: sendMessage,
                      targetUserId: widget.userId,
                      targetUsername: username,
                      targetProfileImage: profileImage,
                      showMessageButton: false,
                    ),
                    const SizedBox(height: 20),
                    const Icon(
                      Icons.lock_outline,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This account is private.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            buildBackButton(),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          buildCoverImage(),
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.65,
            maxChildSize: 1.0,
            builder: (context, scrollController) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  ProfileHeader(
                    username: username,
                    profileImage: profileImage,
                    isVerified: isVerified,
                  ),
                  const SizedBox(height: 8),
                  ProfileStats(followers: followers, following: following),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),
                  ProfileActionsOther(
                    isFollowing: isFollowing,
                    isPrivateAccount: isPrivate,
                    isFriend: isFriend,
                    isPendingRequest: isPendingRequest,
                    onFollowToggle: toggleFollow,
                    onMessage: sendMessage,
                    targetUserId: widget.userId,
                    targetUsername: username,
                    targetProfileImage: profileImage,
                    showMessageButton: myUserId != widget.userId,
                  ),
                  const SizedBox(height: 16),
                  ProfileTabs(
                    all: all,
                    photos: photos,
                    videos: videos,
                    isMyProfile: false,
                  ),
                ],
              ),
            ),
          ),
          buildBackButton(),
        ],
      ),
    );
  }
}
