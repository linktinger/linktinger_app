import 'package:flutter/material.dart';

class StoryBubble extends StatefulWidget {
  final String? storyImage; // صورة الستوري (إن وُجدت)
  final String userImage; // صورة المستخدم (fallback)
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
  State<StoryBubble> createState() => _StoryBubbleState();
}

class _StoryBubbleState extends State<StoryBubble>
    with SingleTickerProviderStateMixin {
  // ========== إعدادات المظهر/المقاسات ==========
  static const double _outerSize = 64; // قطر الحلقة الخارجية
  static const double _ringPadding = 3; // حشوة الحلقة
  static const double _avatarRadius = (_outerSize / 2) - _ringPadding; // 29
  static const double _badgeRadius = 11;
  static const double _usernameWidth = _outerSize;
  static const Duration _pressAnim = Duration(milliseconds: 90);

  double _scale = 1.0;

  // ألوان الحلقة حسب الحالة
  List<Color> get _borderColors {
    if (widget.isMe) {
      return [Colors.grey.shade400, Colors.grey.shade600];
    }
    if (widget.isSeen) {
      return [Colors.grey.shade300, Colors.grey.shade400];
    }
    return const [Colors.indigo, Colors.deepPurple];
  }

  // يبني URL آمنًا (يقبل http/https/data) ويطبع النسبي على baseUrl
  String _buildImageUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    // إزالة / الزائد عند الوصل
    final base = StoryBubble.baseUrl.endsWith('/')
        ? StoryBubble.baseUrl.substring(0, StoryBubble.baseUrl.length - 1)
        : StoryBubble.baseUrl;
    final rel = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$base/$rel';
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl =
        (widget.storyImage != null && widget.storyImage!.trim().isNotEmpty)
        ? _buildImageUrl(widget.storyImage!)
        : _buildImageUrl(widget.userImage);

    return Semantics(
      button: true,
      label: widget.username.isEmpty ? 'Story' : 'Story: ${widget.username}',
      onTapHint: 'فتح القصة',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.97),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTapUp: (_) => Future.microtask(() => setState(() => _scale = 1.0)),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: _pressAnim,
          scale: _scale,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // حلقة خارجية ملوّنة حسب الحالة
                  Container(
                    width: _outerSize,
                    height: _outerSize,
                    padding: const EdgeInsets.all(_ringPadding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: _borderColors),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    // الصورة الداخلية
                    child: CircleAvatar(
                      radius: _avatarRadius,
                      backgroundColor: Colors.grey[300],
                      child: ClipOval(
                        child: _NetworkAvatar(
                          url: imageUrl,
                          width: (_outerSize - (_ringPadding * 2)),
                          height: (_outerSize - (_ringPadding * 2)),
                        ),
                      ),
                    ),
                  ),

                  // شارة الإضافة للحساب الشخصي
                  if (widget.isMe)
                    const Positioned(
                      bottom: -4,
                      right: -4,
                      child: _AddBadge(radius: _badgeRadius),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: _usernameWidth,
                child: Text(
                  widget.username.isEmpty ? 'User' : widget.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صورة شبكة مع Placeholder/Loader و Fallback بدون setState داخل البناء
class _NetworkAvatar extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const _NetworkAvatar({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback(width, height);

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      gaplessPlayback: true, // يمنع الوميض عند إعادة البناء
      // اعرض skeleton حتى يصل أول فريم
      frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _skeleton(width, height);
      },
      // لودر احتياطي لو احتجنا
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return _skeleton(width, height);
      },
      errorBuilder: (ctx, err, st) => _fallback(width, height),
      filterQuality: FilterQuality.low,
    );
  }

  Widget _skeleton(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.2, 0.5, 0.8],
        colors: [
          Colors.grey.shade300,
          Colors.grey.shade200,
          Colors.grey.shade300,
        ],
      ),
    ),
  );

  Widget _fallback(double w, double h) => Container(
    width: w,
    height: h,
    color: Colors.grey.shade300,
    child: const Icon(Icons.person, size: 36, color: Colors.white70),
  );
}

class _AddBadge extends StatelessWidget {
  final double radius;
  const _AddBadge({required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: const Icon(Icons.add, size: 16, color: Colors.indigo),
    );
  }
}
