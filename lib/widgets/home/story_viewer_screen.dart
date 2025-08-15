import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/story_model.dart';

class StoryViewerScreen extends StatefulWidget {
  final String username;
  final String userImage;
  final List<StoryModel> stories;

  /// صور فقط – لا يوجد حذف ولا لايك
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
  late AnimationController _progress; // يتحكم في شريط التقدم للعنصر الحالي
  Timer? _timer;

  int _currentIndex = 0;
  bool _disposed = false;

  // لإيقاف/استئناف المؤقّت بدقة
  Duration _storyDuration(int index) {
    return const Duration(seconds: 5);
  }

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

    _progress = AnimationController(vsync: this, duration: _storyDuration(0));

    // ابدأ أول ستوري
    _startCurrentStory(animatePage: false);
  }

  void _startCurrentStory({bool animatePage = true}) {
    _timer?.cancel();

    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    // أعد ضبط الـ progress لهذا العنصر وابدأه
    _progress.dispose();
    _progress =
        AnimationController(
          vsync: this,
          duration: _storyDuration(_currentIndex),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _next();
          }
        });

    _progress.forward();

    // مؤقّت نهاية الستوري (مرآة للـ progress)
    _timer = Timer(_storyDuration(_currentIndex), _next);
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    if (_progress.isAnimating) _progress.stop();
  }

  void _resume() {
    // احسب المتبقي بشكل تقريبي من progress.value
    final total = _storyDuration(_currentIndex);
    final played = total * _progress.value;
    final remaining = total - played;

    if (remaining <= Duration.zero) {
      _next();
      return;
    }

    _timer?.cancel();
    _timer = Timer(remaining, _next);
    if (!_progress.isAnimating) _progress.forward();
  }

  void _next() {
    if (!mounted || _disposed) return;
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _startCurrentStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (!mounted || _disposed) return;
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startCurrentStory();
    } else {
      // في أول ستوري – إغلاق (اختياري)
      Navigator.pop(context);
    }
  }

  void _onTapUp(TapUpDetails d) {
    final w = MediaQuery.of(context).size.width;
    final dx = d.globalPosition.dx;

    _pause();
    if (dx < w / 3) {
      _prev();
    } else {
      _next();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
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

            // شريط التقدم (متحرك للعنصر الحالي)
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  if (i < _currentIndex) {
                    // مكتمل
                    return _barSegment(1.0);
                  } else if (i == _currentIndex) {
                    // متحرك بحسب AnimationController
                    return AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => _barSegment(_progress.value),
                    );
                  } else {
                    // لم يبدأ
                    return _barSegment(0.0);
                  }
                }),
              ),
            ),

            // معلومات المستخدم
            Positioned(
              top: 60,
              left: 16,
              right: 56, // اترك مساحة لزر الإغلاق
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
                onPressed: () => Navigator.maybePop(context),
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
