import 'dart:async';
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

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  late Timer _timer;
  int _currentIndex = 0;

  static const String baseUrl = 'https://linktinger.xyz/linktinger-api/';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentIndex < widget.stories.length - 1) {
        _nextStory();
      } else {
        _timer.cancel();
        Navigator.pop(context);
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTapUp(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    _timer.cancel();

    if (dx < width / 3) {
      _previousStory();
    } else {
      _nextStory();
    }

    _startTimer(); // Restart timer after interaction
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _buildFullImageUrl(String url) {
    // إذا كانت الصورة تبدأ بـ http، نعيدها كما هي، وإلا نضيف baseUrl
    if (url.startsWith('http') || url.startsWith('https')) {
      return url;
    }
    return '$baseUrl$url';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _onTapUp,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (_, index) {
                return Image.network(
                  _buildFullImageUrl(widget.stories[index].imageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 60,
                        color: Colors.white30,
                      ),
                    );
                  },
                );
              },
            ),

            // ✅ Progress Bar
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                  final index = entry.key;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index < _currentIndex
                            ? Colors.white
                            : index == _currentIndex
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ✅ User Info
            Positioned(
              top: 60,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(
                      _buildFullImageUrl(widget.userImage),
                    ),
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Close Button
            Positioned(
              top: 60,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
