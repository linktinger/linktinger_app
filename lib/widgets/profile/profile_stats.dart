import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  final int followers;
  final int following;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileStats({
    super.key,
    required this.followers,
    required this.following,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  Widget _buildStat(String label, int count, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat('Following', following, onFollowingTap),
          _buildStat('Followers', followers, onFollowersTap),
        ],
      ),
    );
  }
}
