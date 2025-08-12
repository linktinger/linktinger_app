import 'package:flutter/material.dart';

class PostGrid extends StatelessWidget {
  final List<String> mediaList;

  const PostGrid({super.key, required this.mediaList});

  @override
  Widget build(BuildContext context) {
    if (mediaList.isEmpty) {
      return const Center(child: Text('No posts available'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mediaList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final url = mediaList[index];
        final isVideo =
            url.endsWith('.mp4') ||
            url.endsWith('.webm') ||
            url.endsWith('.mov');

        return Container(
          color: Colors.grey[300],
          child: isVideo
              ? const Icon(Icons.play_circle, size: 30)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
        );
      },
    );
  }
}
