import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentSheet extends StatefulWidget {
  final int postId;
  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  bool isSending = false;
  int currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndComments();
  }

  Future<void> _loadUserAndComments() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getInt('user_id') ?? 0;
    await _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => isLoading = true);

    final url = Uri.parse(
      'https://linktinger.xyz/linktinger-api/get_comments.php',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'tweet_id': widget.postId}),
    );

    final data = jsonDecode(response.body);
    if (data['status'] == 'success') {
      setState(() {
        comments = List<Map<String, dynamic>>.from(data['comments']);
        isLoading = false;
      });

      // Scroll to bottom after load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || isSending) {
      print('⚠️ Comment is empty or already sending');
      return;
    }

    print(
      '🟢 Sending comment: "$text" by user $currentUserId for post ${widget.postId}',
    );

    setState(() => isSending = true);
    FocusScope.of(context).unfocus();

    try {
      final url = Uri.parse(
        'https://linktinger.xyz/linktinger-api/add_comment.php',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tweet_id': widget.postId,
          'user_id': currentUserId,
          'content': text,
        }),
      );

      print('📡 Server response (${response.statusCode}): ${response.body}');

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        _controller.clear();
        await _fetchComments();
      } else {
        final message = data['message'] ?? 'Failed to send comment';
        print('❌ Server error: $message');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      print('❗ Exception during sending comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending comment')));
    } finally {
      setState(() => isSending = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Confirmation'),
        content: const Text('Do you really want to delete this comment?'),
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

    if (confirmed != true) return;

    final url = Uri.parse(
      'https://linktinger.xyz/linktinger-api/delete_comment.php',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'comment_id': commentId}),
    );

    final data = jsonDecode(response.body);
    if (data['status'] == 'success') {
      setState(() {
        comments.removeWhere((c) => c['id'] == commentId);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Failed to delete comment')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Comments",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? const Center(child: Text('No comments yet 🥲'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isOwner = comment['user_id'] == currentUserId;
                        final createdAt =
                            DateTime.tryParse(comment['created_at'] ?? '') ??
                            DateTime.now();
                        final timeAgo = timeago.format(createdAt);
                        final profileImage = comment['profileImage'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (profileImage != null &&
                                    profileImage.toString().startsWith('http'))
                                ? NetworkImage(profileImage)
                                : const AssetImage(
                                        'assets/images/default_avatar.png',
                                      )
                                      as ImageProvider,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                comment['username'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(comment['comment'] ?? ''),
                          trailing: isOwner
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      _deleteComment(comment['id']),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _addComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
