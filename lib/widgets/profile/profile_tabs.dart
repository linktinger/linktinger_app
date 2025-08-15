import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linktinger_app/screens/full_image_screen.dart';
import 'package:linktinger_app/services/profile_service.dart';

class ProfileTabs extends StatefulWidget {
  /// Lists of media URLs for display (already normalized by the service)
  final List<String> all;
  final List<String> photos;
  final List<String> videos;

  /// Is this the current user's profile?
  final bool isMyProfile;

  /// Maps: url -> postId (used for deletion). Keys must match the lists above exactly.
  final Map<String, int> allUrlToId;
  final Map<String, int> photosUrlToId;
  final Map<String, int> videosUrlToId;

  const ProfileTabs({
    super.key,
    required this.all,
    required this.photos,
    required this.videos,
    this.isMyProfile = false,
    this.allUrlToId = const {},
    this.photosUrlToId = const {},
    this.videosUrlToId = const {},
  });

  @override
  State<ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends State<ProfileTabs>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  /// Local mutable copies (no extra normalization here)
  late List<String> _all;
  late List<String> _photos;
  late List<String> _videos;

  late Map<String, int> _allUrlToId;
  late Map<String, int> _photosUrlToId;
  late Map<String, int> _videosUrlToId;

  bool _busy = false;

  static const String _base = 'https://linktinger.xyz/linktinger-api';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hydrateFromWidget();
  }

  @override
  void didUpdateWidget(covariant ProfileTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.all != widget.all ||
        oldWidget.photos != widget.photos ||
        oldWidget.videos != widget.videos ||
        oldWidget.allUrlToId != widget.allUrlToId ||
        oldWidget.photosUrlToId != widget.photosUrlToId ||
        oldWidget.videosUrlToId != widget.videosUrlToId) {
      _hydrateFromWidget();
    }
  }

  void _hydrateFromWidget() {
    // Copy lists as-is
    _all = List<String>.from(widget.all);
    _photos = List<String>.from(widget.photos);
    _videos = List<String>.from(widget.videos);

    // Copy maps and expand with lookup variants
    _allUrlToId = _withVariants(Map<String, int>.from(widget.allUrlToId));
    _photosUrlToId = _withVariants(Map<String, int>.from(widget.photosUrlToId));
    _videosUrlToId = _withVariants(Map<String, int>.from(widget.videosUrlToId));
  }

  /// Expand keys with multiple variants to make matching more robust
  Map<String, int> _withVariants(Map<String, int> m) {
    final out = Map<String, int>.from(m);
    for (final e in m.entries) {
      for (final v in _lookupVariants(e.key)) {
        out.putIfAbsent(v, () => e.value);
      }
    }
    return out;
  }

  /// Build alternative keys (absolute/relative/noQuery/stripTrailingSlash…)
  List<String> _lookupVariants(String url) {
    final s = <String>{};
    s.add(url.trim());

    final u = Uri.tryParse(url.trim());
    if (u != null) {
      // remove query/fragment
      final noQ = u.replace(query: null, fragment: null).toString();
      s.add(noQ);
      if (noQ.endsWith('/')) s.add(noQ.substring(0, noQ.length - 1));

      // path only (relative)
      final p = u.path;
      if (p.isNotEmpty) {
        s.add(p);
        if (p.endsWith('/')) s.add(p.substring(0, p.length - 1));
      }

      // add absolute variant if original was relative
      if (!url.startsWith('http')) {
        final abs = _absoluteFromRelative(url);
        s.add(abs);
        if (abs.endsWith('/')) s.add(abs.substring(0, abs.length - 1));
      } else {
        // add relative variant if original was absolute
        final rel = _relativeFromAbsolute(url);
        if (rel.isNotEmpty) {
          s.add(rel);
          if (rel.endsWith('/')) s.add(rel.substring(0, rel.length - 1));
        }
      }
    } else {
      // Fallback: treat as relative and generate absolute
      final abs = _absoluteFromRelative(url);
      s.add(abs);
      if (abs.endsWith('/')) s.add(abs.substring(0, abs.length - 1));
    }

    // Cleanup stray braces/spaces at the end, just in case
    s.add(url.trim().replaceAll(RegExp(r'[}\s]+$'), ''));
    return s.toList();
  }

  String _absoluteFromRelative(String rel) {
    var r = rel.trim();
    if (r.startsWith('/')) r = r.substring(1);
    return '$_base/$r';
  }

  String _relativeFromAbsolute(String abs) {
    final a = abs.trim();
    if (a.startsWith(_base)) {
      final cut = a.substring(_base.length);
      return cut.startsWith('/') ? cut.substring(1) : cut;
    }
    final u = Uri.tryParse(a);
    return u?.path.replaceFirst(RegExp(r'^/'), '') ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isVideo(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm');
  }

  Future<void> _deleteItem({
    required int index,
    required List<String> list,
    required Map<String, int> urlToId,
  }) async {
    if (index < 0 || index >= list.length) return;

    final url = list[index];
    int? postId = urlToId[url];

    if (postId == null) {
      for (final v in _lookupVariants(url)) {
        final id = urlToId[v];
        if (id != null) {
          postId = id;
          break;
        }
      }
    }

    if (postId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to determine post ID for this item'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm delete'),
        content: const Text('Do you want to permanently delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    HapticFeedback.selectionClick();

    final removed = list.removeAt(index);
    setState(() => _busy = true);

    final resp = await ProfileService.deletePost(postId);

    if (!mounted) return;
    setState(() => _busy = false);

    if ((resp['status'] as String?) == 'success') {
      // Remove all variants to keep maps consistent
      for (final v in _lookupVariants(url)) {
        urlToId.remove(v);
      }
      _all.remove(url);
      _photos.remove(url);
      _videos.remove(url);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post deleted')));
    } else {
      // Roll back optimistic removal
      list.insert(index, removed);
      setState(() {});
      final rawMsg = resp['message'];
      final msg = (rawMsg is String && rawMsg.trim().isNotEmpty)
          ? rawMsg
          : 'Failed to delete the post';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _mediaTile({
    required String url,
    required VoidCallback? onDelete,
    required VoidCallback onOpen,
  }) {
    final isVid = _isVideo(url);
    return Stack(
      children: [
        GestureDetector(
          onTap: isVid ? null : onOpen,
          onLongPress: onDelete,
          child: Hero(
            tag: url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isVid
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
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, st) => Container(
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (widget.isMyProfile && onDelete != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black54,
                child: Icon(Icons.delete, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaGrid(List<String> items, Map<String, int> urlToId) {
    if (items.isEmpty) {
      return const Center(child: Text('No content'));
    }

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      children: [
        GridView.builder(
          key: ValueKey(items.length),
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final url = items[index];
            return _mediaTile(
              url: url,
              onDelete: widget.isMyProfile
                  ? () =>
                        _deleteItem(index: index, list: items, urlToId: urlToId)
                  : null,
              onOpen: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullImageScreen(imageUrl: url),
                  ),
                );
              },
            );
          },
        ),
        if (_busy) const PositionedFillLoader(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Important: TabBarView inside Expanded to avoid RenderFlex overflow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Photos'),
            Tab(text: 'Videos'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMediaGrid(_all, _allUrlToId),
              _buildMediaGrid(_photos, _photosUrlToId),
              _buildMediaGrid(_videos, _videosUrlToId),
            ],
          ),
        ),
      ],
    );
  }
}

class PositionedFillLoader extends StatelessWidget {
  const PositionedFillLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Color(0x66000000),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
