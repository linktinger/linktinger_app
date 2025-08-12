import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final subjectController = TextEditingController();
  final messageController = TextEditingController();

  final String apiUrl = 'https://linktinger.xyz/linktinger-api/submit_help.php';

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email != null) {
      setState(() => emailController.text = email);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();
      final subject = subjectController.text.trim();
      final message = messageController.text.trim();

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          body: {'email': email, 'subject': subject, 'message': message},
        );

        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Message sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          subjectController.clear();
          messageController.clear();
        } else {
          throw Exception(data['message'] ?? 'Failed to send');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0.6,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 60,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Need help?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fill the form and our team will contact you shortly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: emailController,
                    readOnly: true,
                    decoration: _inputDecoration(
                      label: 'Your Email',
                      icon: Icons.email,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: subjectController,
                    decoration: _inputDecoration(
                      label: 'Subject',
                      icon: Icons.subject,
                    ),
                    validator: (value) =>
                        value != null && value.trim().length >= 3
                        ? null
                        : 'Please enter a valid subject.',
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: _inputDecoration(
                      label: 'Message',
                      icon: Icons.message_outlined,
                    ),
                    validator: (value) =>
                        value != null && value.trim().length >= 10
                        ? null
                        : 'Message must be at least 10 characters.',
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
