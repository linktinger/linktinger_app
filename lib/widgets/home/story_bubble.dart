import 'package:flutter/material.dart';

class StoryBubble extends StatelessWidget {
  final String? storyImage;
  final String userImage;
  final String username;
  final bool isMe;
  final bool isSeen;
  final VoidCallback? onTap;

  const StoryBubble({
    super.key,
    required this.storyImage,
    required this.userImage,
    required this.username,
    this.isMe = false,
    this.isSeen = false,
    this.onTap,
  });

  static const String baseUrl = 'https://linktinger.xyz/linktinger-api/';

  @override
  Widget build(BuildContext context) {
    String buildImageUrl(String path) {
      if (path.startsWith('http')) {
        return path;
      }
      return '$baseUrl$path';
    }

    final String imageUrl = (storyImage != null && storyImage!.isNotEmpty)
        ? buildImageUrl(storyImage!)
        : buildImageUrl(userImage);

    final List<Color> borderColors = isMe
        ? [Colors.grey.shade400, Colors.grey.shade600]
        : isSeen
        ? [Colors.grey.shade300, Colors.grey.shade400]
        : [Colors.indigo, Colors.deepPurple];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: borderColors),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: Colors.grey[300],
                  child: ClipOval(
                    child: Image.network(
                      imageUrl,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person, size: 58, color: Colors.grey);
                      },
                    ),
                  ),
                ),
              ),
              if (isMe)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.indigo,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
