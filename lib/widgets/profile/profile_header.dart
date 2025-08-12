import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String profileImage;
  final bool isVerified;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.profileImage,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -60,
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 50,
              backgroundImage: profileImage.isNotEmpty
                  ? NetworkImage(profileImage)
                  : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.blue, size: 20),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
