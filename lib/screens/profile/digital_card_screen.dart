import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flip_card/flip_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DigitalCardScreen extends StatefulWidget {
  const DigitalCardScreen({super.key});

  @override
  State<DigitalCardScreen> createState() => _DigitalCardScreenState();
}

class _DigitalCardScreenState extends State<DigitalCardScreen> {
  String username = '';
  String fullName = '';
  String profileImage = '';
  String bio = '';
  String specialty = '';
  bool isVerified = false;
  bool isLoading = true;

  final String baseUrl = 'https://linktinger.xyz/linktinger-api/';

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      fullName = prefs.getString('full_name') ?? '';
      profileImage = prefs.getString('profileImage') ?? '';
      bio = prefs.getString('bio') ?? 'No bio added yet.';
      specialty = prefs.getString('specialty') ?? '';
      isVerified = prefs.getBool('verified') ?? false;
      isLoading = false;
    });
  }

  ImageProvider getProfileImage() {
    if (profileImage.isEmpty) {
      return const AssetImage('assets/images/default_profile.png');
    }
    return NetworkImage('$baseUrl$profileImage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("My Digital Card"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: FlipCard(
                direction: FlipDirection.HORIZONTAL,
                front: buildFrontCard(),
                back: buildBackCard(),
              ),
            ),
    );
  }

  Widget buildFrontCard() {
    return buildCardContainer(
      child: SizedBox(
        height: 500, // زيادة الارتفاع لإضافة التخصص
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            CircleAvatar(radius: 50, backgroundImage: getProfileImage()),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.verified, color: Colors.blue, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '@$username',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
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
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Add full share functionality
              },
              icon: const Icon(Icons.share),
              label: const Text("Share"),
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
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: "Send to Contacts",
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Coming soon: sharing with contacts"),
                      ),
                    );
                  },
                  icon: const Icon(Icons.contacts, color: Colors.white70),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: "Send via WhatsApp",
                  onPressed: _sendViaWhatsApp,
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

  void _sendViaWhatsApp() async {
    final message = Uri.encodeComponent(
      "👋 Hey! Check out my digital card:\n"
      "Name: $fullName\nUsername: @$username\nLet's connect!",
    );
    final url = Uri.parse("https://wa.me/?text=$message");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp")));
    }
  }
}
