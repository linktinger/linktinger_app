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
  bool isTyping = false;
  bool showTyping = false;
  Timer? typingTimer;

  @override
  void initState() {
    super.initState();
    _socket.connect();

    _sendSeenSignal(); // إشعار عند الفتح

    MessageService.fetchMessages(
      senderId: widget.currentUserId,
      receiverId: widget.targetUserId,
    ).then((oldMessages) {
      setState(() => messages.addAll(oldMessages));
      _scrollToBottom();
    });

    _socket.listen((msg) {
      try {
        final decoded = jsonDecode(msg);
        final from = decoded['sender_id'];
        final to = decoded['receiver_id'];
        final type = decoded['type'] ?? 'text';

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
            setState(() => showTyping = false);
          });
          return;
        }

        setState(() => messages.add(decoded));
        _scrollToBottom();

        if (from == widget.targetUserId && to == widget.currentUserId) {
          final preview = type == 'image'
              ? "📷 photo"
              : type == 'audio'
              ? "🎵 audio"
              : decoded['message'];

          Fluttertoast.showToast(
            msg: "${widget.targetUsername}: $preview",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black87,
            textColor: Colors.white,
            fontSize: 14,
          );

          _sendSeenSignal(); // إشعار عند استلام رسالة
        }
      } catch (e) {
        print("❗ WebSocket decode error: $e");
      }
    });
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

    final newMessage = {
      'sender_id': widget.currentUserId,
      'receiver_id': widget.targetUserId,
      'message': content,
      'type': type,
      'seen': 0,
      'created_at': now,
    };

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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
              subtitle: showTyping ? "يكتب الآن..." : null,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['sender_id'] == widget.currentUserId;

                  return MessageBubble(
                    text: msg['message'],
                    isMe: isMe,
                    timestamp: msg['created_at'],
                    isSeen: isMe
                        ? (msg['seen'] == 1 || msg['seen'] == '1')
                        : null,
                    type: msg['type'] ?? 'text',
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
