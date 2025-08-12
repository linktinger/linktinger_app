import 'package:flutter/material.dart';

class ProfileInfo extends StatelessWidget {
  final String screenName;
  final String bio;

  const ProfileInfo({super.key, required this.screenName, required this.bio});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (screenName.isNotEmpty)
            Text(
              screenName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          const SizedBox(height: 8),
          if (bio.isNotEmpty)
            Text(
              bio,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
