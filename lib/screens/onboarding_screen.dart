import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;
  Timer? autoPageTimer;
  bool showTextAnimation = false;

  final List<String> titles = [
    'Welcome To the\nLinktinger',
    'Best Social APP to\nMake New Friends',
    'Enjoy Your Life Every\nTime, Every Where',
  ];

  @override
  void initState() {
    super.initState();
    startAutoPage();
    showTextAnimation = true;
  }

  void startAutoPage() {
    autoPageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (currentPage < titles.length - 1) {
        currentPage++;
        _controller.animateToPage(
          currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        timer.cancel();
        completeOnboarding();
      }
    });
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/register');
  }

  void skipOnboarding() {
    autoPageTimer?.cancel();
    completeOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    autoPageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/splash_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned(
            top: 48,
            right: 24,
            child: TextButton(
              onPressed: skipOnboarding,
              child: const Text(
                "Skip",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          PageView.builder(
            controller: _controller,
            itemCount: titles.length,
            onPageChanged: (index) {
              setState(() {
                currentPage = index;
                showTextAnimation = false;
              });

              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() => showTextAnimation = true);
                }
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: showTextAnimation ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 600),
                        offset: showTextAnimation
                            ? Offset.zero
                            : const Offset(0, 0.2),
                        child: Text(
                          titles[index],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: SmoothPageIndicator(
                        controller: _controller,
                        count: titles.length,
                        effect: const ExpandingDotsEffect(
                          activeDotColor: Colors.blue,
                          dotColor: Colors.grey,
                          dotHeight: 8,
                          dotWidth: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
