import 'dart:convert'; // For decoding shared-post JSON
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

class MessageBubble extends StatefulWidget {
  final String text; // Raw message payload (URL, JSON, text, etc.)
  final bool isMe; // Was this message sent by the current user?
  final String type; // 'text' | 'image' | 'audio' | 'shared_post'
  final String? timestamp; // ISO string (e.g., "2025-08-15T12:34:56Z")
  final bool? isSeen; // Seen status for outgoing messages

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.type,
    this.timestamp,
    this.isSeen,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;

  static const String _base = 'https://linktinger.xyz/linktinger-api/';

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Keep the play/pause icon in sync with the actual player state.
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final completed = state.processingState == ProcessingState.completed;
      if (!playing || completed) {
        if (mounted) setState(() => _isPlaying = false);
        if (completed) _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Returns an absolute URL. Accepts absolute/relative paths.
  String _fullUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return '$_base$cleaned';
  }

  /// Simple URL detector for plain text messages.
  bool _looksLikeUrl(String s) {
    return s.startsWith('http://') || s.startsWith('https://');
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }
    try {
      await _player.setUrl(_fullUrl(widget.text));
      await _player.play();
      setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() => _isPlaying = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play the voice message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format time safely
    String timeText = '';
    if (widget.timestamp != null && widget.timestamp!.trim().isNotEmpty) {
      try {
        timeText = DateFormat(
          'hh:mm a',
        ).format(DateTime.parse(widget.timestamp!).toLocal());
      } catch (_) {
        timeText = '';
      }
    }

    final bubbleColor = widget.isMe ? Colors.blueAccent : Colors.grey.shade200;
    final textColor = widget.isMe ? Colors.white : Colors.black87;

    // Build message content depending on type
    Widget content;

    if (widget.type == 'image') {
      // Image only (no link text)
      final url = _fullUrl(widget.text);
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            // TODO: push a full-screen image viewer if available
            // Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageScreen(imageUrl: url)));
          },
          child: Image.network(
            url,
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
        ),
      );
    } else if (widget.type == 'audio') {
      // Minimal audio bubble
      content = GestureDetector(
        onTap: _togglePlay,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
              color: textColor,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text('Voice message', style: TextStyle(color: textColor)),
          ],
        ),
      );
    } else if (widget.type == 'shared_post') {
      // Expect JSON inside `text`
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(widget.text);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // leave data as null
      }

      final postId = data?['post_id'];
      final owner = (data?['owner_name'] ?? '') as String;
      final caption = (data?['caption'] ?? '') as String;
      final thumbRel = (data?['post_image'] ?? '') as String;
      final thumb = _fullUrl(thumbRel);

      content = InkWell(
        onTap: () {
          // TODO: open a post-details screen when available
          // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: postId)));
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          decoration: BoxDecoration(
            color: widget.isMe ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumb.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    thumb,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.isEmpty ? 'Shared post' : owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                    if (postId != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '#$postId',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Plain text
      if (_looksLikeUrl(widget.text)) {
        // Optional: show a compact "link" chip instead of a full URL
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text('link', style: TextStyle(color: textColor)),
          ],
        );
      } else {
        content = Text(
          widget.text,
          style: TextStyle(color: textColor, fontSize: 15),
        );
      }
    }

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: widget.type == 'image'
                ? EdgeInsets.zero
                : const EdgeInsets.all(10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: widget.type == 'image' ? Colors.transparent : bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: widget.isMe
                    ? const Radius.circular(14)
                    : Radius.zero,
                bottomRight: widget.isMe
                    ? Radius.zero
                    : const Radius.circular(14),
              ),
            ),
            child: content,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeText.isNotEmpty)
                  Text(
                    timeText,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (widget.isMe && widget.isSeen != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.isSeen! ? Icons.done_all : Icons.done,
                    size: 16,
                    color: widget.isSeen!
                        ? Colors.lightBlueAccent
                        : Colors.grey,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
