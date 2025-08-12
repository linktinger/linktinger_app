import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';
import 'package:linktinger_app/services/conversation_service.dart';

class MessagesListScreen extends StatefulWidget {
  final int userId;
  const MessagesListScreen({super.key, required this.userId});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  late Future<List<Map<String, dynamic>>> _conversationsFuture;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allConversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingUsers = false;

  final String baseUrl = 'https://linktinger.xyz/linktinger-api';

  @override
  void initState() {
    super.initState();
    _conversationsFuture = ConversationService.fetchConversations(widget.userId)
        .then((data) {
          _allConversations = data;
          _filteredConversations = data;
          return data;
        });

    _searchController.addListener(() {
      _filterConversations(_searchController.text);
    });
  }

  void _filterConversations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredConversations = _allConversations;
        _searchResults = [];
        _isSearchingUsers = false;
      });
    } else {
      final filtered = _allConversations.where((convo) {
        final username = (convo['username'] ?? '').toLowerCase();
        return username.contains(query.toLowerCase());
      }).toList();

      setState(() {
        _filteredConversations = filtered;
      });

      // إذا لم توجد نتائج في المحادثات، ابدأ البحث في المستخدمين
      if (filtered.isEmpty) {
        await _searchUsers(query);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    final url = Uri.parse('$baseUrl/search_users.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          _isSearchingUsers = true;
          _searchResults = List<Map<String, dynamic>>.from(data['users']);
        });
      } else {
        setState(() {
          _isSearchingUsers = true;
          _searchResults = [];
        });
      }
    } catch (e) {
      setState(() {
        _isSearchingUsers = true;
        _searchResults = [];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search conversations or users...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('An error occurred while loading the conversations.'),
            );
          }

          if (_searchController.text.isNotEmpty && _isSearchingUsers) {
            if (_searchResults.isEmpty) {
              return const Center(child: Text('No users found.'));
            }
            return ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final imageUrl = user['profileImage'] ?? '';
                final username = user['username'] ?? 'User';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl.isNotEmpty
                        ? NetworkImage('$baseUrl/$imageUrl')
                        : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(user['screenName'] ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          currentUserId: widget.userId,
                          targetUserId: int.parse(user['user_id'].toString()),
                          targetUsername: username,
                          targetProfileImage: imageUrl,
                          isOnline: false,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }

          if (_filteredConversations.isEmpty) {
            return const Center(child: Text('No conversations found.'));
          }

          return ListView.separated(
            itemCount: _filteredConversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final convo = _filteredConversations[index];
              final unreadCount = (convo['unread'] ?? 0) as int;
              final lastMessage =
                  convo['lastMessage'] ?? 'Start the conversation now.';
              final imageUrl = convo['profileImage'] ?? '';
              final username = convo['username'] ?? 'user';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                ),
                title: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unreadCount > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: widget.userId,
                        targetUserId: convo['user_id'],
                        targetUsername: username,
                        targetProfileImage: imageUrl,
                        isOnline: convo['isOnline'] == true,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
