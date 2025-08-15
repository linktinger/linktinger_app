import 'package:flutter/material.dart';

class MessageHeader extends StatelessWidget {
  final String username;
  final String? profileImage;
  final bool isOnline;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onProfileTap;

  const MessageHeader({
    super.key,
    required this.username,
    this.profileImage,
    this.isOnline = false,
    this.subtitle,
    this.onBack,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack ?? () => Navigator.pop(context),
          ),
          GestureDetector(
            onTap: onProfileTap,
            onLongPress: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("View profile")));
              if (onProfileTap != null) onProfileTap!();
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      (profileImage != null && profileImage!.isNotEmpty)
                      ? NetworkImage(profileImage!)
                      : const AssetImage('assets/images/profile.png')
                            as ImageProvider,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle ?? (isOnline ? "Online now" : "Offline"),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: subtitle != null
                        ? Colors.blueGrey
                        : (isOnline ? Colors.green : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: "Video Call",
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "🚧 Video call feature is under development and will be available soon.",
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.videocam),
            ),
          ),
          Tooltip(
            message: "Voice Call",
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "🔊 Voice call service is currently under maintenance.",
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.call),
            ),
          ),

          //PopupMenuButton<String>(
          //icon: const Icon(Icons.more_vert),
          //onSelected: (value) {
          //if (value == 'block') {
          //ScaffoldMessenger.of(context).showSnackBar(
          //const SnackBar(content: Text("User has been blocked")),
          //);
          //} else if (value == 'report') {
          //ScaffoldMessenger.of(context).showSnackBar(
          // const SnackBar(content: Text("User has been reported")),
          // );
          // }
          //},
          //itemBuilder: (_) => [
          //const PopupMenuItem(value: 'block', child: Text('Block User')),
          // const PopupMenuItem(value: 'report', child: Text('Report')),
          // ],
          // ),
        ],
      ),
    );
  }
}
