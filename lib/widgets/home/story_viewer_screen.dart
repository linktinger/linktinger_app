import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/story_model.dart';

class StoryViewerScreen extends StatefulWidget {
  final String username;
  final String userImage;
  final List<StoryModel> stories;

  const StoryViewerScreen({
    super.key,
    required this.username,
    required this.userImage,
    required this.stories,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api/';

  late final PageController _pageController;
  late final AnimationController _progress; // نعيد استخدامه لكل الستوري

  int _currentIndex = 0;
  bool _isClosing = false; // تمنع pop المزدوج

  // مدة كل ستوري (ثابتة هنا؛ عدّلها إن أردت)
  Duration _storyDuration(int index) => const Duration(seconds: 5);

  // حساب cacheWidth لتقليل استهلاك الذاكرة
  int _cacheWidthForContext(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final logicalW = mq.size.width;
    final dpr = mq.devicePixelRatio;
    final px = (logicalW * dpr).round();
    return math.min(px, 1440);
  }

  String _abs(String url) {
    final u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/')) return '$baseUrl${u.substring(1)}';
    return '$baseUrl$u';
  }

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _progress = AnimationController(vsync: this, duration: _storyDuration(0))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _next();
        }
      });

    _startCurrentStory(animatePage: false);
  }

  void _startCurrentStory({bool animatePage = true}) {
    if (!mounted) return;

    // انتقل لصفحة العنصر الحالي (لو لزم)
    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    // أعِد تهيئة المؤقّت البصري بدون إنشاء Controller جديد
    _progress.stop();
    _progress.duration = _storyDuration(_currentIndex);
    _progress.value = 0.0;
    _progress.forward();

    setState(() {}); // لتحديث شريط التقدم
  }

  void _pause() {
    if (_progress.isAnimating) _progress.stop();
  }

  void _resume() {
    if (!_progress.isAnimating && _progress.value < 1.0) {
      _progress.forward();
    }
  }

  void _next() {
    if (!mounted || _isClosing) return;

    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _startCurrentStory();
    } else {
      // انتهت آخر ستوري → أغلق الشاشة مرة واحدة فقط
      _isClosing = true;
      _progress.stop();
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (!mounted || _isClosing) return;

    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startCurrentStory();
    } else {
      // لو على أول ستوري وطلب الرجوع
      _isClosing = true;
      _progress.stop();
      Navigator.of(context).maybePop();
    }
  }

  void _onTapUp(TapUpDetails d) {
    final w = MediaQuery.of(context).size.width;
    final dx = d.globalPosition.dx;

    // نقرة يسار = رجوع، يمين/وسط = التالي
    if (dx < w / 3) {
      _prev();
    } else {
      _next();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cacheW = _cacheWidthForContext(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onLongPress: _pause,
      onLongPressEnd: (_) => _resume(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // محتوى القصص (صور فقط)
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (_, index) {
                final src = _abs(widget.stories[index].imageUrl);
                if (src.isEmpty) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.white30,
                    ),
                  );
                }
                return Image.network(
                  src,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: cacheW,
                  filterQuality: FilterQuality.low,
                  loadingBuilder: (c, child, p) {
                    if (p == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.white30,
                    ),
                  ),
                );
              },
            ),

            // شريط التقدم
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  if (i < _currentIndex) {
                    return _barSegment(1.0);
                  } else if (i == _currentIndex) {
                    return AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => _barSegment(_progress.value),
                    );
                  } else {
                    return _barSegment(0.0);
                  }
                }),
              ),
            ),

            // معلومات المستخدم
            Positioned(
              top: 60,
              left: 16,
              right: 56, // مساحة زر الإغلاق
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    backgroundImage: (_abs(widget.userImage).isNotEmpty)
                        ? NetworkImage(_abs(widget.userImage))
                        : null,
                    child: (_abs(widget.userImage).isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // زر إغلاق
            Positioned(
              top: 60,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  if (_isClosing) return;
                  _isClosing = true;
                  _progress.stop();
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عنصر شريط التقدم
  Widget _barSegment(double factor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: factor.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
