import 'dart:convert';
import 'package:http/http.dart' as http;

class ConversationService {
  static const String baseUrl = 'https://linktinger.xyz/linktinger-api';

  static Future<List<Map<String, dynamic>>> fetchConversations(
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/get_conversations.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("📥 Decoded JSON: $data");

        if (data['status'] == 'success' && data['conversations'] != null) {
          List<dynamic> rawConvos = data['conversations'];

          return rawConvos.map<Map<String, dynamic>>((item) {
            final convo = Map<String, dynamic>.from(item);

            if (convo['profileImage'] != null &&
                convo['profileImage'].toString().isNotEmpty &&
                !convo['profileImage'].toString().startsWith('http')) {
              convo['profileImage'] = '$baseUrl/${convo['profileImage']}';
            }

            convo['username'] ??= 'user';
            convo['lastMessage'] ??= 'start chating';
            convo['unread'] ??= 0;
            convo['isOnline'] ??= false;

            return convo;
          }).toList();
        } else {
          print(
            "⚠️ API returned empty or error: ${data['message'] ?? 'no message'}",
          );
        }
      } else {
        print("❌ HTTP error: ${response.statusCode}");
      }
    } catch (e) {
      print('❌ Exception while fetching conversations: $e');
    }

    return [];
  }
}
