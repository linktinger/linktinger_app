import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCard extends StatefulWidget {
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
  final VoidCallback? onImageTap; // (اختياري) إن أردت فتح شاشة معاينة

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
    this.onImageTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  // أنيميشن قلب كبير عند الدبل-تاب
  bool _showBigHeart = false;

  // نبضة أيقونة الإعجاب عند التغيير
  late final AnimationController _likePulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    lowerBound: 0.9,
    upperBound: 1.15,
  );

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked) {
      // شغّل نبضة بسيطة عند تغيّر حالة الإعجاب
      _likePulseCtrl.forward(from: 0.9).then((_) => _likePulseCtrl.reverse());
    }
  }

  @override
  void dispose() {
    _likePulseCtrl.dispose();
    super.dispose();
  }

  String _fullUrl(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    return '${PostCard.baseUrl}$pathOrUrl';
  }

  void _handleDoubleTapLike() {
    setState(() => _showBigHeart = true);
    widget.onLike?.call();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showBigHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodyMedium;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(40),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== User Header =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                InkWell(
                  onTap: widget.onUserTap,
                  customBorder: const CircleBorder(),
                  child: _Avatar(url: _fullUrl(widget.userImage)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: widget.onUserTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.username,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.handle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // (اختياري) زر المزيد
                // IconButton(onPressed: (){}, icon: const Icon(Icons.more_horiz))
              ],
            ),
          ),

          // ===== Post Image with overlay actions =====
          _PostImage(
            imageUrl: _fullUrl(widget.postImage),
            onDoubleTap: _handleDoubleTapLike,
            onTap: widget.onImageTap,
            bigHeartVisible: _showBigHeart,
            actions: _OverlayActions(
              isLiked: widget.isLiked,
              likes: widget.likes,
              comments: widget.comments,
              onLike: widget.onLike,
              onComment: widget.onComment,
              onShare: widget.onShare,
              likePulse: _likePulseCtrl,
            ),
          ),

          // ===== Caption =====
          if (widget.caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Text(widget.caption, style: captionStyle),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const CircleAvatar(
        radius: 22,
        backgroundImage: AssetImage('assets/images/logo.jpg'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            CircleAvatar(radius: 22, backgroundColor: Colors.grey[300]),
        errorWidget: (_, __, ___) => const CircleAvatar(
          radius: 22,
          backgroundImage: AssetImage('assets/images/logo.jpg'),
        ),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool bigHeartVisible;
  final Widget actions;

  const _PostImage({
    required this.imageUrl,
    required this.actions,
    this.onTap,
    this.onDoubleTap,
    required this.bigHeartVisible,
  });

  @override
  Widget build(BuildContext context) {
    // نسبة 4:5 مثل إنستغرام
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الصورة
            Hero(
              tag: imageUrl,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) =>
                    Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),

            // قلب كبير عند الدبل-تاب
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: bigHeartVisible ? 1 : 0,
              child: Center(
                child: Icon(
                  Icons.favorite,
                  size: 96,
                  color: Colors.white.withAlpha(220),
                  shadows: const [
                    Shadow(color: Colors.black45, blurRadius: 12),
                  ],
                ),
              ),
            ),

            // تدرّج سفلي + شريط الأكشن “زجاجي”
            Align(
              alignment: Alignment.bottomCenter,
              child: _GlassBar(child: actions),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  final Widget child;
  const _GlassBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withAlpha(160),
                Colors.black.withAlpha(40),
                Colors.transparent,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _OverlayActions extends StatelessWidget {
  final bool isLiked;
  final int likes;
  final int comments;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final AnimationController likePulse;

  const _OverlayActions({
    required this.isLiked,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.likePulse,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white, fontSize: 13);

    return Row(
      children: [
        _Action(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: '$comments',
          onTap: onComment,
          textStyle: textStyle,
        ),
        const SizedBox(width: 6),
        ScaleTransition(
          scale: likePulse,
          child: _Action(
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            activeColor: Colors.redAccent,
            label: '$likes',
            isActive: isLiked,
            onTap: onLike,
            textStyle: textStyle,
          ),
        ),
        const Spacer(),
        _IconOnly(icon: Icons.share, onTap: onShare, tooltip: 'Share'),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;
  final TextStyle textStyle;

  const _Action({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? (activeColor ?? Colors.white) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

class _IconOnly extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const _IconOnly({required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
