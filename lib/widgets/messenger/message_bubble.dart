import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

class MessageBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final String type;
  final String? timestamp;
  final bool? isSeen;

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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      try {
        await _player.setUrl(_getFullAudioUrl(widget.text));
        await _player.play();
      } catch (e) {
        debugPrint('Error playing audio: $e');
      }
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  String _getFullAudioUrl(String path) {
    if (path.startsWith('http')) return path;
    return 'https://linktinger.xyz/linktinger-api/$path';
  }

  @override
  Widget build(BuildContext context) {
    final timeText = widget.timestamp != null
        ? DateFormat('hh:mm a').format(DateTime.parse(widget.timestamp!))
        : '';

    final bubbleColor = widget.isMe ? Colors.blueAccent : Colors.grey.shade200;
    final textColor = widget.isMe ? Colors.white : Colors.black87;

    Widget content;

    if (widget.type == 'image') {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.text,
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
    } else if (widget.type == 'audio') {
      content = GestureDetector(
        onTap: _togglePlay,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle_fill,
              color: widget.isMe ? Colors.white : Colors.black87,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text("Voice Message", style: TextStyle(color: textColor)),
          ],
        ),
      );
    } else {
      content = Text(
        widget.text,
        style: TextStyle(color: textColor, fontSize: 15),
      );
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
                    : const Radius.circular(0),
                bottomRight: widget.isMe
                    ? const Radius.circular(0)
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
