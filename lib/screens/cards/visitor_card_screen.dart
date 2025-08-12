import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:linktinger_app/screens/profile/user_profile_screen.dart';

class VisitorCardsCarouselScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final int initialIndex;
  final String baseUrl;

  const VisitorCardsCarouselScreen({
    super.key,
    required this.cards,
    this.initialIndex = 0,
    required this.baseUrl,
  });

  @override
  State<VisitorCardsCarouselScreen> createState() =>
      _VisitorCardsCarouselScreenState();
}

class _VisitorCardsCarouselScreenState
    extends State<VisitorCardsCarouselScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Digital Cards"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.cards.length,
        itemBuilder: (context, index) {
          final card = widget.cards[index];
          return Center(
            child: FlipCard(
              direction: FlipDirection.HORIZONTAL,
              front: buildFrontCard(card),
              back: buildBackCard(),
            ),
          );
        },
      ),
    );
  }

  Widget buildFrontCard(Map<String, dynamic> card) {
    ImageProvider profileImage;
    if (card['profileImage'] == null || card['profileImage'].isEmpty) {
      profileImage = const AssetImage('assets/images/default_profile.png');
    } else {
      profileImage = NetworkImage('${widget.baseUrl}/${card['profileImage']}');
    }

    final String specialty = card['specialty'] ?? '';

    return buildCardContainer(
      child: SizedBox(
        height: 500, 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            CircleAvatar(radius: 50, backgroundImage: profileImage),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card['screenName'] ?? card['username'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (card['isVerified'] == true)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.verified, color: Colors.blue, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '@${card['username']}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              card['bio'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (specialty.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                specialty,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: int.parse(card['user_id'].toString()),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("View Profile"),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.qr_code_2, size: 40, color: Colors.white30),
            const SizedBox(height: 8),
            const Text(
              "Scan to connect",
              style: TextStyle(fontSize: 12, color: Colors.white30),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBackCard() {
    return buildCardContainer(
      child: SizedBox(
        height: 460,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 60, height: 60),
            const SizedBox(height: 20),
            const Text(
              "Linktinger",
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connect. Create. Link.",
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.qr_code_2, size: 50, color: Colors.white38),
            const SizedBox(height: 6),
            const Text(
              "Flip to connect",
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCardContainer({required Widget child}) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1C2C), Color.fromARGB(255, 81, 132, 235)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(8, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: child,
        ),
      ),
    );
  }
}
