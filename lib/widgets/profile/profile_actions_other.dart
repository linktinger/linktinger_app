import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/messenger/chat_screen.dart';

class ProfileActionsOther extends StatelessWidget {
  final bool isFollowing;
  final bool isPrivateAccount;
  final bool isFriend;
  final bool isPendingRequest;
  final VoidCallback onFollowToggle;
  final VoidCallback onMessage;
  final int targetUserId;
  final String targetUsername;
  final String targetProfileImage;
  final bool isOnline;
  final bool showMessageButton;

  const ProfileActionsOther({
    super.key,
    required this.isFollowing,
    required this.isPrivateAccount,
    required this.isFriend,
    required this.isPendingRequest,
    required this.onFollowToggle,
    required this.onMessage,
    required this.targetUserId,
    required this.targetUsername,
    required this.targetProfileImage,
    this.isOnline = false,
    this.showMessageButton = true,
  });

  Future<void> _goToChat(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getInt('user_id') ?? 0;

    if (currentUserId == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text("You must log in first.")),
      );
      return;
    }

    if (currentUserId == targetUserId) {
      messenger.showSnackBar(
        const SnackBar(content: Text("You cannot send a message to yourself!")),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
          targetUsername: targetUsername,
          targetProfileImage: targetProfileImage,
          isOnline: isOnline,
        ),
      ),
    );
  }

  String getFollowLabel() {
    if (isPendingRequest) return 'Awaiting acceptance';
    if (isFollowing) return 'Unfollow';
    if (isPrivateAccount && !isFriend) return 'Follow request';
    return 'Follow';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDisabled = isPendingRequest;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isDisabled ? null : onFollowToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPendingRequest
                    ? Colors.grey[300]
                    : isFollowing
                    ? Colors.white
                    : Colors.blueAccent,
                foregroundColor: isFollowing || isPendingRequest
                    ? Colors.black
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isFollowing
                      ? const BorderSide(color: Colors.grey)
                      : BorderSide.none,
                ),
                elevation: 0,
              ),
              child: Text(
                getFollowLabel(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (showMessageButton)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToChat(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: isDark ? Colors.white70 : Colors.blueAccent,
                  ),
                  foregroundColor: isDark ? Colors.white : Colors.blueAccent,
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
