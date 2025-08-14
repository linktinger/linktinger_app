import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

class MessageBubble extends StatefulWidget {
  /// ملاحظة: في حالة shared_post نمرّر في [text] رابط الـ thumb (قد يكون فارغ)
  final String text;
  final bool isMe;
  final String type; // text | image | audio | shared_post
  final String? timestamp;
  final bool? isSeen;

  /// خصائص خاصة بالمنشور المشترك
  final int? sharedPostId;
  final String? sharedPostOwner;

  /// أحداث اختيارية لفتح الصور/المنشورات
  final void Function(int postId)? onOpenSharedPost;
  final void Function(String imageUrl)? onImageTap;

  /// لضبط عنوان الأساس للروابط النسبية (اختياري)
  final String? baseUrl;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.type,
    this.timestamp,
    this.isSeen,
    this.sharedPostId,
    this.sharedPostOwner,
    this.onOpenSharedPost,
    this.onImageTap,
    this.baseUrl,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final AudioPlayer _player;

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // مراقبة الحالة لتحديث الأيقونة/التحميل
    _player.playerStateStream.listen((state) {
      final buffering =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      final playing =
          state.playing && state.processingState != ProcessingState.completed;

      if (mounted) {
        setState(() {
          _isBuffering = buffering;
          _isPlaying = playing;
        });
      }

      if (state.processingState == ProcessingState.completed) {
        // أعد المؤشر للبداية عند الانتهاء
        _player.seek(Duration.zero);
        if (mounted) setState(() => _isPlaying = false);
      }
    });

    // مدة الملف الصوتي
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });

    // موضع التشغيل
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.text.trim().isEmpty) return;

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    try {
      // إذا لم يتم الإعداد بعد أو تغيّر الرابط، أعد التهيئة
      if (_player.audioSource == null ||
          (_player.audioSource is UriAudioSource &&
              (_player.audioSource as UriAudioSource).uri.toString() !=
                  _fullUrl(widget.text))) {
        await _player.setUrl(_fullUrl(widget.text));
      }
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  String _fullUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // استخدم baseUrl إن زُوّدت، وإلا اتركه نسبيًا (أو ضع افتراضيًا لديك)
    final base = (widget.baseUrl ?? '').trim();
    if (base.isNotEmpty) {
      final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final p = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      return '$b/$p';
    }
    // fallback (يمكنك تخصيصه بما يناسب مشروعك)
    return 'https://linktinger.xyz/linktinger-api/${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
  }

  String _formatTime(String? ts) {
    if (ts == null || ts.trim().isEmpty) return '';
    try {
      DateTime dt;
      try {
        dt = DateTime.parse(ts);
      } catch (_) {
        final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
        dt = fmt.parse(ts, true);
      }
      return DateFormat('hh:mm a').format(dt.toLocal());
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(1, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
    // إذا أردت ساعات: '${d.inHours}:${(d.inMinutes%60).toString().padLeft(2,'0')}:${(total%60).toString().padLeft(2,'0')}'
  }

  Widget _buildImage(String url) {
    final u = _fullUrl(url);
    if (u.isEmpty) {
      return Container(
        height: 150,
        color: Colors.grey.shade200,
        child: const Center(child: Text('📷 No image')),
      );
    }
    return GestureDetector(
      onTap: widget.onImageTap == null ? null : () => widget.onImageTap!(u),
      child: Image.network(
        u,
        fit: BoxFit.cover,
        width: MediaQuery.of(context).size.width * 0.55,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            height: 150,
            child: Center(child: Text('📷 Failed to load image')),
          );
        },
      ),
    );
  }

  Widget _buildAudio() {
    final isDisabled = widget.text.trim().isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: isDisabled ? null : _togglePlay,
              iconSize: 32,
              color: widget.isMe ? Colors.white : Colors.black87,
              icon: _isBuffering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              _duration == Duration.zero
                  ? 'Voice Message'
                  : _formatDuration(_position) +
                        ' / ' +
                        _formatDuration(_duration),
              style: TextStyle(
                color: widget.isMe ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        // شريط تقدّم بسيط
        if (_duration > Duration.zero)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble(),
                value: _position.inMilliseconds
                    .clamp(0, _duration.inMilliseconds)
                    .toDouble(),
                onChanged: (v) async {
                  final newPos = Duration(milliseconds: v.toInt());
                  await _player.seek(newPos);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSharedPost() {
    final thumbUrl = _fullUrl(widget.text);
    final hasThumb = thumbUrl.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (widget.sharedPostId != null && widget.onOpenSharedPost != null) {
          widget.onOpenSharedPost!(widget.sharedPostId!);
        } else {
          // احتياطًا لو لم يمرّر حدث الفتح
          debugPrint('Open shared post: ${widget.sharedPostId}');
        }
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hasThumb
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      height: 150,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Center(child: Text('📷 No preview')),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: 150,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Center(child: Text('🔗 Shared Post')),
                  ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                (widget.sharedPostOwner != null &&
                        widget.sharedPostOwner!.trim().isNotEmpty)
                    ? "Post by ${widget.sharedPostOwner}"
                    : "Shared a post",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(widget.timestamp);

    final bubbleColor = widget.isMe ? Colors.blueAccent : Colors.grey.shade200;
    final textColor = widget.isMe ? Colors.white : Colors.black87;

    late final Widget content;
    final isImage = widget.type == 'image';
    final isAudio = widget.type == 'audio';
    final isShared = widget.type == 'shared_post';

    if (isImage) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildImage(widget.text),
      );
    } else if (isAudio) {
      content = _buildAudio();
    } else if (isShared) {
      content = _buildSharedPost();
    } else {
      // نص
      content = Text(
        widget.text,
        style: TextStyle(color: textColor, fontSize: 15),
      );
    }

    final isMediaBubble = isImage || isShared;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: isMediaBubble ? EdgeInsets.zero : const EdgeInsets.all(10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isMediaBubble ? Colors.transparent : bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: widget.isMe
                    ? const Radius.circular(14)
                    : const Radius.circular(0),
                bottomRight: widget.isMe
                    ? const Radius.circular(0)
                    : const Radius.circular(14),
              ),
            ),
            child: content,
          ),
          // الوقت + مؤشّر القراءة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (widget.isMe && widget.isSeen != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      widget.isSeen! ? Icons.done_all : Icons.done,
                      size: 16,
                      color: widget.isSeen!
                          ? Colors.lightBlueAccent
                          : Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
