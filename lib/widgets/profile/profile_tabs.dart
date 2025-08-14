import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linktinger_app/screens/full_image_screen.dart';
import 'package:linktinger_app/services/profile_service.dart';

class ProfileTabs extends StatefulWidget {
  /// قوائم الروابط فقط (ستُستخدم للعرض) - يجب أن تكون جاهزة/مطابقة من الـ Service
  final List<String> all;
  final List<String> photos;
  final List<String> videos;

  /// هل الملف الشخصي للمستخدم الحالي؟
  final bool isMyProfile;

  /// خرائط: url -> postId (للاستخدام عند الحذف) - مفاتيحها تطابق القوائم أعلاه حرفياً
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

  /// نسخ محليّة قابلة للتعديل من القوائم والخرائط (بدون أي تطبيع إضافي)
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
    // نسخ القوائم كما هي (مطابقة لما يأتي من الـ Service)
    _all = List<String>.from(widget.all);
    _photos = List<String>.from(widget.photos);
    _videos = List<String>.from(widget.videos);

    // نسخ الخرائط كما هي
    _allUrlToId = Map<String, int>.from(widget.allUrlToId);
    _photosUrlToId = Map<String, int>.from(widget.photosUrlToId);
    _videosUrlToId = Map<String, int>.from(widget.videosUrlToId);

    // ✅ توسعة الخرائط بإضافة مفاتيح بديلة (absolute/relative/noQuery/stripTrailingSlash)
    final beforeA = _allUrlToId.length;
    final beforeP = _photosUrlToId.length;
    final beforeV = _videosUrlToId.length;

    _allUrlToId = _withVariants(_allUrlToId);
    _photosUrlToId = _withVariants(_photosUrlToId);
    _videosUrlToId = _withVariants(_videosUrlToId);

    // ==== DEBUG: ملخص سريع بعد التهيئة ====
    debugPrint('----[ProfileTabs hydrate]--------------------------------');
    debugPrint(
      'ALL items=${_all.length}, map=${_allUrlToId.length} (was $beforeA)',
    );
    if (_all.isNotEmpty) {
      final sample = _all.first;
      debugPrint('ALL sample URL: $sample');
      debugPrint(
        'ALL hasKey? ${_allUrlToId.containsKey(sample)} | postId=${_allUrlToId[sample]}',
      );
    }
    debugPrint(
      'PHOTOS items=${_photos.length}, map=${_photosUrlToId.length} (was $beforeP)',
    );
    if (_photos.isNotEmpty) {
      final sample = _photos.first;
      debugPrint('PHOTOS sample URL: $sample');
      debugPrint(
        'PHOTOS hasKey? ${_photosUrlToId.containsKey(sample)} | postId=${_photosUrlToId[sample]}',
      );
    }
    debugPrint(
      'VIDEOS items=${_videos.length}, map=${_videosUrlToId.length} (was $beforeV)',
    );
    if (_videos.isNotEmpty) {
      final sample = _videos.first;
      debugPrint('VIDEOS sample URL: $sample');
      debugPrint(
        'VIDEOS hasKey? ${_videosUrlToId.containsKey(sample)} | postId=${_videosUrlToId[sample]}',
      );
    }
    debugPrint('----------------------------------------------------------');

    // ملاحظة: لو الخرائط لا تزال 0، فالمشكلة ليست هنا، بل في الخدمة/الـ API.
  }

  /// يبني مجموعة مفاتيح بديلة لكل مفتاح موجود ويضيفها إن لم تكن موجودة
  Map<String, int> _withVariants(Map<String, int> m) {
    final out = Map<String, int>.from(m);
    for (final entry in m.entries) {
      final key = entry.key;
      final id = entry.value;
      for (final v in _lookupVariants(key)) {
        out.putIfAbsent(v, () => id);
      }
    }
    return out;
  }

  /// يبني متغيرات لمفتاح (url) لمطابقة حالات: مطلق/نسبي/بدون query/بدون سلاش نهائي…
  List<String> _lookupVariants(String url) {
    final variants = <String>{};

    // الأصل كما هو
    variants.add(url.trim());

    final u = Uri.tryParse(url.trim());
    if (u != null) {
      // بدون query/fragment
      final noQ = u.replace(query: null, fragment: null).toString();
      variants.add(noQ);

      // بدون السلاش النهائي
      if (noQ.endsWith('/')) variants.add(noQ.substring(0, noQ.length - 1));

      // المسار فقط (نسبي)
      final p = u.path;
      if (p.isNotEmpty) {
        variants.add(p);
        if (p.endsWith('/')) variants.add(p.substring(0, p.length - 1));
      }

      // اكتب النسخة المطلقة إن كان المفتاح نسبي
      if (!url.startsWith('http')) {
        final abs = _absoluteFromRelative(url);
        variants.add(abs);
        if (abs.endsWith('/')) variants.add(abs.substring(0, abs.length - 1));
      }

      // اكتب النسخة النسبية إن كان المفتاح مطلق
      if (url.startsWith('http')) {
        final rel = _relativeFromAbsolute(url);
        if (rel.isNotEmpty) {
          variants.add(rel);
          if (rel.endsWith('/')) variants.add(rel.substring(0, rel.length - 1));
        }
      }
    } else {
      // لو Uri فشل، جرّب اعتباره نسبي
      final abs = _absoluteFromRelative(url);
      variants.add(abs);
      if (abs.endsWith('/')) variants.add(abs.substring(0, abs.length - 1));
    }

    // تنظيف خفيف من } ومسافات شاردة (احتياط)
    variants.add(url.trim().replaceAll(RegExp(r'[}\s]+$'), ''));

    return variants.toList();
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
    // لو دومين مختلف، نرجّع المسار فقط إن أمكن
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

    // استخدم الرابط كما هو دون أي تعديل
    final url = list[index];

    // جرّب مباشرة
    int? postId = urlToId[url];

    // إن لم يوجد، جرّب متغيرات الرابط (ABS/REL/noQuery/stripSlash)
    if (postId == null) {
      for (final v in _lookupVariants(url)) {
        if (urlToId.containsKey(v)) {
          postId = urlToId[v];
          debugPrint('[Match via variant] "$url" -> "$v" -> id=$postId');
          break;
        }
      }
    }

    // ==== DEBUG قبل الحذف ====
    debugPrint('[Delete Tap] index=$index');
    debugPrint('URL="$url"');
    debugPrint('HasKey? ${urlToId.containsKey(url)} | postId=$postId');

    if (postId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا أستطيع تحديد معرّف المنشور لهذا العنصر'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا المنشور نهائيًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    HapticFeedback.selectionClick();

    // حذف تفاؤلي + إمكانية التراجع عند الفشل
    final removed = list.removeAt(index);
    setState(() => _busy = true);

    final resp = await ProfileService.deletePost(postId);

    if (!mounted) return;
    setState(() => _busy = false);

    if ((resp['status'] as String?) == 'success') {
      // احذف كل المتغيرات المحتملة لنفس الرابط لضمان الاتساق
      for (final v in _lookupVariants(url)) {
        urlToId.remove(v);
      }
      _all.remove(url);
      _photos.remove(url);
      _videos.remove(url);
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المنشور')));
    } else {
      // تراجع لو فشل الحذف على السيرفر
      list.insert(index, removed);
      setState(() {});

      final rawMsg = resp['message'];
      final msg = (rawMsg is String && rawMsg.trim().isNotEmpty)
          ? rawMsg
          : 'فشل حذف المنشور';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // ==== DEBUG عند الفشل ====
      debugPrint('[Delete Failed] id=$postId | message=$msg | resp=$resp');
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
          onLongPress: onDelete, // دعم الضغط المطوّل للحذف
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
                      // مُحمّل بسيط
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      // خطأ تحميل الصورة
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
      return const Center(child: Text('لا يوجد محتوى'));
    }

    return Stack(
      children: [
        GridView.builder(
          key: ValueKey(items.length), // إعادة بناء نظيفة عند تغيّر الطول
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final url = items[index];

            // ==== DEBUG خفيف لكل عنصر أول 5 فقط لمنع الضوضاء ====
            if (index < 5) {
              debugPrint(
                '[GridItem#$index] url=$url | hasId=${urlToId.containsKey(url)} | id=${urlToId[url]}',
              );
            }

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
    return Column(
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
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
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
