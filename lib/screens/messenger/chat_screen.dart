// ChatScreen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';

import '../../services/websocket_service.dart';
import '../../services/message_service.dart';
import '../../widgets/messenger/message_bubble.dart';
import '../../widgets/messenger/message_input_field.dart' as input;
import '../../widgets/messenger/message_header.dart' as header;
import 'package:fluttertoast/fluttertoast.dart';

class ChatScreen extends StatefulWidget {
  final int currentUserId;
  final int targetUserId;
  final String targetUsername;
  final String? targetProfileImage;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUsername,
    this.targetProfileImage,
    this.isOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> messages = [];
  final WebSocketService _socket = WebSocketService();
  final ScrollController _scrollController = ScrollController();
  bool showTyping = false;
  Timer? typingTimer;

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _sendSeenSignal();

    // Fetch initial messages from API (may include shared_post)
    MessageService.fetchMessages(
          senderId: widget.currentUserId,
          receiverId: widget.targetUserId,
          // If you have a production env, pass overrideBaseUrl here
          // overrideBaseUrl: 'https://linktinger.xyz/linktinger-api',
        )
        .then((oldMessages) {
          setState(() => messages.addAll(oldMessages.map(_normalizeMessage)));
          _scrollToBottom();
        })
        .catchError((_) {});

    // Listen to WebSocket messages
    _socket.listen((raw) {
      try {
        final decodedAny = jsonDecode(raw);
        if (decodedAny is! Map) return;
        final decoded = Map<String, dynamic>.from(decodedAny);

        final from = _asInt(decoded['sender_id']);
        final to = _asInt(decoded['receiver_id']);
        final type = (decoded['type'] ?? 'text').toString();

        final isForThisChat =
            (from == widget.targetUserId && to == widget.currentUserId) ||
            (from == widget.currentUserId && to == widget.targetUserId);

        if (!isForThisChat) return;

        if (type == 'seen') {
          _updateSeenState();
          return;
        }

        if (type == 'typing') {
          setState(() => showTyping = true);
          typingTimer?.cancel();
          typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => showTyping = false);
          });
          return;
        }

        // Normalize the incoming message before adding
        final normalized = _normalizeMessage(decoded);
        setState(() => messages.add(normalized));
        _scrollToBottom();

        // Toast preview for incoming messages
        if (from == widget.targetUserId && to == widget.currentUserId) {
          final preview = _buildPreviewText(
            lastType: normalized['type'],
            lastMessage: normalized['message'],
            sharedPostOwner: normalized['shared_post_owner'],
          );
          Fluttertoast.showToast(
            msg: "${widget.targetUsername}: $preview",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black87,
            textColor: Colors.white,
            fontSize: 14,
          );
          _sendSeenSignal();
        }
      } catch (_) {
        // Ignore transient JSON parsing errors
      }
    });
  }

  /// Normalize message shape and guard against nulls.
  /// Supports `shared_post` whether provided at root or inside `message` as JSON.
  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> m) {
    final type = (m['type'] ?? 'text').toString().trim();

    // Keep the raw message before converting to String
    final rawMsg = m['message'];

    if (type == 'shared_post') {
      Map<String, dynamic>? inner;
      // Try to parse inner JSON if message is a JSON string or Map
      try {
        if (rawMsg is Map) {
          inner = Map<String, dynamic>.from(rawMsg);
        } else if (rawMsg is String && rawMsg.trim().isNotEmpty) {
          final decoded = jsonDecode(rawMsg);
          if (decoded is Map) inner = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Ignore failures
      }

      dynamic pick(List keys) {
        for (final k in keys) {
          if (inner != null &&
              inner[k] != null &&
              inner[k].toString().isNotEmpty) {
            return inner[k];
          }
          if (m[k] != null && m[k].toString().isNotEmpty) return m[k];
        }
        return null;
      }

      m['shared_post_id'] = pick(['shared_post_id', 'post_id', 'postId']);
      m['shared_post_thumb'] = pick([
        'shared_post_thumb',
        'thumb',
        'postImage',
        'post_image',
        'image',
        'thumbnail',
      ]);
      m['shared_post_owner'] = pick([
        'shared_post_owner',
        'owner',
        'username',
        'user_name',
        'author',
      ]);

      // Normalize created_at
      m['created_at'] =
          (m['created_at'] ??
                  m['createdAt'] ??
                  pick(['created_at', 'createdAt']) ??
                  '')
              .toString();
    } else {
      // Non-shared_post
      m['created_at'] = (m['created_at'] ?? m['createdAt'] ?? '').toString();
    }

    // After extracting from message, convert to String for UI consistency
    m['message'] = (rawMsg ?? '').toString();

    // Guard seen
    final seen = m['seen'];
    if (seen is! int && seen is! String) m['seen'] = 0;

    // Guard ids
    m['sender_id'] = _asInt(m['sender_id']);
    m['receiver_id'] = _asInt(m['receiver_id']);

    // Avoid empty bubble if no thumbnail is provided for shared_post
    if (type == 'shared_post' &&
        (m['shared_post_thumb'] == null ||
            m['shared_post_thumb'].toString().trim().isEmpty)) {
      m['shared_post_thumb'] = ''; // fallback text will be used in UI
    }

    return m;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _buildPreviewText({
    required String? lastType,
    required String? lastMessage,
    String? sharedPostOwner,
  }) {
    final type = (lastType ?? '').trim();
    switch (type) {
      case 'shared_post':
        if (sharedPostOwner != null && sharedPostOwner.trim().isNotEmpty) {
          return '🔗 Post by $sharedPostOwner';
        }
        return '🔗 Shared post';
      case 'image':
        return '📷 Image';
      case 'audio':
        return '🎵 Voice message';
      case 'video':
        return '🎬 Video';
      default:
        final msg = (lastMessage ?? '').trim();
        return msg.isEmpty ? '…' : msg;
    }
  }

  void _sendSeenSignal() {
    _socket.sendMessage(
      senderId: widget.currentUserId,
      receiverId: widget.targetUserId,
      message: '',
      type: 'seen',
    );
  }

  void _updateSeenState() {
    setState(() {
      for (var msg in messages) {
        if (msg['sender_id'] == widget.currentUserId) {
          msg['seen'] = 1;
        }
      }
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _scrollController.dispose();
    typingTimer?.cancel();
    super.dispose();
  }

  void _handleSend(String content, {String type = 'text'}) async {
    if (content.trim().isEmpty) return;

    FocusScope.of(context).unfocus();
    final now = DateTime.now().toIso8601String();

    final newMessage = _normalizeMessage({
      'sender_id': widget.currentUserId,
      'receiver_id': widget.targetUserId,
      'message': content,
      'type': type,
      'seen': 0,
      'created_at': now,
    });

    setState(() => messages.add(newMessage));
    _scrollToBottom();

    _socket.sendMessage(
      senderId: widget.currentUserId,
      receiverId: widget.targetUserId,
      message: content,
      type: type,
    );

    final success = await MessageService.sendMessage(
      senderId: widget.currentUserId,
      receiverId: widget.targetUserId,
      message: content,
      type: type,
      // overrideBaseUrl: 'https://linktinger.xyz/linktinger-api',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Failed to send the message to the server"),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _openSharedPost(int postId) {
    // Change this to your navigation system
    // Navigator.pushNamed(context, '/post', arguments: {'postId': postId});
    debugPrint('Open shared post: $postId');
  }

  void _openImage(String url) {
    // Push a full image screen if available
    // Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageScreen(url: url)));
    debugPrint('Open image: $url');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            header.MessageHeader(
              username: widget.targetUsername,
              profileImage: widget.targetProfileImage,
              isOnline: widget.isOnline,
              subtitle: showTyping ? "typing now..." : null,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['sender_id'] == widget.currentUserId;

                  final type = (msg['type'] ?? 'text').toString();

                  // The text/preview string passed to the bubble
                  final displayText = (type == 'shared_post')
                      ? ((msg['shared_post_thumb']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ??
                                false)
                            ? msg['shared_post_thumb'].toString()
                            : ' share post 🔗') // Fallback text to avoid empty bubble
                      : (msg['message'] ?? '').toString();

                  return MessageBubble(
                    text: displayText, // Always String
                    isMe: isMe,
                    timestamp: (msg['created_at'] ?? '').toString(),
                    isSeen: isMe
                        ? (msg['seen'] == 1 || msg['seen'] == '1')
                        : null,
                    type: type,
                    sharedPostId: msg['shared_post_id'] == null
                        ? null
                        : _asInt(msg['shared_post_id']),
                    sharedPostOwner: (msg['shared_post_owner'] ?? '')
                        .toString(),

                    // Enable opening image/post
                    onOpenSharedPost: (id) => _openSharedPost(id),
                    onImageTap: (url) => _openImage(url),

                    // Pass baseUrl to resolve relative URLs in MessageBubble
                    baseUrl: MessageService.baseUrl,
                  );
                },
              ),
            ),
            input.MessageInputField(
              onSend: _handleSend,
              currentUserId: widget.currentUserId,
              targetUserId: widget.targetUserId,
              onTyping: () {
                _socket.sendTyping(
                  senderId: widget.currentUserId,
                  receiverId: widget.targetUserId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
