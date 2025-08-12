import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatelessWidget {
  final int postId;
  final int userId;
  final String username;
  final String handle;
  final String userImage;
  final String postImage;
  final String caption;
  final int likes;
  final int comments;
  final bool isLiked;

  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onUserTap;

  static const String baseUrl = 'https://linktinger.xyz/linktinger-api/';

  const PostCard({
    super.key,
    required this.postId,
    required this.userId,
    required this.username,
    required this.handle,
    required this.userImage,
    required this.postImage,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.isLiked,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== User Header =====
          ListTile(
            leading: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onUserTap,
              child: userImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: '$baseUrl$userImage',
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        backgroundImage: imageProvider,
                        backgroundColor: Colors.grey[200],
                      ),
                      placeholder: (context, url) =>
                          const CircleAvatar(backgroundColor: Colors.grey),
                      errorWidget: (context, url, error) => const CircleAvatar(
                        backgroundImage: AssetImage('assets/images/logo.jpg'),
                      ),
                    )
                  : const CircleAvatar(
                      backgroundImage: AssetImage('assets/images/logo.jpg'),
                    ),
            ),
            title: InkWell(
              onTap: onUserTap,
              child: Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            subtitle: Text(handle),
          ),

          // ===== Post Image =====
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: CachedNetworkImage(
              imageUrl: '$baseUrl$postImage',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 280,
              placeholder: (context, url) => Container(
                width: double.infinity,
                height: 280,
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: 280,
              ),
            ),
          ),

          // ===== Action Buttons =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withAlpha(153), // 0.6 opacity
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.comment,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onComment,
                  tooltip: 'Comment',
                ),
                Text('$comments', style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 20,
                  ),
                  onPressed: onLike,
                  tooltip: isLiked ? 'Unlike' : 'Like',
                ),
                Text('$likes', style: const TextStyle(color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: onShare,
                  tooltip: 'Share',
                ),
              ],
            ),
          ),

          // ===== Caption =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(caption),
          ),
        ],
      ),
    );
  }
}
