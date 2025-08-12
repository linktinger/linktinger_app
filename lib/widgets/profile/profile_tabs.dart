import 'package:flutter/material.dart';
import 'package:linktinger_app/screens/full_image_screen.dart';

class ProfileTabs extends StatefulWidget {
  final List<String> all;
  final List<String> photos;
  final List<String> videos;
  final bool isMyProfile;

  const ProfileTabs({
    super.key,
    required this.all,
    required this.photos,
    required this.videos,
    this.isMyProfile = false,
  });

  @override
  State<ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends State<ProfileTabs>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmDelete(int index, List<String> list) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm deletion "),
        content: const Text(" Do you want to delete this image?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                list.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget buildMediaGrid(List<String> items) {
    if (items.isEmpty) {
      return const Center(child: Text('There is no content '));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final url = items[index];
        final isVideo =
            url.endsWith('.mp4') ||
            url.endsWith('.mov') ||
            url.endsWith('.webm');

        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (!isVideo) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullImageScreen(imageUrl: url),
                    ),
                  );
                }
              },
              child: Hero(
                tag: url,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isVideo
                      ? Container(
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle,
                              size: 40,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : Image.network(url, fit: BoxFit.cover),
                ),
              ),
            ),
            if (widget.isMyProfile)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _confirmDelete(index, items),
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.delete, size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'photos'),
            Tab(text: 'vedios'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              buildMediaGrid(widget.all),
              buildMediaGrid(widget.photos),
              buildMediaGrid(widget.videos),
            ],
          ),
        ),
      ],
    );
  }
}
