import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linktinger_app/screens/profile/user_profile_screen.dart';
import 'package:linktinger_app/screens/cards/visitor_card_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List users = [];
  List<Map<String, dynamic>> digitalCards = [];
  List<Map<String, dynamic>> explorePosts = [];
  List<String> recentSearches = [];
  bool isLoading = false;
  bool isCardsLoading = true;
  bool isPostsLoading = true;
  String error = '';

  final String baseUrl = 'https://linktinger.xyz/linktinger-api';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _fetchDigitalCards();
    _fetchExplorePosts();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    recentSearches = prefs.getStringList('recent_searches') ?? [];
    setState(() {});
  }

  Future<void> _saveToRecent(String query) async {
    final prefs = await SharedPreferences.getInstance();
    recentSearches.remove(query);
    recentSearches.insert(0, query);
    if (recentSearches.length > 10) {
      recentSearches = recentSearches.sublist(0, 10);
    }
    await prefs.setStringList('recent_searches', recentSearches);
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) return;

    await _saveToRecent(query);

    setState(() {
      isLoading = true;
      users = [];
      error = '';
    });

    final url = Uri.parse('$baseUrl/search_users.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      final data = jsonDecode(response.body);

      setState(() {
        isLoading = false;
        if (data['status'] == 'success') {
          users = data['users'];
        } else {
          error = data['message'] ?? 'Failed to fetch results.';
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'An error occurred while connecting: $e';
      });
    }
  }

  Future<void> _fetchDigitalCards() async {
    final url = Uri.parse('$baseUrl/get_all_cards.php');

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          digitalCards = List<Map<String, dynamic>>.from(data['cards']);
          isCardsLoading = false;
        });
      } else {
        setState(() {
          isCardsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isCardsLoading = false;
      });
    }
  }

  Future<void> _fetchExplorePosts() async {
    final url = Uri.parse('$baseUrl/get_explore_posts.php');
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          explorePosts = List<Map<String, dynamic>>.from(data['posts']);
          isPostsLoading = false;
        });
      } else {
        setState(() {
          isPostsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isPostsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onSubmitted: searchUsers,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            users = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          if (users.isEmpty && recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: recentSearches
                      .map(
                        (search) => ActionChip(
                          label: Text(search),
                          onPressed: () {
                            _controller.text = search;
                            searchUsers(search);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            )
          else if (users.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (_, index) {
                  final user = users[index];
                  final profileImage =
                      user['profileImage'] != null &&
                          user['profileImage'].toString().isNotEmpty
                      ? NetworkImage('$baseUrl/${user['profileImage']}')
                      : const AssetImage('assets/images/profile.png')
                            as ImageProvider;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundImage: profileImage,
                      radius: 26,
                    ),
                    title: Text(
                      user['screenName'] ?? user['username'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('@${user['username']}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            userId: int.parse(user['user_id'].toString()),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (!isCardsLoading && digitalCards.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Explore Digital Cards",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (isCardsLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: digitalCards.length,
                        itemBuilder: (context, index) {
                          final card = digitalCards[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisitorCardsCarouselScreen(
                                    cards: digitalCards,
                                    initialIndex: index,
                                    baseUrl: baseUrl,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.deepPurple,
                                    Colors.blueAccent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      '$baseUrl/${card['profileImage']}',
                                    ),
                                    radius: 30,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    card['screenName'] ?? card['username'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (card['isVerified'] == true)
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!isPostsLoading && explorePosts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Explore Posts",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isPostsLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (explorePosts.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: explorePosts.length,
                        itemBuilder: (context, index) {
                          final post = explorePosts[index];
                          final imageUrl = '$baseUrl/${post['media_url']}';
                          return GestureDetector(
                            onTap: () {
                              // افتح صفحة عرض المنشور الكامل إذا لزم
                            },
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
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
